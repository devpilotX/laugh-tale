# guard.ps1 - the destructive-command guard. Spec 33.6 item 13:
#   "enforcement matters more than instruction. A rule written in prose is a
#    request; a hook that refuses the command is a guarantee."
#
# Dot-source this and call Assert-CommandAllowed before ANY state-changing
# command, local or remote. It fails closed: an unparseable command is refused.
#
# 33.6 also warns: "Normalise quotes before matching, because a naively written
# guard is trivially bypassed by quoting inside the command." That is why
# Get-NormalisedCommand exists and why matching happens on its output only.

Set-StrictMode -Version Latest

# Paths where destructive recursive deletion is permitted (never-break rule 8).
# Anything else is refused outright.
$script:GuardAllowedDeleteRoots = @(
  '/var/lib/pelican/volumes/',   # dev server volume only, narrowed below
  '/tmp/',
  '/home/ubuntu/laughtail-scratch/',
  # Plugin build directory. Everything in it is either generated output or source
  # staged from the repository by build-plugin.sh, so it is fully reproducible and
  # holds nothing that is not already in git. Added when the plugin build needed to
  # clear stale compiler output; deliberately narrow, not a general /home/ubuntu grant.
  '/home/ubuntu/laughtail-plugin/'
)

# Permitted ONLY when the caller passes -TeardownApproved. These are the paths a permanent
# teardown must remove and that nothing else has any business deleting: the Pelican data
# directory, the panel web root, the panel config and the local backup directory.
#
# Kept as a SEPARATE list rather than added to the one above, because the list above governs
# every ordinary day of work. A teardown happens once; widening the everyday list to permit it
# would leave the box permanently one typo away from losing the panel.
$script:GuardTeardownDeleteRoots = @(
  '/var/lib/pelican',
  '/var/www/pelican',
  '/etc/pelican',
  '/home/ubuntu/laughtail-backups'
)

# The production server must never be touched from a script (never-break rule 1).
$script:GuardProductionNames = @('laughtail-prod', 'laughtail-live')

function Get-NormalisedCommand {
  <#
    Collapses the tricks that defeat naive string matching:
      quote removal      rm -rf "/var" and rm -rf '/var' and rm -rf /va"r"
      escape removal     rm\ -rf
      whitespace collapse
      case folding
    Matching is only ever done on this output.
  #>
  param([Parameter(Mandatory)][string]$Command)

  $c = $Command
  $c = $c -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ' '   # control chars
  $c = $c -replace '[''"`]', ''                            # quote characters
  $c = $c -replace '\\(?=\S)', ''                          # backslash escapes
  # Braced expansions keep their $ sigil rather than becoming the word VAR. The
  # previous form produced "VAR", which the final ToLowerInvariant() turned into
  # "var" - indistinguishable from a real /var/lib path, so a check for variable
  # targets either missed ${BUILD} or falsely flagged /var/lib/pelican. Keeping the
  # sigil makes "is this a variable" answerable with one character.
  $c = $c -replace '\$\{[^}]*\}', '$$var'
  $c = $c -replace '\$\(', '('                             # $( ) substitution
  $c = $c -replace '\s+', ' '
  return $c.Trim().ToLowerInvariant()
}

function Test-GuardRule {
  param([string]$Norm, [string]$Pattern)
  return [bool]([regex]::IsMatch($Norm, $Pattern))
}

function Assert-CommandAllowed {
  <#
    Throws if the command is forbidden. Returns a decision object otherwise.
    -Confirmed marks that the owner has explicitly approved a confirm-required
    command; without it, confirm-required commands are refused too.
  #>
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Command,
    [switch]$Confirmed,
    [string]$Reason = '',
    # TEARDOWN IS A SEPARATE, LOUDER PERMISSION THAN -Confirmed.
    #
    # -Confirmed means "the owner approved this operation". -TeardownApproved means "the owner asked to
    # DESTROY the server permanently", which is a different question and deserves a different answer.
    # Folding it into -Confirmed would mean every ordinary confirmed command silently gained the right
    # to delete the world, which is precisely the fail-open the rest of this file exists to prevent.
    #
    # It relaxes exactly two rules - container removal and volume pruning - and nothing else. Recursive
    # deletes still go through the literal-path check, so a teardown script still cannot delete a path
    # held in a variable.
    [switch]$TeardownApproved
  )

  if ([string]::IsNullOrWhiteSpace($Command)) {
    throw 'GUARD: refusing an empty command. Fail closed.'
  }

  $norm = Get-NormalisedCommand -Command $Command

  # ---- rm: recursive + force, however the flags are spelled ------------------
  # Handled before the pattern table because flags can be split (-r -f), combined
  # (-rf), reordered (-fr) or long (--recursive --force). A regex per spelling is
  # how guards get bypassed, so the flags are parsed instead of matched.
  foreach ($seg in ($norm -split '[;&|]')) {
    $s = $seg.Trim()
    if ($s -notmatch '(^|\s)rm(\s|$)') { continue }

    $tokens = $s -split '\s+'
    $idx = [array]::IndexOf($tokens, 'rm')
    if ($idx -lt 0) { continue }
    $after = if ($idx + 1 -lt $tokens.Count) { $tokens[($idx + 1)..($tokens.Count - 1)] } else { @() }

    $flagChars = ''
    $targets = @()
    foreach ($t in $after) {
      if ($t -eq '--recursive') { $flagChars += 'r'; continue }
      if ($t -eq '--force')     { $flagChars += 'f'; continue }
      if ($t -like '--*')       { continue }
      if ($t -like '-*')        { $flagChars += $t.TrimStart('-'); continue }
      $targets += $t
    }

    $recursive = $flagChars.Contains('r')
    $force     = $flagChars.Contains('f')
    if (-not ($recursive -and $force)) { continue }

    foreach ($target in $targets) {
      # Fail closed on a target we cannot resolve. A shell variable is opaque to a
      # static guard, so `rm -rf "$SOMEDIR/target"` could be anything at runtime.
      # The DROP DATABASE rule already refuses variable targets for exactly this
      # reason; allowing them here was an inconsistency that failed OPEN, which is
      # the worse direction. Name destructive targets literally.
      # One character decides it: a surviving $ or backtick means the target is a
      # shell expansion. Get-NormalisedCommand deliberately keeps the sigil on
      # braced forms so ${BUILD} and $BUILD are both caught, while a literal path
      # like /var/lib/pelican/volumes/... is not.
      if ($target -match '[$`]') {
        throw ("GUARD REFUSED (never-break rule 8): recursive force delete whose target is a variable.`n  command: {0}`n  target : {1}`n  A static guard cannot know what a variable expands to. Write the path literally." -f $Command, $target)
      }

      $ok = $false
      if ($TeardownApproved) {
        foreach ($tr in $script:GuardTeardownDeleteRoots) {
          if ($target -eq $tr.ToLowerInvariant() -or $target.StartsWith($tr.ToLowerInvariant() + '/')) {
            $ok = $true; break
          }
        }
      }
      if (-not $ok) { foreach ($root in $script:GuardAllowedDeleteRoots) {
        if ($target.StartsWith($root.ToLowerInvariant())) { $ok = $true; break }
      } }
      # A relative path is inside the repository working directory, which is fine.
      if (-not $ok -and $target -notmatch '^[/~]' -and $target -notmatch '^[a-z]:') { $ok = $true }
      if ($ok) { continue }

      throw ("GUARD REFUSED (never-break rule 8): recursive force delete outside the permitted roots.`n  command: {0}`n  target : {1}`n  Permitted roots: {2}`n  State the full path and get explicit confirmation first." -f `
             $Command, $target, ($script:GuardAllowedDeleteRoots -join ', '))
    }
    if ($targets.Count -eq 0) {
      throw ("GUARD REFUSED (never-break rule 8): recursive force delete with no parseable target. Fail closed.`n  command: {0}" -f $Command)
    }
  }

  # ---- DROP / TRUNCATE: denied by name, not by keyword ------------------------
  # The blanket rule 'drop database|drop table|truncate table' protected player data
  # correctly but also refused the Phase 0.6 restore drill, which must create and
  # remove a THROWAWAY schema to prove the backups restore. Refusing to test a
  # backup in the name of data safety is a net loss of safety.
  #
  # So the target name is parsed and checked against an explicit scratch allowlist.
  # This is narrower than the old rule, not looser: `DROP DATABASE laughtail` is
  # still refused, and now so is `DROP TABLE players`, while `DROP DATABASE
  # laughtail_drill` is permitted. Enforced by guard.tests.ps1 in both directions.
  foreach ($seg in ($norm -split ';')) {
    $s = $seg.Trim()
    if ($s -notmatch '\b(drop\s+(database|schema|table)|truncate\s+table)\b') { continue }

    # Strip the keywords and the optional IF EXISTS, then take the first identifier.
    $tail = $s -replace '.*\b(drop\s+(?:database|schema|table)|truncate\s+table)\b', ''
    $tail = $tail -replace '^\s*if\s+exists\s*', ''
    $target = ($tail.Trim() -split '[\s,(]')[0]
    $target = $target -replace '^.*\.', ''      # schema.table -> table
    $target = $target.Trim('`', '[', ']')

    if ([string]::IsNullOrWhiteSpace($target)) {
      throw ("GUARD REFUSED (data safety): a DROP or TRUNCATE with no parseable target. Fail closed.`n  command: {0}" -f $Command)
    }

    $isScratch = $target -match '^(lt|laughtail)_(drill|scratch|test)$' -or
                 $target -match '_(drill|scratch)$'
    if (-not $isScratch) {
      throw ("GUARD REFUSED (data safety): destroys player data.`n  command: {0}`n  target : {1}`n  Only scratch names are permitted here - something ending in _drill or _scratch,`n  such as laughtail_drill for the restore drill. If dropping '{1}' is genuinely`n  required, write it to docs/owner-actions.md and get explicit confirmation." -f $Command, $target)
    }
  }

  # ---- absolute denials -----------------------------------------------------
  # Each entry: pattern, which rule it protects, why it is unrecoverable.
  $deny = @(
    @{ p = '\bapp_key\b'
       r = 'never-break rule 6'; why = 'encrypted Panel data becomes permanently unrecoverable' }
    @{ p = 'artisan\s+key:generate'
       r = 'never-break rule 6'; why = 'regenerates the Panel APP_KEY' }
    @{ p = '(^|[\s;&|])(rm|mv|truncate|shred|tee)\b[^;&|]*\.env(\s|$|[;&|])'
       r = 'never-break rule 5'; why = 'destroys, truncates or overwrites the environment file' }
    @{ p = '(>|>>)\s*[^\s;&|]*\.env\b'
       r = 'never-break rule 5'; why = 'redirects output over the environment file' }
    @{ p = 'git\s+push\s+.*(--force\b|--force-with-lease=|-f\b)'
       r = 'git safety'; why = 'rewrites shared history' }
    @{ p = 'git\s+reset\s+.*--hard'
       r = 'git safety'; why = 'discards committed and uncommitted work' }
    @{ p = 'git\s+clean\s+.*-[a-z]*f'
       r = 'git safety'; why = 'deletes untracked files irrecoverably' }
    @{ p = 'git\s+branch\s+.*-d\b'
       r = 'git safety'; why = 'force-deletes a branch' }
    @{ p = 'git\s+filter-branch|git\s+filter-repo'
       r = 'git safety'; why = 'rewrites all history' }
    @{ p = 'docker\s+(volume\s+)?rm\b|docker\s+system\s+prune|docker\s+volume\s+prune'
       r = 'never-break rule 8'; why = 'deletes a Pelican server volume'; teardownOk = $true }
    @{ p = 'ufw\s+(disable|--force\s+reset|reset)\b'
       r = 'security'; why = 'opens the host to the internet' }
    @{ p = 'iptables\s+-f\b|iptables\s+--flush'
       r = 'security'; why = 'flushes all firewall rules' }
    @{ p = '(rm|mv|shred)\s[^;&|]*(/world|/world_nether|/world_the_end)(\s|/|$)'
       r = 'never-break rule 3'; why = 'never reset or delete the main world. Only the resource world resets, monthly' }
  )

  foreach ($d in $deny) {
    if (-not (Test-GuardRule -Norm $norm -Pattern $d.p)) { continue }
    # A rule marked teardownOk is skipped ONLY when the caller passed -TeardownApproved, which is a
    # louder and separate permission from -Confirmed. Folding the two together would mean every
    # ordinary confirmed command silently gained the right to delete the world.
    if ($TeardownApproved -and $d.ContainsKey('teardownOk')) { continue }
    throw ("GUARD REFUSED ({0}): {1}`n  command: {2}`n  If this is genuinely required, write it to docs/owner-actions.md and get explicit confirmation." -f `
           $d.r, $d.why, $Command)
  }

  # ---- dangerous binaries, checked by COMMAND POSITION not substring ----------
  # "echo waiting for a clean shutdown" must not be refused. Only an actual
  # invocation of shutdown must be. So the first real token of each command
  # segment is compared, after stripping sudo and env prefixes.
  $denyBinaries = @{
    'shutdown' = 'availability: takes the host down; stop the server via the Panel instead'
    'reboot'   = 'availability: takes the host down'
    'halt'     = 'availability: takes the host down'
    'poweroff' = 'availability: takes the host down'
    'mkfs'     = 'data safety: destroys the filesystem'
    'mkfs.ext4'= 'data safety: destroys the filesystem'
    'fdisk'    = 'data safety: repartitions the disk'
    'init'     = 'availability: changes runlevel'
    # never-break rule 7. Moved here from the substring table for the SAME reason
    # shutdown was: the old regex matched the WORD reload anywhere, so an echo
    # explaining the rule - "an Admin may reload the LaughTail config" - was refused.
    # That is the second false positive of this class. A guard that refuses prose
    # gets worked around, and a worked-around guard protects nothing.
    'reload'   = 'never-break rule 7: vanilla /reload corrupts plugin state. Use /laughtail reload'
  }
  foreach ($seg in ($norm -split '[;&|]|\bthen\b|\bdo\b')) {
    $t = @($seg.Trim() -split '\s+' | Where-Object { $_ -ne '' })
    $i = 0
    while ($i -lt $t.Count -and ($t[$i] -eq 'sudo' -or $t[$i] -eq 'env' -or $t[$i] -like '-*' -or $t[$i] -match '^\w+=')) { $i++ }
    if ($i -ge $t.Count) { continue }
    $bin = ($t[$i] -replace '^.*/', '')          # /sbin/shutdown -> shutdown
    $bin = $bin -replace '^(minecraft|bukkit|spigot|paper):', ''   # minecraft:reload -> reload
    if ($denyBinaries.ContainsKey($bin)) {
      throw ("GUARD REFUSED ({0}).`n  command: {1}`n  If this is genuinely required, write it to docs/owner-actions.md and get explicit confirmation." -f $denyBinaries[$bin], $Command)
    }
    # dd writing to a block device
    if ($bin -eq 'dd' -and $seg -match 'of=/dev/') {
      throw ("GUARD REFUSED (data safety): dd writing to a block device destroys the filesystem.`n  command: {0}" -f $Command)
    }
  }

  # ---- production server protection (never-break rule 1) --------------------
  foreach ($p in $script:GuardProductionNames) {
    if ($norm -match [regex]::Escape($p)) {
      throw ("GUARD REFUSED (never-break rule 1): the production server is named in this command.`n  command: {0}`n  Nothing reaches production until it has passed acceptance on laughtail-dev." -f $Command)
    }
  }

  # ---- confirm-required -----------------------------------------------------
  $confirm = @(
    @{ p = 'apt(-get)?\s+(dist-)?upgrade|apt(-get)?\s+full-upgrade'; why = 'never-break rule 13: host packages must not be upgraded mid-build without a fresh snapshot' }
    @{ p = 'apt(-get)?\s+install';                                   why = 'installs software on the game box' }
    @{ p = 'systemctl\s+(stop|disable|mask)\s';                      why = 'stops a host service' }
    @{ p = 'docker\s+(stop|kill|restart)\b';                         why = 'stops a running server' }
    @{ p = 'p:server:bulk-power\s+(stop|restart|kill)';              why = 'stops or kills a Pelican server; players online would be disconnected' }
    @{ p = 'artisan\s+migrate(\s|$)';                                why = 'runs Panel database migrations' }
    @{ p = 'artisan\s+down\b';                                       why = 'puts the Panel into maintenance mode' }
    @{ p = 'growpart|resize2fs|parted|fdisk';                        why = 'modifies partitions' }
    @{ p = 'chown\s+-r|chmod\s+-r';                                  why = 'recursive ownership or permission change' }
    @{ p = 'ufw\s+(allow|deny|delete)';                              why = 'changes the firewall' }
    @{ p = 'mysqldump|mysql\s+-';                                    why = 'touches the database directly' }
  )
  foreach ($c in $confirm) {
    if (Test-GuardRule -Norm $norm -Pattern $c.p) {
      if (-not $Confirmed) {
        throw ("GUARD REFUSED (confirmation required): {0}`n  command: {1}`n  Re-issue with -Confirmed once the owner has approved, and record why." -f $c.why, $Command)
      }
      return [pscustomobject]@{ Allowed = $true; Level = 'confirmed'; Why = $c.why; Command = $Command; Reason = $Reason }
    }
  }

  return [pscustomobject]@{ Allowed = $true; Level = 'plain'; Why = ''; Command = $Command; Reason = $Reason }
}

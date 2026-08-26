# guard.tests.ps1 - proves the guard refuses what it claims to refuse.
# Spec 28-4 and 28-5 want a transcript per pattern. This is that transcript.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'guard.ps1')

$pass = 0; $fail = 0
function Should-Refuse {
  param([string]$Cmd, [string]$Label)
  try {
    Assert-CommandAllowed -Command $Cmd | Out-Null
    Write-Output ("  FAIL  allowed but should refuse : {0}   [{1}]" -f $Cmd, $Label); $script:fail++
  } catch {
    if ($_.Exception.Message -like 'GUARD*') {
      Write-Output ("  ok    refused : {0}" -f $Cmd); $script:pass++
    } else {
      Write-Output ("  FAIL  wrong error : {0} -> {1}" -f $Cmd, $_.Exception.Message); $script:fail++
    }
  }
}
function Should-Allow {
  param([string]$Cmd)
  try {
    $r = Assert-CommandAllowed -Command $Cmd
    Write-Output ("  ok    allowed ({0}) : {1}" -f $r.Level, $Cmd); $script:pass++
  } catch {
    Write-Output ("  FAIL  refused but should allow : {0} -> {1}" -f $Cmd, $_.Exception.Message); $script:fail++
  }
}

Write-Output 'GROUP 1  never-break rule 8 - recursive delete outside permitted roots'
Should-Refuse 'rm -rf /'                                        'root'
Should-Refuse 'rm -rf /var/lib/pelican'                         'panel volumes parent'
Should-Refuse 'rm -rf /var/www/pelican'                         'panel install'
Should-Refuse 'rm -fr /etc'                                     'flag order swapped'
Should-Refuse 'rm -r -f /home/ubuntu'                           'split flags'

Write-Output 'GROUP 2  quote and escape bypass attempts (33.6 normalisation requirement)'
Should-Refuse 'rm -rf "/var/www/pelican"'                       'double quotes'
Should-Refuse "rm -rf '/var/www/pelican'"                       'single quotes'
Should-Refuse 'rm -rf /var/www/pel"ican"'                       'quote inside path'
Should-Refuse 'rm -rf /var/www/pelican'                         'plain'
Should-Refuse 'rm  -rf   /etc'                                  'extra whitespace'
Should-Refuse 'RM -RF /ETC'                                     'upper case'

Write-Output 'GROUP 3  never-break rule 6 - the Panel APP_KEY'
Should-Refuse 'php artisan key:generate'                        'key generate'
Should-Refuse 'grep APP_KEY /var/www/pelican/.env'              'any APP_KEY mention'
Should-Refuse 'sed -i s/APP_KEY=.*/APP_KEY=new/ .env'           'rewrite key'

Write-Output 'GROUP 4  never-break rule 5 - the environment file'
Should-Refuse 'rm /var/www/pelican/.env'                        'delete env'
Should-Refuse 'truncate -s 0 .env'                              'truncate env'

Write-Output 'GROUP 5  git safety'
Should-Refuse 'git push --force origin main'                    'force push'
Should-Refuse 'git push -f'                                     'short force'
Should-Refuse 'git reset --hard HEAD~3'                         'hard reset'
Should-Refuse 'git clean -fd'                                   'clean force'
Should-Refuse 'git branch -D main'                              'branch delete'
Should-Refuse 'git filter-branch --all'                         'history rewrite'

Write-Output 'GROUP 6  never-break rule 7 - vanilla reload'
Should-Refuse 'reload'                                          'bare reload'
Should-Refuse '/reload confirm'                                 'slash reload'

Write-Output 'GROUP 7  data safety'
Should-Refuse 'DROP DATABASE laughtail'                         'drop database'
Should-Refuse 'drop table players'                              'drop table'
Should-Refuse 'truncate table transactions'                     'truncate table'
Should-Refuse 'dd if=/dev/zero of=/dev/nvme0n1'                 'overwrite disk'
Should-Refuse 'docker volume rm 4fd2f0a9'                       'delete volume'
Should-Refuse 'docker system prune -af'                         'prune everything'

Write-Output 'GROUP 8  security and availability'
Should-Refuse 'ufw disable'                                     'disable firewall'
Should-Refuse 'iptables --flush'                                'flush rules'
Should-Refuse 'sudo reboot'                                     'reboot host'
Should-Refuse 'shutdown -h now'                                 'shutdown host'
Should-Refuse '/sbin/shutdown -r now'                           'shutdown by full path'
Should-Refuse 'sudo -n mkfs.ext4 /dev/nvme0n1'                  'format disk'
Should-Refuse 'dd if=/dev/zero of=/dev/nvme0n1'                 'overwrite disk'

Write-Output 'GROUP 8b  the same words inside strings must NOT be refused'
Should-Allow 'echo "=== waiting for a clean shutdown (up to 60s) ==="'
Should-Allow 'echo reboot required'
Should-Allow 'grep -c "left the game" latest.log'

Write-Output 'GROUP 8c  SQL keywords stay broad ON PURPOSE'
# Position-based checking is right for binaries, where "echo ... shutdown" is
# obviously harmless. It is NOT right for SQL, because a DROP can arrive through
# mysql -e, a heredoc, a .sql file, or a tinker one-liner, and enumerating those
# is how a guard gets bypassed. The cost of this false positive is rewording a
# log message. The cost of a false negative is the player database. Deliberate.
Should-Refuse 'echo "this will drop table names into a list"'    'SQL kept broad by design'

Write-Output 'GROUP 9  never-break rule 1 - production is untouchable'
Should-Refuse 'docker start laughtail-prod'                     'production named'

Write-Output 'GROUP 9b  never-break rule 3 - the main world'
Should-Refuse 'rm -r /var/lib/pelican/volumes/abc/world'        'delete main world'
Should-Refuse 'mv /var/lib/pelican/volumes/abc/world /tmp/old'  'move main world'
Should-Refuse 'rm -r /var/lib/pelican/volumes/abc/world_nether' 'delete nether'
Should-Allow  'rm -rf /var/lib/pelican/volumes/abc/world_resource'

Write-Output 'GROUP 10  confirm-required refused without -Confirmed'
Should-Refuse 'apt-get install openjdk-21-jdk'                  'install'
Should-Refuse 'systemctl stop wings'                            'stop service'
Should-Refuse 'ufw allow 24454/udp'                             'firewall change'
Should-Refuse 'growpart /dev/nvme0n1 1'                         'partition change'
Should-Refuse 'php artisan p:server:bulk-power stop --servers=1' 'panel stop'
Should-Refuse 'php artisan migrate'                             'panel migrations'

Write-Output 'GROUP 11  confirm-required allowed WITH -Confirmed'
try {
  $r = Assert-CommandAllowed -Command 'ufw allow 24454/udp' -Confirmed -Reason 'OA-06'
  if ($r.Level -eq 'confirmed') { Write-Output '  ok    allowed with -Confirmed : ufw allow 24454/udp'; $pass++ }
  else { Write-Output '  FAIL  wrong level'; $fail++ }
} catch { Write-Output ("  FAIL  " + $_.Exception.Message); $fail++ }

Write-Output 'GROUP 12  ordinary commands are not blocked'
Should-Allow 'ls -la /var/lib/pelican/volumes'
Should-Allow 'docker ps -a'
Should-Allow 'free -m'
Should-Allow 'rm -rf /tmp/scratch'
Should-Allow 'rm -rf build/output'
Should-Allow 'git status --short'
Should-Allow 'git commit -m fix'

Write-Output 'GROUP 13  fail closed on empty input'
Should-Refuse '' 'empty'
Should-Refuse '   ' 'whitespace only'

Write-Output ''
Write-Output ("PASS {0}   FAIL {1}" -f $pass, $fail)
if ($fail -eq 0) { Write-Output 'GUARD TESTS PASS (pre-flight 33.6 item 13)'; exit 0 }
else { Write-Output 'GUARD TESTS FAILED'; exit 1 }

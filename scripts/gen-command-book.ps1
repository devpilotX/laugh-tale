# gen-command-book.ps1 - emits docs/LaughTail-Command-Book.docx
#
# A REAL .docx, built as OOXML rather than an .html file renamed. A renamed HTML file opens in Word and
# then breaks the moment anyone edits or prints it, and the owner asked for a Word document.
#
# No Word installation is required and no COM automation is used: a .docx is a ZIP of XML parts, so it
# is assembled directly. That also means this runs identically on a machine without Office.
#
# It is a GENERATOR, following the same pattern as the other scripts here, because the command list
# changes with every feature. Regenerate it rather than editing the .docx by hand, or the document and
# the server will disagree - and a command book that lies is worse than none.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'docs'
$outFile = Join-Path $outDir 'LaughTail-Command-Book.docx'
$work = Join-Path $env:TEMP ("ltbook-" + [guid]::NewGuid().ToString('N'))

function XmlEsc([string]$s) {
    if ($null -eq $s) { return '' }
    $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

$body = New-Object System.Text.StringBuilder

function Add-Heading([string]$text, [int]$level) {
    $null = $body.Append('<w:p><w:pPr><w:pStyle w:val="Heading' + $level + '"/></w:pPr><w:r><w:t xml:space="preserve">' + (XmlEsc $text) + '</w:t></w:r></w:p>')
}
function Add-Para([string]$text) {
    $null = $body.Append('<w:p><w:r><w:t xml:space="preserve">' + (XmlEsc $text) + '</w:t></w:r></w:p>')
}
function Add-Note([string]$text) {
    $null = $body.Append('<w:p><w:pPr><w:pStyle w:val="Note"/></w:pPr><w:r><w:rPr><w:i/><w:color w:val="595959"/></w:rPr><w:t xml:space="preserve">' + (XmlEsc $text) + '</w:t></w:r></w:p>')
}
function Add-Bullet([string]$text) {
    $null = $body.Append('<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t xml:space="preserve">' + (XmlEsc $text) + '</w:t></w:r></w:p>')
}
function Add-PageBreak {
    $null = $body.Append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
}

# Builds a table. $rows is an array of string arrays; the first is the header.
function Add-Table($rows, $widths) {
    $null = $body.Append('<w:tbl><w:tblPr><w:tblStyle w:val="LTGrid"/><w:tblW w:w="5000" w:type="pct"/><w:tblBorders>')
    foreach ($side in 'top','left','bottom','right','insideH','insideV') {
        $null = $body.Append('<w:' + $side + ' w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>')
    }
    $null = $body.Append('</w:tblBorders></w:tblPr><w:tblGrid>')
    foreach ($w in $widths) { $null = $body.Append('<w:gridCol w:w="' + $w + '"/>') }
    $null = $body.Append('</w:tblGrid>')
    $first = $true
    foreach ($row in $rows) {
        $null = $body.Append('<w:tr>')
        if ($first) { $null = $body.Append('<w:trPr><w:tblHeader/></w:trPr>') }
        for ($i = 0; $i -lt $row.Count; $i++) {
            $shade = if ($first) { '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>' } else { '' }
            $null = $body.Append('<w:tc><w:tcPr><w:tcW w:w="' + $widths[$i] + '" w:type="dxa"/>' + $shade + '</w:tcPr>')
            $runProps = if ($first) { '<w:rPr><w:b/></w:rPr>' } else {
                if ($i -eq 0) { '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/></w:rPr>' } else { '' }
            }
            $null = $body.Append('<w:p><w:r>' + $runProps + '<w:t xml:space="preserve">' + (XmlEsc $row[$i]) + '</w:t></w:r></w:p></w:tc>')
        }
        $null = $body.Append('</w:tr>')
        $first = $false
    }
    $null = $body.Append('</w:tbl><w:p/>')
}

# ---------------------------------------------------------------------------
# Front matter
# ---------------------------------------------------------------------------
Add-Heading 'LaughTail SMP' 1
Add-Para 'The complete command book. Every command, every rank, every screen.'
Add-Note ("Generated " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " by scripts/gen-command-book.ps1. Regenerate rather than editing this file by hand - a command book that disagrees with the server is worse than none.")
Add-Para ''

Add-Heading 'How to read this' 2
Add-Para 'Anything in this book marked NOT BUILT is honestly not built. The in-game menu says the same thing on the same buttons, because a menu of buttons that silently do nothing looks like a finished server and is worse than an empty one - it moves the disappointment from "that is not built" to "this server is broken".'
Add-Para 'Three rules shape every decision below, and they are worth knowing before the command list:'
Add-Bullet 'Total equality. Nothing is for sale but access. There are no donor ranks, no pay-to-win, no crates, no gambling.'
Add-Bullet 'Rank comes from PvP and nothing else. Two hours of mining changes your rank by exactly zero. That is tested, not promised.'
Add-Bullet 'One currency. Berries. There is no second currency and never will be - a second currency is how servers hyperinflate.'

Add-PageBreak

# ---------------------------------------------------------------------------
# Ranks
# ---------------------------------------------------------------------------
Add-Heading 'Ranks' 1
Add-Para 'There are four separate ladders on this server and they do not feed into each other. That separation is deliberate and is the single most important thing in this document.'

Add-Heading '1. PvP rank - ten tiers, earned by fighting only' 2
Add-Para 'Everyone starts at Raider with 1000 RP. Winning takes RP from the loser; the amount depends on the gap between you, so beating someone far above you is worth a great deal and beating someone far below you is worth almost nothing.'
Add-Table @(
    @('Tier','RP needed','Shop tier'),
    @('Wanderer','0','1'),
    @('Settler','900','1'),
    @('Raider','1000 (start)','1'),
    @('Fighter','1100','2'),
    @('Warrior','1200','3'),
    @('Gladiator','1325','4'),
    @('Champion','1450','5'),
    @('Warlord','1600','6'),
    @('Legend','1775','7'),
    @('Mythic','2000','8')
) @(3000,3000,3000)
Add-Note 'Demotion exists. Losing costs RP, and a bad run can drop you a tier. A ladder you cannot fall down is a list of who played longest.'
Add-Note 'Shop tier gates BUYING only. Selling is never gated - a new player must be able to turn what they mine into Berries in their first minute.'

Add-Heading '2. Season Champion - one per month' 2
Add-Para 'Whoever holds the highest rating when a season ends is crowned Champion. Exactly one, enforced by the database itself so a second one cannot be created even by accident.'
Add-Para 'The Champion gets a permanent title, kept forever, shown on join. They get no Berries, no items, no gear, no stat bonus, no permission and no shop discount. The prize is entirely recognition, and that is what keeps the next season fair - a Champion with an advantage would make the following season unfair by construction.'

Add-Heading '3. Paths - six ladders that everyone can climb' 2
Add-Para 'Because rank is PvP-only, a player who loses fights would otherwise have nothing to climb. Paths are the second ladder. Each levels from something you already do, up to level 50, and awards titles at levels 5, 10, 20, 30, 40 and 50.'
Add-Table @(
    @('Path','Advances from','Titles'),
    @('Delver','Mining, and depth','Apprentice / Journeyman / Adept / Master / Grandmaster / Eternal'),
    @('Cultivator','Farming and harvesting','same six milestones'),
    @('Hunter','Killing hostile creatures','same six milestones'),
    @('Wayfinder','Distance travelled on foot','same six milestones'),
    @('Artificer','Crafting and building','same six milestones'),
    @('Broker','Trading and filling orders','same six milestones')
) @(2000,3500,3500)
Add-Note 'Paths grant titles, colours and recognition. They never grant damage, health, speed, drop rate, discounts or permissions. This is enforced by the database schema: no column exists anywhere in the roleplay tables that could hold a bonus.'

Add-Heading '4. Staff groups - six, and none of them are for sale' 2
Add-Table @(
    @('Group','Shown as','Weight','What it is for'),
    @('default','Member','0','Every paying player. This is the normal state'),
    @('helper','Helper','10','Answer questions, short mutes and kicks, claim reports'),
    @('mod','Mod','20','Full mutes, kicks, temporary bans, inspect blocks'),
    @('srmod','SrMod','30','Permanent bans, unban, review other staff actions'),
    @('admin','Admin','40','Configuration and access grants'),
    @('owner','Owner','100','Seasons, economy control, everything')
) @(1600,1600,1000,4800)
Add-Note 'There is no VIP, Premium, Elite, MVP or donor rank, and there will not be one. Every paying player is a Member with exactly the same abilities. That is not a limitation - it is the product. It is also what makes pay-to-win impossible by construction rather than by policy.'
Add-Note 'Admin carries EXPLICIT DENIALS on a list of dangerous permissions, rather than simply not being granted them. An explicit denial keeps working even if someone later grants the permission higher up the chain; an absence does not.'

Add-PageBreak

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
Add-Heading 'Commands' 1
Add-Para 'Forty commands. Every one of them works right now unless the row says otherwise.'

Add-Heading 'The menu' 2
Add-Table @(
    @('Command','What it does'),
    @('/menu','Opens the chest menu. This is the front door to almost everything'),
    @('/lt','Short for /menu'),
    @('/laughtale','Also short for /menu')
) @(2600,6400)
Add-Note 'Why a chest menu and not a button in the ESC pause menu: a server cannot put a button there. That menu is drawn entirely by your own game, and the only way in is the Lunar Client mod, which would work for Lunar players and nobody else. A chest menu works for every Java player AND for Bedrock players.'

Add-Heading 'Getting started' 2
Add-Table @(
    @('Command','What it does'),
    @('/rules','Read the rules'),
    @('/rules accept','Accept them. Until you do, you cannot move, build or chat')
) @(2600,6400)

Add-Heading 'Money - Berries' 2
Add-Table @(
    @('Command','What it does'),
    @('/balance','Your Berries. /bal also works'),
    @('/pay <player> <amount>','Send Berries. Over 5000 carries a 5% tax, shown before it applies'),
    @('/baltop','The richest players'),
    @('/berries','Where Berries come from and what they are for')
) @(2600,6400)
Add-Note 'Every movement of Berries writes a permanent ledger row. The ledger sums to the balance, which is how the server can prove it has not lost or invented money.'

Add-Heading 'The shop - buying from the server' 2
Add-Table @(
    @('Command','What it does'),
    @('/shop','Your shop tier, and how buying and selling work'),
    @('/buy <item> [amount]','Buy. Refused if the item needs a higher rank than you have'),
    @('/sell','Opens the sell box: put items in, see what they are worth, click once'),
    @('/sell hand','Sell everything of the type you are holding'),
    @('/sell all','Sell every sellable item in your inventory')
) @(2600,6400)
Add-Note 'Prices move with trade, inside a band of plus or minus 20% of a base price. Buying pushes a price up, selling pushes it down, and prices drift back toward normal at 5% an hour.'
Add-Note 'You can sell at most 3600 Berries worth per category per day. That limit is what stops one player flooding the market and crashing a price for everyone.'
Add-Note 'The shop sells at the listed price and buys back at HALF of it, so something listed at 200 pays 100 when you sell one. Buying and selling straight back therefore loses half its value. That is deliberate and it is checked automatically: every recipe on the server is audited on every restart for any way to turn Berries into more Berries, and if one is found the shop closes itself.'

Add-Heading 'The bazaar - trading with other players' 2
Add-Table @(
    @('Command','What it does'),
    @('/order buy <item> <qty> <price>','Place a buy order. Your Berries are held until it fills'),
    @('/order sell <item> <qty> <price>','Place a sell order. Your items are held until it fills'),
    @('/order book <item>','What people are currently buying and selling it for'),
    @('/order claim','Collect what your filled orders earned'),
    @('/order cancel <id>','Withdraw an order and get your Berries or items back'),
    @('/order','Your own orders. /orders and /bazaar also work')
) @(3400,5600)
Add-Note 'Orders fill whether or not you are online. That is the whole point of a bazaar.'
Add-Note 'The order that waited sets the price. If you offer 25 and someone is already selling at 20, you pay 20 and get the difference back. Rewarding whoever committed first is what makes a market worth using.'
Add-Note 'You cannot trade with yourself, and nothing is held in memory - if the server crashes mid-trade, the trade either happened completely or not at all.'

Add-Heading 'Homes and teleporting' 2
Add-Table @(
    @('Command','What it does'),
    @('/sethome <name>','Set a home'),
    @('/home [name]','Go to one'),
    @('/homes','List them'),
    @('/delhome <name>','Delete one'),
    @('/buyhome','Buy another slot with Berries. Two free, twenty maximum'),
    @('/rtp','Random teleport into the resource world. /wild also works'),
    @('/tpa <player>','Ask to teleport to someone'),
    @('/tpahere <player>','Ask someone to come to you'),
    @('/tpaccept','Accept a request'),
    @('/tpdeny','Refuse one')
) @(2600,6400)
Add-Note 'None of these work while you are in combat. Taking or dealing damage from a player tags you for 15 seconds, and the tag stops you teleporting away or logging out safely. Logging out while tagged drops your items where you stood and counts as a death.'
Add-Note 'A home slot you buy is yours permanently. Dropping a rank cannot take it away.'

Add-Heading 'Other players' 2
Add-Table @(
    @('Command','What it does'),
    @('/friend add <player>','Ask someone to be a friend'),
    @('/friend accept <player>','Accept their request'),
    @('/friend remove <player>','Remove a friend, or withdraw a request'),
    @('/friend requests','Requests waiting for you'),
    @('/friend','Your friends, and who is online. /friends also works'),
    @('/top','Leaderboards. Add rank, kills, streak or playtime')
) @(2900,6100)
Add-Note 'Friendship needs both sides to agree. A one-sided friend list is a following list, and a following list is a way to harass someone.'
Add-Note 'Being friends grants no advantage of any kind. There is also no richest leaderboard - it would reward hoarding over playing, and it would tell every thief who to target.'

Add-Heading 'Roleplay - Paths, Houses and the story' 2
Add-Table @(
    @('Command','What it does'),
    @('/path','Your six Paths and their progress. /paths also works'),
    @('/path focus <name>','Show one Path on your screen'),
    @('/house','Your House and the season standings'),
    @('/house join <name>','Join one: ember, tide, verdant or ashen'),
    @('/title','Titles you have earned. /titles also works'),
    @('/title wear <key>','Wear a different one'),
    @('/chronicle','This season''s story and how far the server has got. /story also works'),
    @('/me <action>','Describe what you are doing, to people within 100 blocks'),
    @('/local <message>','Speak only to people who can see you'),
    @('/hc <message>','Speak to your House, wherever they are')
) @(2900,6100)
Add-Note 'House standing rises from everything members do, not only from fighting. A House of farmers can beat a House of fighters.'
Add-Note 'The Chronicle is one story for the whole server, and every chapter needs more than one kind of player - blocks mined AND creatures defeated AND orders filled. That is what makes farmers and fighters useful to each other.'
Add-Note 'Breaking character is not punishable. These are tools for people who want them, not rules for people who do not.'

Add-Heading 'Staff commands' 2
Add-Table @(
    @('Command','Who','What it does'),
    @('/warn <player> <reason>','Helper','Warn someone'),
    @('/mute <player> <time> <reason>','Helper','Mute'),
    @('/unmute <player>','Mod','Unmute'),
    @('/kick <player> <reason>','Helper','Kick'),
    @('/tempban <player> <time> <reason>','Mod','Temporary ban'),
    @('/ban <player> <reason>','SrMod','Permanent ban'),
    @('/unban <player>','SrMod','Lift a ban'),
    @('/history <player>','Helper','Everything that has been done to an account')
) @(3400,1400,4200)
Add-Note 'Every one of these writes a permanent audit row, including failed attempts. The audit table refuses UPDATE and DELETE at the database level, so nobody - including the Owner - can quietly edit history.'

Add-Heading 'Owner and Admin' 2
Add-Table @(
    @('Command','Who','What it does'),
    @('/access grant <player> <ref> <amount>','Admin','Grant paid access'),
    @('/access revoke <player> <reason>','Admin','Remove it'),
    @('/access list','Admin','Who has access'),
    @('/access audit','Admin','Compare the whitelist against paid records, both ways'),
    @('/season status','Owner','Season state'),
    @('/season start','Owner','Open a season'),
    @('/season end','Owner','Close one and crown the Champion'),
    @('/laughtail status','Admin','Plugin and database health'),
    @('/laughtail rating','Admin','Prove the rating maths is correct'),
    @('/laughtail reload','Owner','Reload configuration. Never use vanilla /reload')
) @(3600,1400,4000)
Add-Note 'Seasons also roll over automatically now, with warnings at 7 days, 24 hours, 1 hour and 10 minutes. The manual commands remain for when something needs doing early.'
Add-Note 'The automatic rollover will REFUSE to end a season that has no Champion, and will say so loudly rather than inventing one. A season running late is a scheduling problem; a season with a fabricated winner is a credibility problem.'

Add-PageBreak

# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------
Add-Heading 'The screens' 1
Add-Para 'Everything below is reached from /menu.'
Add-Table @(
    @('Screen','What is on it'),
    @('Main menu','Homes, Berries, Random Teleport, Teleport to a player, Your rank, Rules, Shop, Bazaar, Friends, Paths and Story, Leaderboards, and a staff section if you have permission'),
    @('Shop','Every item with its live buy and sell price, category buttons, and a search. Items above your rank are shown greyed with the tier they need'),
    @('Sell box','Put items in, watch the value add up, click once to sell'),
    @('Homes','One bed per home, click to travel, and a button to buy another slot'),
    @('Your stats','Rank, RP, kills, deaths, K/D, Berries, season, Champion titles'),
    @('Bazaar','Your orders, and a button to collect what they earned'),
    @('Paths and Story','Six Paths with progress bars, your House, your titles, and the current chapter'),
    @('Staff tools','Moderation and owner commands, visible only with permission')
) @(2400,6600)
Add-Note 'Locked shop items are shown rather than hidden, on purpose. Hiding them would make rank feel like nothing exists beyond your tier; showing them is the reason to climb.'
Add-Note 'The greying is decoration. The actual refusal happens on the server after checking your rank in the database, so a modified game cannot click its way past it.'

Add-Heading 'Your screen while playing' 2
Add-Para 'A panel on the right shows your rank, RP, kills and deaths, Berries, homes used, Champion titles, your focused Path with a progress bar, and the season. The header shimmers. It is the only animated thing on the server, deliberately.'

Add-PageBreak

# ---------------------------------------------------------------------------
# Not built
# ---------------------------------------------------------------------------
Add-Heading 'Not built yet' 1
Add-Para 'Listed because a command book that quietly omits the gaps is a sales brochure.'
Add-Table @(
    @('Missing','What it means for players'),
    @('Auction house','You cannot sell an enchanted or named item to another player yet. The bazaar handles plain resources only'),
    @('Land claims','Nothing currently stops another player breaking your build'),
    @('Chat filter','No automatic protection against spam or abusive language yet'),
    @('Cosmetics','No hats, trails or particles yet'),
    @('Settings page','You cannot yet turn off individual messages'),
    @('Anti-cheat','No automatic cheat detection. Explained below'),
    @('Discord','No linked chat or alerts'),
    @('Website','No public rules page, Terms or Privacy policy yet')
) @(2400,6600)

Add-Heading 'The one that matters' 2
Add-Para 'There is no anti-cheat running. Not because it was forgotten - it was installed and tested twice and failed both times, because this server runs a very new version of Minecraft and no anti-cheat supports it yet.'
Add-Para 'That is a real risk on a server whose entire value is a fair PvP ladder, and it is an owner decision rather than an engineering one: wait for support and delay opening, open without it, or move back to an older Minecraft version where it works - which is what made movement feel broken before.'
Add-Note 'This is recorded in the project as OA-32 and is the single largest thing standing between this server and paying players.'

# ---------------------------------------------------------------------------
# Assemble the .docx
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $work | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work '_rels') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work 'word') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work 'word\_rels') | Out-Null

$contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>
'@
Set-Content -LiteralPath (Join-Path $work '[Content_Types].xml') -Value $contentTypes -Encoding UTF8

$rels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@
Set-Content -LiteralPath (Join-Path $work '_rels\.rels') -Value $rels -Encoding UTF8

$docRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>
'@
Set-Content -LiteralPath (Join-Path $work 'word\_rels\document.xml.rels') -Value $docRels -Encoding UTF8

$styles = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="21"/></w:rPr></w:rPrDefault>
<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>
<w:pPr><w:keepNext/><w:spacing w:before="360" w:after="160"/><w:pBdr><w:bottom w:val="single" w:sz="8" w:space="4" w:color="C9A227"/></w:pBdr></w:pPr>
<w:rPr><w:b/><w:color w:val="7A5C00"/><w:sz w:val="40"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>
<w:pPr><w:keepNext/><w:spacing w:before="280" w:after="120"/></w:pPr>
<w:rPr><w:b/><w:color w:val="1F3864"/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Note"><w:name w:val="Note"/><w:basedOn w:val="Normal"/>
<w:pPr><w:ind w:left="284"/><w:spacing w:after="80"/></w:pPr>
<w:rPr><w:i/><w:color w:val="595959"/><w:sz w:val="19"/></w:rPr></w:style>
<w:style w:type="table" w:styleId="LTGrid"><w:name w:val="LT Grid"/>
<w:tblPr><w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>
</w:styles>
'@
Set-Content -LiteralPath (Join-Path $work 'word\styles.xml') -Value $styles -Encoding UTF8

$numbering = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>
<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/>
<w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>
'@
Set-Content -LiteralPath (Join-Path $work 'word\numbering.xml') -Value $numbering -Encoding UTF8

$doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
    '<w:body>' + $body.ToString() +
    '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>' +
    '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="709" w:footer="709" w:gutter="0"/>' +
    '</w:sectPr></w:body></w:document>'
# UTF8 without BOM: Word rejects a BOM inside the XML parts.
[System.IO.File]::WriteAllText((Join-Path $work 'word\document.xml'), $doc, (New-Object System.Text.UTF8Encoding($false)))

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $outFile) { Remove-Item -LiteralPath $outFile -Force }

# ENTRY NAMES MUST USE FORWARD SLASHES. CreateFromDirectory on Windows writes "word\document.xml",
# and Word rejects the file outright - the OOXML package format requires "/" as the separator
# regardless of platform. The first version of this script produced a 10 KB file that looked correct
# and would not open, which is exactly the kind of failure worth a comment.
#
# [Content_Types].xml is added FIRST and uncompressed-first because some readers expect it at the
# start of the archive.
$order = @(
    '[Content_Types].xml',
    '_rels/.rels',
    'word/document.xml',
    'word/styles.xml',
    'word/numbering.xml',
    'word/_rels/document.xml.rels'
)
$zip = [System.IO.Compression.ZipFile]::Open($outFile, 'Create')
try {
    foreach ($entryName in $order) {
        $src = Join-Path $work ($entryName -replace '/', '\')
        if (-not (Test-Path -LiteralPath $src)) { throw "missing part: $entryName" }
        $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try {
            $bytes = [System.IO.File]::ReadAllBytes($src)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally { $stream.Dispose() }
    }
} finally { $zip.Dispose() }
Remove-Item -LiteralPath $work -Recurse -Force

$size = [math]::Round((Get-Item $outFile).Length / 1KB, 1)
Write-Host ("wrote docs/LaughTail-Command-Book.docx ({0} KB)" -f $size)

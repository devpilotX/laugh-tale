# gen-handbook.ps1 - emits docs/LaughTail-Server-Handbook.docx
#
# The A-to-Z explanation of how the server WORKS, as opposed to the command book, which lists what to
# TYPE. Two documents rather than one because they answer different questions and get read at different
# times: the command book is a reference you keep open, the handbook is read once and then argued with.
#
# It shares its .docx assembly with gen-command-book.ps1. That duplication is deliberate and small -
# factoring it into a shared module would mean a third file to keep in step for two callers.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path (Join-Path $root 'docs') 'LaughTail-Server-Handbook.docx'
$work = Join-Path $env:TEMP ("lthand-" + [guid]::NewGuid().ToString('N'))

function XmlEsc([string]$s) {
    if ($null -eq $s) { return '' }
    $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}
$body = New-Object System.Text.StringBuilder
function H1([string]$t) { $null = $body.Append('<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function H2([string]$t) { $null = $body.Append('<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function H3([string]$t) { $null = $body.Append('<w:p><w:pPr><w:pStyle w:val="Heading3"/></w:pPr><w:r><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function P([string]$t)  { $null = $body.Append('<w:p><w:r><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function N([string]$t)  { $null = $body.Append('<w:p><w:pPr><w:pStyle w:val="Note"/></w:pPr><w:r><w:rPr><w:i/><w:color w:val="595959"/></w:rPr><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function B([string]$t)  { $null = $body.Append('<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function Code([string]$t) { $null = $body.Append('<w:p><w:pPr><w:ind w:left="284"/><w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="19"/></w:rPr><w:t xml:space="preserve">' + (XmlEsc $t) + '</w:t></w:r></w:p>') }
function PB { $null = $body.Append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>') }
function T($rows, $widths) {
    $null = $body.Append('<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblBorders>')
    foreach ($s in 'top','left','bottom','right','insideH','insideV') { $null = $body.Append('<w:' + $s + ' w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>') }
    $null = $body.Append('</w:tblBorders></w:tblPr><w:tblGrid>')
    foreach ($w in $widths) { $null = $body.Append('<w:gridCol w:w="' + $w + '"/>') }
    $null = $body.Append('</w:tblGrid>')
    $first = $true
    foreach ($row in $rows) {
        $null = $body.Append('<w:tr>')
        if ($first) { $null = $body.Append('<w:trPr><w:tblHeader/></w:trPr>') }
        for ($i = 0; $i -lt $row.Count; $i++) {
            $shd = if ($first) { '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>' } else { '' }
            $rpr = if ($first) { '<w:rPr><w:b/></w:rPr>' } else { '' }
            $null = $body.Append('<w:tc><w:tcPr><w:tcW w:w="' + $widths[$i] + '" w:type="dxa"/>' + $shd + '</w:tcPr><w:p><w:r>' + $rpr + '<w:t xml:space="preserve">' + (XmlEsc $row[$i]) + '</w:t></w:r></w:p></w:tc>')
        }
        $null = $body.Append('</w:tr>')
        $first = $false
    }
    $null = $body.Append('</w:tbl><w:p/>')
}

# ===========================================================================
H1 'LaughTail SMP - Server Handbook'
P 'How this server works, and why it works that way. A to Z.'
N ("Generated " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " by scripts/gen-handbook.ps1. The companion document, LaughTail-Command-Book.docx, lists what to type. This one explains what is happening.")

H2 'The one-paragraph version'
P 'LaughTail is a paid, whitelist-only survival server. You pay once for access and that is the only thing money buys - there are no ranks for sale, no crates, no gambling, and no way to buy an advantage. Rank comes from beating other players in combat and from nothing else. There is one currency, Berries. Seasons last a month and end with exactly one Champion. Alongside the combat ladder there is a second ladder made of Paths, Houses and a season-long story, which awards titles and recognition but never power.'

H2 'The three laws everything else follows from'
P 'These are not marketing. Every feature in this document is shaped by them, and several obvious features were refused because they broke one.'
B 'Total equality. Every paying player has identical abilities. Nothing is for sale but access.'
B 'Rank is PvP only. Two hours of mining changes your rank by exactly zero. This is verified by a test, not promised.'
B 'One currency. There is no second currency and never will be, because dual currencies are how servers hyperinflate.'
N 'Things refused for breaking these: a shard shop as a second currency; donor ranks; profession bonuses that grant combat power; House taxes creating a parallel economy. Each is recorded in the project decision log with its reasoning.'

PB
# ===========================================================================
H1 'How ranking works'

H2 'The idea'
P 'Your rank is a number called RP, and it only moves when you fight another player. Beat someone and you take RP from them. The amount depends on the gap between you: beating someone far above you is worth a great deal, and beating someone far below you is worth almost nothing.'
P 'Everyone starts at 1000 RP, which is the Raider tier. There are ten tiers.'
T @(
    @('Tier','RP','What it means'),
    @('Wanderer','0','Below the starting line. You have lost more than you have won'),
    @('Settler','900','Slightly below starting'),
    @('Raider','1000','Where everyone begins'),
    @('Fighter','1100','Winning more than losing'),
    @('Warrior','1200','Consistently good'),
    @('Gladiator','1325','Strong'),
    @('Champion','1450','Top of the server for most seasons'),
    @('Warlord','1600','Rare'),
    @('Legend','1775','Very rare'),
    @('Mythic','2000','Almost nobody')
) @(2000,1400,5600)

H2 'Why demotion exists'
P 'Losing costs RP, and a bad run drops you a tier. That is deliberate. A ladder you cannot fall down stops measuring skill and starts measuring how long someone has played - and then the top of the board is whoever showed up first, permanently.'

H2 'What cannot give you rank'
P 'Mining, farming, building, trading, exploring, buying, selling, levelling a Path, joining a House, completing the story, being in the same House as a good fighter, or paying money. None of it moves RP by a single point.'
N 'This is enforced structurally rather than by discipline: nothing in the roleplay or economy code shares a table with the rating table, and no foreign key points at it. A test asserts that.'

H2 'Anti-farming'
P 'Killing the same person repeatedly pays less each time and eventually nothing. Kills between accounts on the same connection award nothing and raise a staff alert. Staff kills are excluded. Killing someone who has just respawned does not count.'
N 'The exact thresholds are deliberately not published. Publishing detector thresholds teaches people how to stay just underneath them.'

H2 'Combat tagging'
P 'Taking or dealing damage from another player tags you for 15 seconds. While tagged you cannot teleport home, use random teleport, or accept a teleport request. Logging out while tagged drops your inventory where you stood and is recorded as a death, with the kill credited to whoever you were fighting.'
P 'Without this, every losing fight ends with the loser typing /home or pulling the plug, and a ladder where the loser escapes is not a ladder.'

H2 'Seasons and the Champion'
P 'A season lasts 30 days. The server warns everyone at 7 days, 24 hours, 1 hour and 10 minutes before the end. When it ends, whoever holds the highest rating is crowned Champion - exactly one, enforced by the database so a second cannot exist even by mistake.'
P 'The Champion receives a permanent title, kept forever, announced whenever they join. They receive no Berries, no items, no gear, no stat bonus, no permission and no shop discount.'
N 'That is the most important sentence in this section. A Champion with a gameplay advantage would make the next season unfair by construction. The title is valuable precisely because it buys nothing.'

H2 'What a new season resets, and what it does not'
T @(
    @('Resets','Survives forever'),
    @('Combat rating, back to 1000','Berries'),
    @('House standing','Statistics: kills, deaths, playtime'),
    @('The story, which starts again','Homes, including bought slots'),
    @('','Path levels and titles'),
    @('','Champion titles from past seasons')
) @(4500,4500)
N 'The split is identity versus competition. What you own and what you have become are yours. What you are currently winning is a contest, and a contest that never restarts is a museum.'

PB
# ===========================================================================
H1 'How the economy works'

H2 'One currency'
P 'Berries. Earned by selling what you gather, filling other players'' orders, and being paid by other players. Every single movement of Berries writes a permanent ledger row, and the ledger adds up to the balance - which is how the server can prove it has neither lost nor invented money.'

H2 'The shop, and why prices move'
P 'The server buys and sells over 750 items - essentially everything a player can legitimately obtain. Prices are not fixed: buying pushes a price up, selling pushes it down, and prices drift back toward normal at 5% an hour. A price can never move more than 20% away from its base in either direction.'
P 'Base prices are not invented per item. The anchor is 1,200 Berries for an hour of focused play, and every item sits in a rarity band relative to that. Cobblestone is worth 1 because you get thousands of it; a nether star is worth 9,000 because it is a day of play.'
N 'Prices come from eight RARITY BANDS rather than being chosen per item, and the gaps widen as they climb - cobblestone 1, coal 4, iron 30, diamond 90, shulker shell 300, netherite 1200, nether star 9000. With hundreds of items, hand-picking each price guarantees an inconsistent pair somewhere, and an inconsistent pair is a money printer. Storage blocks are priced as exactly nine of their contents for the same reason.'

H2 'The spread, and the money-printer audit'
P 'The shop sells at the listed price and buys back at HALF of it. An item listed at 200 pays 100 when you sell one, so buying and reselling loses half its value. That is the server''s cut and the reason you cannot make money by trading with the shop.'
P 'The harder version of that problem is crafting: buy inputs, transform them, sell the output for more than the parts cost. On every restart the server walks all 1,585 recipes it knows and checks whether any of them can be run at a profit - assuming the worst case, with inputs at their cheapest and the output at its dearest.'
P 'If it finds one, the shop closes itself and refuses to trade until it is fixed.'
N 'That audit found 220 real money printers the first time the full catalogue was priced, almost all of them recipes that produce more units than they consume - one log costs 4 and yields four planks. Rather than hand-fixing hundreds of prices, the server now LOWERS any price a recipe could profit from, automatically, on every boot; 191 prices are adjusted this way. Berries once created cannot be un-created without rolling back everyone who traded since, so a shop that closes itself is recoverable and one that quietly prints money is not.'

H2 'Daily sell limits'
P 'You can sell at most 3,600 Berries worth per category per day, resetting at midnight UTC. That limit is what stops one player with a huge farm flooding the market and crashing a price for everyone else.'

H2 'Shop tiers'
P 'Buying is gated by rank: eight tiers, matching the ten rank tiers. A Tier 1 player cannot buy a Tier 8 item by any means, including a modified game - the refusal happens on the server after reading your rank from the database, and the greyed-out button in the menu is only decoration.'
P 'Selling is never gated. A brand-new player must be able to turn what they mine into Berries in their first minute, or the economy has no entry point.'
N 'Locked items are shown rather than hidden, with the tier they need. Hiding them would make rank feel like nothing exists beyond your tier; showing them is the reason to climb.'

H2 'The bazaar - trading with other players'
P 'A buy order says "I will pay 20 each for 500 iron". A sell order says the opposite. The server matches them automatically, and orders fill whether or not you are online. That is the entire point.'
P 'When an order is placed, your Berries or your items leave you immediately and are held by the server. Nothing is held in memory - if the server is killed mid-trade, the trade either happened completely or did not happen at all.'
P 'The order that waited sets the price. If you offer 25 and someone is already selling at 20, you pay 20 and the difference comes back to you.'
N 'That last rule matters more than it looks. If the incoming order set the price, you could watch the book, place an order one Berry better, and capture the whole spread every time. Rewarding whoever committed first rewards providing liquidity, which is what makes a market usable.'
P 'You cannot trade with yourself. Doing so would move Berries between your own accounts while generating fake trading volume, which corrupts every price signal the shop depends on.'

H2 'Paying other players'
P 'Payments above 5,000 Berries carry a 5% tax, shown before it applies. The tax is a sink: it removes Berries from the economy, which is what stops long-term inflation on a server where money is constantly created by selling.'

PB
# ===========================================================================
H1 'How roleplay works'

H2 'Why it exists'
P 'Because rank is PvP-only, a player who loses fights would have nothing to climb. They mine, build and trade and no visible number moves. Most players are not top-decile fighters, so a server where they see no progress loses them.'
P 'Roleplay is the second ladder - a place to climb for everyone not winning fights, built so it can never leak into the first.'

H2 'Paths'
P 'Six Paths, each levelling from something you already do, up to level 50. You can focus one to show on your screen with a progress bar.'
T @(
    @('Path','Advances from'),
    @('Delver','Mining. Rare ore and deep stone are worth much more than cobblestone'),
    @('Cultivator','Harvesting crops'),
    @('Hunter','Killing hostile creatures. Bosses are worth hundreds of times a zombie'),
    @('Wayfinder','Distance travelled on foot. Teleports do not count'),
    @('Artificer','Crafting and placing blocks'),
    @('Broker','Trading. Scaled so sustained trading counts and one huge transaction does not')
) @(1800,7200)
P 'Titles arrive at levels 5, 10, 20, 30, 40 and 50: Apprentice, Journeyman, Adept, Master, Grandmaster, and Eternal. A title is announced to the whole server when you earn it.'
N 'Titles land at six milestones rather than every level on purpose. A reward at every level becomes wallpaper - nobody remembers their fourteenth title.'

H2 'Houses'
P 'Four Houses: Ember, Tide, Verdant and Ashen. You choose one, and it can be changed but the server counts how often. House standing rises from everything members do - Path progress, trading, fighting - so a House of farmers can beat a House of fighters.'
P 'Standing resets each season and pays out in banners, a title and a monument entry. Nothing else.'
N 'Houses are deliberately not factions with land, wars or taxes. Taxes would create a second economy alongside the Berry ledger, which breaks the guarantee that value is created in exactly one place.'

H2 'The Chronicle'
P 'A five-chapter story for each season, and progress is server-wide rather than per-player. Everyone''s mining counts toward the same number.'
P 'Every chapter needs more than one kind of player - blocks mined AND creatures defeated AND orders filled - so no single play style can finish one alone. That is what makes farmers and fighters useful to each other without forcing them into a party.'
P 'Season 1''s chapters are The Rumour, The First Marker, Deep Water, What the Stones Remember, and Laugh Tale. Completing one awards a title to everyone online and unlocks the next.'

H2 'In-character chat'
P '/me describes an action to people within 100 blocks. /local speaks only to people who can see you. /hc reaches your House anywhere.'
N 'Breaking character is not punishable. Hard roleplay enforcement needs constant staff attention this server does not have, and it turns moderation into taste policing - which is the fastest way to make a small server feel hostile. These are tools for people who want them.'

H2 'The rule that governs all of it'
P 'Roleplay grants status, never power. Titles, colours, banners, recognition, access to the story: unlimited. Damage, health, speed, drop rates, discounts, permissions: never.'
N 'This is held by the database, not by good intentions. There is no column anywhere in the roleplay tables that could store a bonus, and a test checks for one on every run. Adding one would require a schema change somebody has to review.'

PB
# ===========================================================================
H1 'Staff ranks, and how to promote someone'

H2 'The six groups'
T @(
    @('Group','Shown as','Can do'),
    @('default','Member','Everything a paying player does. This is normal'),
    @('helper','Helper','Warn, short mute, kick, view and claim reports'),
    @('mod','Mod','Unmute, temporary ban, inspect blocks'),
    @('srmod','SrMod','Permanent ban, unban, review other staff'),
    @('admin','Admin','Access grants, configuration, plugin status'),
    @('owner','Owner','Seasons, economy, everything')
) @(1600,1600,5800)

H2 'There are no VIP ranks, and there will not be'
P 'No VIP, Premium, Elite, MVP, Donor or any paid tier. Every paying player is a Member with exactly the same abilities as every other.'
P 'This is the product rather than a limitation. It is also what keeps the server compliant with Mojang''s commercial rules, which permit charging for access but forbid selling gameplay advantage. And it makes pay-to-win impossible by construction instead of by policy - there is no advantage to sell, so no future decision can accidentally sell one.'
N 'If a cosmetic-only supporter tag is ever wanted, it must grant literally nothing but a colour, and it needs its own written decision first. The moment it grants a command, a slot or a discount, the whole model is gone.'

H2 'How to promote someone to staff'
P 'Permissions are managed by LuckPerms. Run these from the server console or in game as Owner.'
Code '/lp user <name> parent set helper'
Code '/lp user <name> parent set mod'
Code '/lp user <name> parent set srmod'
Code '/lp user <name> parent set admin'
P 'To demote someone back to a normal player:'
Code '/lp user <name> parent set default'
P 'To see what someone currently has:'
Code '/lp user <name> info'
N 'Use parent SET rather than parent ADD. Add leaves the old group in place, so a demoted admin keeps admin, and the symptom is that a demotion appears to have worked and has not.'

H2 'The permission ladder lives in a file'
P 'server/permissions.yml in the project is the source of truth. It is applied by a script and then verified node by node, so what is running matches what is written down.'
P 'The Admin group carries EXPLICIT DENIALS on a list of dangerous permissions - things that could destroy the server, corrupt the economy, or hide an audit trail - rather than simply not being granted them.'
N 'An absence and a denial look equivalent and are not. Any future wildcard, any plugin shipping a permissive default, or anyone adding a convenience permission can turn an absence into a grant. An explicit denial beats an inherited grant and keeps working regardless.'

H2 'Granting paid access'
P 'Access is manual and deliberate. When somebody pays you, add them:'
Code '/access grant <player> <payment-reference> <amount-in-paise>'
P 'The payment reference must be unique, so the same payment cannot be recorded twice. To check that the whitelist and the paid records agree:'
Code '/access audit'
N 'That audit checks both directions, because the two failure modes are different problems. Whitelisted with no payment is unexplained access. Paid with no whitelist is somebody who gave you money and cannot get in.'

H2 'The audit trail cannot be edited'
P 'Every staff action, including failed attempts, writes a permanent row. The table refuses UPDATE and DELETE at the database level - not by policy, by trigger. Nobody can quietly edit history, including you.'

PB
# ===========================================================================
H1 'Everything is in the menu'
P 'Every command a normal player needs is reachable from /menu without typing. That is deliberate: most players never read a command list, and a feature nobody can find is a feature that does not exist.'
T @(
    @('Screen','Reached by','What it covers'),
    @('Main menu','/menu, /lt','The front door to everything below'),
    @('Shop','Main menu','Buy, sell prices, categories, search, locked items'),
    @('Sell box','Shop','Drop items in, see the value, one click'),
    @('Berries','Main menu','Balance, pay someone, rich list'),
    @('Homes','Main menu','Travel, set, delete, buy a slot'),
    @('Teleports','Main menu','Send, accept, deny requests'),
    @('Bazaar','Main menu','Your orders, collect winnings'),
    @('Your stats','Main menu','Rank, RP, kills, deaths, Berries, titles'),
    @('Paths and Story','Main menu','Six Paths, House, titles, Chronicle, in-character chat'),
    @('Leaderboards','Main menu','Rank, kills, streak, playtime'),
    @('Friends','Main menu','List, add by clicking a player'),
    @('Staff tools','Main menu','Visible only with permission')
) @(2200,1800,5000)
N 'Where a number or a name is needed - an amount to pay, a home name, something to say in character - the menu asks you to type it in chat and then runs the command for you. A chest cannot hold a sentence, and click-to-increment interfaces where entering 3,470 takes forty clicks are worse than typing.'
N 'Every menu click runs the command AS YOU. Permissions, refusals and audit rows behave exactly as if you had typed it, so the menu can never be a way around a rule.'

H1 'What is not built yet'
T @(
    @('Missing','Effect on players'),
    @('Auction house','Enchanted or named items cannot be sold to other players yet'),
    @('Land claims','Nothing stops another player breaking your build'),
    @('Chat filter','No automatic spam or abuse protection'),
    @('Cosmetics','No hats, trails or particles'),
    @('Settings page','Individual messages cannot be turned off'),
    @('Anti-cheat','No automatic cheat detection'),
    @('Discord','No linked chat or alerts'),
    @('Website and legal pages','No public rules, Terms or Privacy policy')
) @(2400,6600)
H2 'The one that decides when you can open'
P 'There is no anti-cheat running. It was installed and tested twice and failed both times, because this server runs a very new version of Minecraft that no anti-cheat supports yet.'
P 'On a server whose entire value is a fair PvP ladder, that is the largest risk there is. It is a decision rather than a task: wait for support and delay opening, open without it, or move back to an older Minecraft version where it works - which is what made movement feel broken before.'

# ===========================================================================
New-Item -ItemType Directory -Force -Path $work | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work '_rels') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work 'word') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work 'word\_rels') | Out-Null

Set-Content -LiteralPath (Join-Path $work '[Content_Types].xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>
'@
Set-Content -LiteralPath (Join-Path $work '_rels\.rels') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@
Set-Content -LiteralPath (Join-Path $work 'word\_rels\document.xml.rels') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>
'@
Set-Content -LiteralPath (Join-Path $work 'word\styles.xml') -Encoding UTF8 -Value @'
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
<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/>
<w:pPr><w:keepNext/><w:spacing w:before="200" w:after="80"/></w:pPr>
<w:rPr><w:b/><w:color w:val="404040"/><w:sz w:val="23"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Note"><w:name w:val="Note"/><w:basedOn w:val="Normal"/>
<w:pPr><w:ind w:left="284"/><w:spacing w:after="80"/></w:pPr>
<w:rPr><w:i/><w:color w:val="595959"/><w:sz w:val="19"/></w:rPr></w:style>
</w:styles>
'@
Set-Content -LiteralPath (Join-Path $work 'word\numbering.xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>
<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/>
<w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>
'@

$doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' +
    $body.ToString() +
    '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr>' +
    '</w:body></w:document>'
[System.IO.File]::WriteAllText((Join-Path $work 'word\document.xml'), $doc, (New-Object System.Text.UTF8Encoding($false)))

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $outFile) { Remove-Item -LiteralPath $outFile -Force }
# Forward slashes, or Word rejects the package. See the note in gen-command-book.ps1.
$order = @('[Content_Types].xml','_rels/.rels','word/document.xml','word/styles.xml','word/numbering.xml','word/_rels/document.xml.rels')
$zip = [System.IO.Compression.ZipFile]::Open($outFile, 'Create')
try {
    foreach ($e in $order) {
        $src = Join-Path $work ($e -replace '/', '\')
        if (-not (Test-Path -LiteralPath $src)) { throw "missing part: $e" }
        $entry = $zip.CreateEntry($e, [System.IO.Compression.CompressionLevel]::Optimal)
        $st = $entry.Open()
        try { $bytes = [System.IO.File]::ReadAllBytes($src); $st.Write($bytes, 0, $bytes.Length) }
        finally { $st.Dispose() }
    }
} finally { $zip.Dispose() }
Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ("wrote docs/LaughTail-Server-Handbook.docx ({0} KB)" -f [math]::Round((Get-Item $outFile).Length / 1KB, 1))

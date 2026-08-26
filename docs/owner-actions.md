# LaughTail SMP - Owner Actions

**Append-only.** Nothing is ever deleted from this file. Resolved items are marked `RESOLVED <date>` and left in place (spec 32.5).

Every entry uses the fixed format from spec 32.2. One item per entry, never batched, so each can be actioned without a follow-up question.

**Opened this session: 24 items.** Ordered by what blocks the most work, not by importance.

Nothing here is guesswork on my part. Where the specification supplies a recommended default (32.4), I have named it and I will proceed on it if you say nothing - but I will record that I did.

---

## Tier 1 - blocks the very next step

```
RESOLVED 2026-08-26 - OA-01 Git is not installed on this PC
What I needed: Git for Windows installed on the machine Kiro runs on.
Why: Spec 33.3 step 3 requires the first commit in history to be .gitignore alone;
     33.4 step 5 requires the split to be committed; 33.6 item 5 makes this a
     pre-flight gate. Acceptance 33-2 and 32-6 depend on it.
How it was resolved: installed Git 2.55.0.3 with
     winget install --id Git.Git -e --source winget
     under the owner's "you have full permission" instruction. Local, reversible,
     and touches nothing on the VPS - so it does not breach the snapshot-first
     rule in 33.2, which protects the host, not the build PC.
Evidence: three commits exist. The root commit 3087a56 contains .gitignore and
     nothing else, confirmed by git show --name-only on git rev-list --max-parents=0.
     Commit 1b1be77 carries AGENTS.md, README.md, the 43 split files, INDEX.md and
     the scripts. Commit 5115674 carries the six living documents. Working tree clean.
Still outstanding: no remote is configured. See OA-02.
```

```
BLOCKED - OA-02 GitHub repository and a way to push to it
What I need: a GitHub repository named laughtail-smp, and either a deploy key or a
     fine-grained personal access token that can push to it.
Why: Spec 32.3 rows 5 and 6. Section 29 makes the repository the only source of
     truth; 29-11 and 33-2 depend on it. Law 6: the server is disposable, the data
     is not - without a remote, a dead PC loses the build.
Steps for the owner:
  1. Go to github.com, click the "+" top right, then "New repository".
  2. Repository name: laughtail-smp   Visibility: Private (see OA-15).
     Do NOT tick "Add a README file", "Add .gitignore", or "Choose a licence" -
     the first commit must be our .gitignore and nothing else.
  3. Click "Create repository", then copy the SSH URL shown
     (it looks like git@github.com:<you>/laughtail-smp.git) and paste it to me here.
  4. Then: your avatar, top right, Settings, Developer settings,
     Personal access tokens, Fine-grained tokens, Generate new token.
     Repository access: Only select repositories, pick laughtail-smp.
     Permissions: Contents = Read and write. Nothing else.
     Paste the token into a NEW file at C:\Laugh-Tale\docs\private\github-token.txt
     - that folder is git-ignored, so it can never be committed.
What I will do when it arrives: add the remote, push the Day Zero commits, and
     verify the push landed.
What I am doing meanwhile: OA-01 is the harder blocker; both are needed together.
```

```
BLOCKED - OA-03 A verified pre-build snapshot of the VPS
What I need: a full AWS snapshot of instance i-0d5663cfa8038b494, confirmed complete,
     before I change anything on the host.
Why: Spec 33.2 calls this "the single most important step on Day Zero". 33.6 items
     1 and 2, and acceptance 33-1. GitHub protects the code and Pelican backups
     protect one server's files; neither protects the machine. If the Panel, Docker
     or the firewall breaks, this snapshot is the only fast recovery.
Steps for the owner:
  1. AWS Console, region Asia Pacific (Mumbai) ap-south-1, service EC2, Instances.
  2. Tick instance i-0d5663cfa8038b494. Actions, then "Image and templates",
     then "Create image".
  3. Image name: laughtail-pre-build-2026-08-26
     Leave "No reboot" UNTICKED if you can accept a brief restart (a rebooted
     image is more reliable). Click "Create image".
  4. Left menu, AMIs. Wait until Status shows "Available", not "Pending".
  5. Then click Snapshots in the left menu and confirm the snapshot is "Completed".
  6. Find the restore path now, before you need it: from the AMI, Actions,
     "Launch instance from AMI". You do not have to launch it - just confirm you
     have seen the button.
  7. Reply "snapshot done" with the AMI id (it starts ami-).
What I will do when it arrives: begin Phase 0 step 0.1, host remediation.
What I am doing meanwhile: nothing on the host. Only read-only inspection has
     happened so far, which is safe without a snapshot.
```

---

## Tier 2 - host facts that change the plan

```
BLOCKED - OA-04 The disk is too small for the worlds
What I need: the root EBS volume grown from 19 GB to at least 60 GB.
Why: Measured this session: 9.5 GB free. Section 20 Phase 2 pregenerates five
     worlds with borders 6,000 / 2,000 / 3,000 / 3,000 using Chunky, and Section 5
     also wants hourly database and six-hourly world backups staged locally before
     going offsite. The overworld alone at a 6,000 border is several GB of region
     files. Acceptance rows 4 and 45 to 47 sit behind Phase 2, and a full disk on a
     Minecraft server corrupts region files rather than failing cleanly.
Steps for the owner:
  1. AWS Console, EC2, region ap-south-1, left menu "Volumes".
  2. Tick the 20 GiB volume attached to i-0d5663cfa8038b494.
  3. Actions, "Modify volume". Set Size to 60. Leave type as it is. Click Modify,
     then Modify again to confirm.
  4. Wait until State shows "in-use - completed (100%)". This is online; the
     server does not need to stop.
  5. Reply "disk grown".
What I will do when it arrives: grow the partition and filesystem on the host with
     growpart and resize2fs, confirm df shows the new size, and record it.
     This is a two-command, reversible-by-snapshot operation.
What I am doing meanwhile: Phase 0 steps that do not write large files.
```

```
BLOCKED - OA-05 The instance is burstable, which undermines the 20 TPS promise
What I need: a decision on how to get sustained CPU: either enable Unlimited credit
     mode on the current t4g.medium, or move to a non-burstable instance.
Why: Measured this session: the host is a t4g.medium in ap-south-1c. T-series
     instances have a baseline of 20 per cent of their vCPUs and earn credits at a
     fixed rate. Chunky pregeneration (Phase 2), the bot load test (Phase 6), war
     events and the Finale (Phase 7) are all sustained full-CPU work and will
     exhaust the balance. Once exhausted, the instance throttles to baseline and
     cannot hold 20 TPS - which is stated as a product requirement in 1.2, not an
     aspiration. Worse, Phase 6's entire purpose is to measure the player cap
     (row 21, row 19), and a cap measured on a throttled instance is not
     reproducible, so the number would be worthless. Note that acceptance 22-10
     measures CPU steal time, which does NOT detect T-instance throttling.
Steps for the owner - pick one:
  Option A, cheapest, least certain:
  1. AWS Console, EC2, Instances, tick i-0d5663cfa8038b494.
  2. Actions, "Instance settings", "Change credit specification".
  3. Tick Unlimited. Save. Note that surplus CPU is then billed per vCPU-hour.
  Option B, recommended, fixes memory too:
  1. Check the price of m7g.large (2 vCPU, 8 GB, ARM, non-burstable) in ap-south-1
     using the AWS Pricing Calculator at https://calculator.aws - I will not quote
     you a price.
  2. If acceptable: EC2, Instances, tick the instance, Instance state, Stop.
  3. Actions, "Instance settings", "Change instance type", choose m7g.large, Apply.
  4. Instance state, Start. The public IP will change unless an Elastic IP is
     attached - check that first, EC2, Elastic IPs.
  5. Reply with which option you chose.
What I will do when it arrives: re-measure the baseline, and if Option B, redo the
     memory plan with the extra 4 GB and revise the laughtail-dev allocation.
What I am doing meanwhile: Phase 0 steps 0.2 to 0.8, none of which are CPU-bound.
     I will not run pregeneration or any load test until this is settled.
```

```
BLOCKED - OA-06 Voice and Bedrock UDP ports are closed in two places
What I need: UDP 24454 and UDP 19132, plus UDP 25565, opened in the AWS security
     group attached to the instance. I will do the ufw half myself.
Why: Spec 32.3 rows 14 and 15. Acceptance row 6 requires the voice port proven open
     with a UDP-aware method, and row 64 requires two real clients hearing each
     other over the public internet. Measured this session: ufw allows 22, 80, 443,
     8443 and 25565/tcp only - no UDP rules at all - and a security group sits in
     front of ufw, so both must allow the traffic. Section 13 makes voice a
     flagship feature; row 67 requires it be switchable off without breaking
     anything, which is not a substitute for it working.
Steps for the owner:
  1. AWS Console, EC2, Instances, click i-0d5663cfa8038b494.
  2. Security tab, click the security group name listed there.
  3. "Inbound rules" tab, "Edit inbound rules".
  4. Add rule: Type "Custom UDP", Port range 24454, Source "Anywhere-IPv4",
     Description "LaughTail proximity voice".
  5. Add rule: Type "Custom UDP", Port range 19132, Source "Anywhere-IPv4",
     Description "Bedrock via Geyser".
  6. Add rule: Type "Custom UDP", Port range 25565, Source "Anywhere-IPv4",
     Description "Minecraft Java UDP".
  7. Save rules. Reply "udp open".
What I will do when it arrives: add the matching ufw rules, map the ports on the
     Pelican allocation, and verify from outside with a UDP-aware check, not a TCP
     port checker.
What I am doing meanwhile: Phase 0 work that does not need these ports.
```

```
BLOCKED - OA-07 Permission to stop the existing stock server
What I need: your explicit yes to stop the Pelican server currently running
     (container 4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22, up 2 days).
Why: Spec 33.6 item 11 requires the stock server to be stopped and not yet deleted.
     Never-break rule 2 forbids two Paper servers running at once, and the combined
     allocation exceeds this 3.8 GB box - the existing container alone is allocated
     3.0 GiB and 1.9 of 2 cores. laughtail-dev cannot be started while it runs.
     This is reversible: stopping is not deleting, and I will not delete it.
Steps for the owner:
  1. Confirm nobody is playing on it. It has white-list=false and max-players=20,
     so it is currently open to anyone who knows the IP.
  2. Reply "stop the stock server" - or stop it yourself from the Pelican Panel,
     Console tab, Stop button.
  3. Do NOT delete it. Spec 29.13c keeps it as the rollback path until dev passes
     its smoke test.
What I will do when it arrives: stop it, confirm it is stopped in the Panel, then
     create laughtail-dev with a correct allocation and heap.
What I am doing meanwhile: repository machinery in Phase 0.2, which needs no server.
```

```
BLOCKED - OA-08 Offsite backup destination
What I need: an object-storage bucket and credentials for encrypted offsite backups.
Why: Spec 32.3 row 16, Section 5.4, acceptance row 4 and 22-12. A backup stored on
     the same box is not a backup - if the instance is lost, so is the backup.
     Phase 0's gate is a completed restore drill, and it cannot be completed
     against a destination that does not exist.
Steps for the owner:
  1. Either AWS S3 - Console, S3, "Create bucket", name laughtail-backups-<random>,
     region ap-south-1, keep "Block all public access" ticked, Create.
     Then IAM, Users, "Create user" named laughtail-backup, no console access;
     attach an inline policy allowing only s3:PutObject, s3:GetObject and
     s3:ListBucket on that one bucket; create an access key.
  2. Or any provider you prefer (Backblaze B2, Wasabi, Cloudflare R2).
  3. Put the bucket name, region, access key id and secret into a new file at
     C:\Laugh-Tale\docs\private\backup-destination.txt (git-ignored).
What I will do when it arrives: write the backup script, run it, then run the
     restore drill and record it in docs/restore-drills.md.
What I am doing meanwhile: writing the backup and restore scripts against a local
     destination so only the credentials are outstanding.
```

```
BLOCKED - OA-09 Uptime monitor account
What I need: an account on any uptime monitoring service, with a monitor pointed at
     the server, and alerts going somewhere you actually read.
Why: Spec 32.3 row 17, Section 5.5, Phase 0's "monitoring and alerting live".
     AGENTS.md: never assume the owner will notice a silent failure.
Steps for the owner:
  1. Sign up at any of uptimerobot.com, betterstack.com or healthchecks.io.
     The free tier is sufficient.
  2. Create a monitor: type TCP port, host = the server's public IP, port 25565,
     interval 5 minutes, name "LaughTail Java". The IP is in
     scripts/host.env.ps1 on this PC, or in the AWS console under EC2, Instances.
  3. Add your email, and later the Discord webhook from OA-16, as alert contacts.
  4. Reply "monitor live".
What I will do when it arrives: wire the host health check to the same alert path
     and prove an induced failure raises an alert.
What I am doing meanwhile: writing the health-check script.
```

---

## Tier 3 - decisions and accounts needed before Phase 1

```
BLOCKED - OA-10 Store account with the access product created and priced
What I need: an account on a Minecraft-appropriate payment platform, with one
     product representing server access, priced.
Why: Spec 32.3 row 10, Section 3.8, Section 18.3. Acceptance rows 8, 9, 10, 11 and
     12 all exercise the store-to-whitelist pipeline, and row 16 requires legal
     pages live before any payment is possible. Section 3 is absolute: only access
     is ever sold, at one uniform price.
Steps for the owner:
  1. Create the account (Tebex is the established option and acts as merchant of
     record, which handles tax; the spec flags this in 3.8).
  2. Create exactly ONE package. Name it "LaughTail SMP Access".
     Create no other package, no tiers, no bundles, no discounts - 3.2 and Law 3
     make unequal capability a legal problem, not just a design one.
  3. Set the price per OA-12.
  4. Put the store's secret key and webhook secret into
     C:\Laugh-Tale\docs\private\store-credentials.txt (git-ignored).
What I will do when it arrives: build the idempotent, UUID-keyed grant pipeline and
     prove rows 8, 9, 10 and 11 including a real test refund.
What I am doing meanwhile: building the whitelist and grant schema, which is
     store-agnostic.
```

```
BLOCKED - OA-11 A payment method that settles in INR
What I need: confirmation that your chosen store can pay out to you in INR, and the
     payout account configured.
Why: Spec 32.3 row 11 - your players pay in INR. If payouts cannot settle, the
     paywall is theatre.
Steps for the owner:
  1. In the store's dashboard, open Payments or Payouts settings.
  2. Confirm INR is a supported settlement currency and add your bank details.
  3. Reply "INR payouts configured".
What I will do when it arrives: nothing technical; this unblocks going live, not
     building.
What I am doing meanwhile: the grant pipeline, which is currency-agnostic.
```

```
BLOCKED - OA-12 The access price, and whether it recurs
What I need: one number, and whether it is one-time or monthly.
Why: Spec 24.1 calls this "the single most consequential unanswered question".
     32.4 lists it as owner-only. Mojang's Commercial Usage Guidelines require one
     uniform price for everyone (Section 3.3), so this is a legal constraint as well
     as a commercial one.
Steps for the owner:
  1. Decide the amount in INR.
  2. Decide one-time or monthly. The specification recommends ONE-TIME for launch:
     far less to build, far less to support, and you can add a subscription later,
     whereas converting subscriptions to one-time is much harder.
  3. Reply with, for example: "499 INR, one-time".
What I will do when it arrives: set it in the store and in the grant logic.
What I am doing meanwhile: proceeding on the 24.1 default, which is to build the
     grant table with a boolean plus a NULLABLE expiry timestamp. Null expiry means
     permanent access. That one column keeps both models open at zero cost, so the
     build genuinely does not wait on this. Recorded as decision D-0002.
```

```
BLOCKED - OA-13 Owner-approved Terms, Privacy and Refund text
What I need: your approval of the three legal pages before any payment can be taken.
Why: Spec 32.3 rows 12 and 21, Section 3.8, acceptance row 16 requires all three
     live and linked BEFORE payment is possible. Section 3.8 also states bans are
     not refunded, and that this must be stated before purchase.
Steps for the owner:
  1. Reply "draft the legal pages" and I will write plain-language drafts of
     Terms of Service, Privacy Policy and Refund Policy from Sections 3.8, 14.4
     and 31.13.
  2. Read them. They are short by design.
  3. Tell me what to change, then say "approved".
  4. Note: I am not a lawyer and these are drafts, not legal advice. For a paid
     service taking money from the public, having them reviewed is money well spent.
What I will do when it arrives: publish them on the website in Phase 8 and link
     them from the store before the product goes live.
What I am doing meanwhile: nothing depends on this until Phase 1's store test.
```

```
BLOCKED - OA-14 Licence for the repository
What I need: which licence goes in the LICENSE file.
Why: Spec 32.3 row 22, 29.12, acceptance 29-12. Spec 33.3 step 4 lists LICENSE in
     the tree. I have NOT created a licence file, because putting a licence on your
     work is your decision and a wrong one is hard to walk back.
     29.12 also flags that a GPL cosmetics plugin could affect whether the
     repository can be public at all - see OA-24.
Steps for the owner:
  1. If the repository stays private forever, reply "no licence" and I will write a
     LICENSE file stating "All rights reserved" with your name.
  2. If it may go public, MIT is the usual choice for permissive, GPL-3.0 if you
     want derivatives kept open. Reply with the name.
What I will do when it arrives: write LICENSE and commit it.
What I am doing meanwhile: leaving LICENSE absent rather than guessing.
```

```
BLOCKED - OA-15 Repository public or private at launch
What I need: a yes or no on private.
Why: Spec 32.3 row 23, 29.11. Interacts with never-break rule 5: a public
     repository makes any accidentally committed secret a permanent incident, and
     never-break rule 10 forbids publishing detector thresholds.
Steps for the owner:
  1. Reply "private" or "public".
Recommended default from 32.4: private until launch, then decide.
What I will do when it arrives: set it, and if public, re-audit the whole history
     for secrets and move all thresholds into docs/private/ first.
What I am doing meanwhile: proceeding on private. Recorded as decision D-0003.
```

```
BLOCKED - OA-16 Discord server, bot token and channel IDs
What I need: a Discord server, a bot invited to it, and the IDs of a public
     announcements channel and a PRIVATE staff-alerts channel.
Why: Spec 32.3 row 13. Acceptance row 57 (reports reach Discord with evidence),
     row 75 (staff alerts go ONLY to a private channel), row 18 (rules identical in
     three places), and the Section 9.5 season countdown campaign.
Steps for the owner:
  1. In Discord, create a server named LaughTail SMP.
  2. Create channels: #announcements (public) and #staff-alerts (private - deny
     "View Channel" for @everyone).
  3. Go to discord.com/developers/applications, "New Application", name it
     LaughTail. Bot tab, "Reset Token", copy the token.
  4. Installation or OAuth2 tab, generate an invite with the bot scope and the
     permissions Send Messages, Embed Links and Read Message History. Open the
     link and add the bot to your server.
  5. In Discord: User Settings, Advanced, turn on Developer Mode. Then right-click
     each channel, "Copy Channel ID".
  6. Put the token and both channel IDs into
     C:\Laugh-Tale\docs\private\discord.txt (git-ignored).
What I will do when it arrives: wire announcements, the countdown campaign and the
     staff alert queue, and prove row 75 - that alerts reach the private channel
     and only the private channel.
What I am doing meanwhile: building the alert queue behind an interface so the
     transport is swappable.
```

```
BLOCKED - OA-17 Support and appeals email address
What I need: one email address players can write to.
Why: Spec 32.3 row 12, Section 14.8 (one appeal route), 31.13 (data requests).
     Acceptance row 16 - the Privacy Policy must name a contact.
Steps for the owner:
  1. Create or nominate an address, for example support@<yourdomain>.
  2. Reply with it. It will be published, so use one you are happy to publish.
What I will do when it arrives: put it in the legal pages, the in-game /appeal
     output and the website footer.
What I am doing meanwhile: using a placeholder marker that fails the CI
     hardcoded-value check, so it cannot ship unnoticed.
```

```
BLOCKED - OA-18 The first players, and the soft-launch roster
What I need: the Minecraft usernames of the first players to be whitelisted.
Why: Spec 32.3 row 20, Section 20 Phase 9 ("a small group of paying players").
     Acceptance row 51 needs one full week of real play, and row 12 requires the
     whitelist to match paid transactions exactly with zero unexplained entries -
     so a hand-added friend is an audit failure unless it is recorded.
Steps for the owner:
  1. List the usernames, and mark which are paying and which are staff test
     accounts. Section 17 requires staff play accounts to be separate from staff
     accounts, and staff accounts earn zero RP (row 55).
  2. Put the list in C:\Laugh-Tale\docs\private\whitelist-seed.txt (git-ignored).
  3. Decide whether staff pay for access. Law 3 says everyone is equal with no
     exceptions, "not for staff" - so my reading is that they should.
What I will do when it arrives: seed the whitelist and reconcile it against the
     transaction log for row 12.
What I am doing meanwhile: building the whitelist audit script.
```

---

## Tier 4 - needed by Phase 8, not before

```
BLOCKED - OA-19 Domain and DNS access
What I need: a domain, and the ability to edit its DNS records.
Why: Spec 32.3 row 8. Acceptance row 71 (the site is not served from the game
     host, proven by DNS and IP), and the store, map and status subdomains.
Steps for the owner:
  1. Register a domain at any registrar, or nominate one you own.
  2. Confirm you can reach its DNS record editor.
  3. Reply with the domain name.
What I will do when it arrives: plan the subdomains and, at migration time, lower
     the TTL to 60 seconds ahead of a cutover as 22.11 requires.
What I am doing meanwhile: nothing depends on this until Phase 8.
```

```
BLOCKED - OA-20 Website hosting, separate from the game VPS
What I need: hosting for a static or small dynamic site that is NOT this EC2 box.
Why: Spec 18.1 calls this non-negotiable and 32.3 row 9 repeats it. Acceptance
     row 71 proves it by DNS and IP check. Section 5 keeps the game box doing one
     job; on 2 vCPU a web request storm would otherwise become game lag.
Steps for the owner:
  1. Any of Cloudflare Pages, Netlify, Vercel or GitHub Pages. Free tiers are fine.
  2. Connect it to the laughtail-smp repository from OA-02, or a separate site repo.
  3. Reply with the hosting choice.
What I will do when it arrives: build the site, the leaderboards through a
     read-only database user (row 72), and 60-second caching (row 73).
What I am doing meanwhile: nothing depends on this until Phase 8.
```

```
BLOCKED - OA-21 Status page provider
What I need: a status page players can check when something is wrong.
Why: Spec 18.2 lists it; Phase 8 delivers it. It reduces support load, which on a
     one-person operation matters more than it sounds.
Steps for the owner:
  1. Most uptime monitors from OA-09 include a public status page. Enable it there.
  2. Reply with the URL.
What I will do when it arrives: link it from the website and the Discord.
What I am doing meanwhile: nothing depends on this until Phase 8.
```

```
BLOCKED - OA-22 Resource pack hosting, if a pack ships
What I need: a URL that can serve the resource pack zip over HTTPS, if we use one.
Why: Spec 32.3 row 18, Section 11. Law 7: a pack animating a texture costs the
     server nothing, which is the whole reason animated cosmetics survived the
     performance review. Acceptance row 61 requires the server to be fully playable
     with the pack DECLINED, so this is an enhancement, not a dependency.
Steps for the owner:
  1. Any static host or CDN with a direct HTTPS link. The OA-20 host will do.
  2. Reply with the base URL, or "no pack for launch".
What I will do when it arrives: publish the pack and set it as optional, never
     forced (Section 23).
What I am doing meanwhile: designing cosmetics so pack-declined players get a
     working, if plainer, experience.
```

---

## Tier 5 - security and verification

```
BLOCKED - OA-23 Two-factor authentication on every account
What I need: 2FA enabled on GitHub, the Pelican Panel, the registrar, the AWS
     account, the store account, and the email address behind all of them.
Why: Spec 32.3 row 7, 31.9, 33.6 item 4. Acceptance 31-13. This is the single
     cheapest risk reduction in the whole project: every one of these accounts can
     end the project if taken over, and the email account can reset most of the
     others. Note the specification names the fifth account inconsistently - 31.9
     says the store account, 33.6 says the host account - so I am asking for both.
Steps for the owner:
  1. AWS: your account name top right, Security credentials, "Assign MFA device".
     Use an authenticator app. Also do this for the root user if you use one.
  2. GitHub: Settings, Password and authentication, "Enable two-factor".
  3. Pelican Panel: your account, Account Settings, enable two-factor.
  4. Registrar and store: find the security or 2FA section in account settings.
  5. Email: enable 2FA and save the recovery codes somewhere offline.
  6. Save every recovery code. Reply "2FA done" listing which accounts.
What I will do when it arrives: record it against acceptance 31-13. Note that 31-13
     asks for evidence in docs/private/, which is git-ignored - so the evidence
     cannot be in git history. Recorded as questions.md Q-07.
What I am doing meanwhile: everything else. This blocks no build task, but it is
     the item I would least like to skip.
```

```
BLOCKED - OA-24 Read-only AWS access so I can verify the host myself
What I need: either the AWS CLI installed on this PC with a read-only profile, or a
     read-only IAM access key.
Why: Three things I currently cannot verify and had to ask you to do by hand:
     the security group rules (OA-06), whether the pre-build snapshot completed
     (OA-03, acceptance 33-1), and the CPU credit balance that OA-05 turns on.
     Acceptance 22-10 and row 5 both need host-level facts. Right now I can see
     inside the instance over SSH but nothing about the AWS resources around it.
Steps for the owner:
  1. Reply "install aws cli" and I will run:
       winget install --id Amazon.AWSCLI -e --source winget
  2. AWS Console, IAM, Users, "Create user", name laughtail-readonly,
     no console access.
  3. Attach the AWS managed policy ReadOnlyAccess. Nothing else.
  4. Create an access key for it, choose "Command Line Interface".
  5. Paste the access key id and secret into
     C:\Laugh-Tale\docs\private\aws-readonly.txt (git-ignored).
What I will do when it arrives: verify the security group, the snapshot state, the
     volume size and the CPU credit balance directly, and stop asking you to read
     values out of the console.
What I am doing meanwhile: asking you for those values by hand, as above.
```

---

## Owner-only decisions I am proceeding on by default

Spec 32.4 says nothing should ever wait on a decision that has a recommended
default. These are the eight, plus the Section 24 questions. I am taking the
default, recording it in `docs/decisions.md`, and flagging it here for your
confirmation. **Say nothing and these stand.** Say the word and I change them.

| Decision | Default I am taking | Source |
| --- | --- | --- |
| Access price | Build for both models via a nullable expiry column; no price hardcoded | 24.1, OA-12 |
| Shop tier at season reset | `drop_one`, behind one config key so all three are one line apart | 24.2 |
| Voice route presented as primary | Browser-based for universality, client mod as the quality upgrade | 24.3 |
| Lifesteal hearts | Built, switched **OFF** at launch | 24.4 |
| Clans and guilds | Not at launch. Roadmap Tier 1 | 24.5 |
| Bedrock support | Enabled, explicitly labelled best-effort, limits published | 24.6 |
| Languages | Every user-facing string in a language file from day one, English only populated | 24.7 |
| Season end hour | 00:00 IST on the 1st | 31.1, 32.4 |
| Combat-log flat penalty | 25 RP on top of the normal loss | 31.3, 32.4 |
| Daily per-item sell cap | 3x the modelled manual rate | 31.5, 32.4 |
| New-player grace length | 30 minutes of playtime | 31.6, 32.4 |
| Daily restart hour | 05:00 IST | 31.8, 32.4 |
| Repository visibility | Private until launch | 29.11, 32.4, OA-15 |

One caveat on the combat-log penalty: 32.4 recommends 25 RP, but 31.3 requires the
penalty be *published* and *strictly worse than dying*, and never states the normal
death loss - so I cannot yet prove 25 RP satisfies its own rule. Recorded as
`docs/questions.md` **Q-14**.


---

## Discovered 2026-08-26 after the plan was written

```
BLOCKED - OA-25 laughtail-dev cannot be created without Panel access
What I need: either two minutes of you clicking in the Pelican Panel, or an
     Application API key. Root SSH is genuinely not sufficient, and the
     specification is wrong to say it is.
Why: Section 20 Phase 0 and pre-flight 33.6 items 9 and 10 require laughtail-dev
     to exist, with its own allocation and a heap 25 per cent below it. Nothing in
     Phase 0 onward can be built or tested without it.
     Evidence that SSH is not enough, gathered this session:
       php artisan list on the Panel shows the full p: namespace. It contains
       p:node:make and p:user:make but there is NO p:server:make. Pelican has no
       CLI path to create a server. Only p:server:bulk-power exists.
       The node also has exactly ONE allocation and it is already bound to the
       stock server, so a second allocation is needed before a second server can
       exist. Allocations are created in the Panel UI or the Application API.
       Panel facts: Pelican on Laravel 13.25.0, SQLite at
       /var/www/pelican/database/database.sqlite, APP_URL https://panel.devpilotx.com,
       nodes=1 servers=1 allocations=1 eggs=1 users=1.
     I will NOT create the server by editing database.sqlite directly. That is
     exactly the class of change that breaks a Panel silently, and never-break
     rule 6 plus the ownership trap in 33.1 both point the same way.
Steps for the owner - OPTION A, you click (about two minutes):
  1. Open https://panel.devpilotx.com and sign in.
  2. Admin area, Nodes, open the existing node, Allocations tab.
     Add an allocation: IP = the node's IP as already listed, Ports = 25566.
     Add a second: Ports = 24455.   (dev uses 25566 and 24455 so it can never
     collide with production on 25565 and 24454.)
  3. Admin area, Servers, Create New.
       Name: laughtail-dev
       Owner: your account
       Node: the existing node
       Allocation: the 25566 one you just made
       Memory: 1536 MB      Swap: 0       Disk: 6144 MB
       CPU: 100  (one of the two cores; leaves the other for Wings and the Panel)
       Egg: the Paper egg
       Minecraft version / build: leave default, I will replace the jar with the
         pinned Paper 1.21.11 build 132 from server/manifest.yml
       Docker image: the java_21 image if offered, not java_25 - PaperMC states a
         Java 21 minimum for this build and 21 is the most-tested runtime for it
  4. Do NOT start it. Reply "dev server created".
Steps for the owner - OPTION B, I do it and it stays repeatable (recommended):
  1. https://panel.devpilotx.com, sign in, click your name, API Credentials -
     or Admin area, Application API depending on the Panel build.
  2. Create an Application API key with read and write on Servers, Nodes and
     Allocations. Nothing else.
  3. Paste it into C:\Laugh-Tale\docs\private\pelican-app-key.txt (git-ignored).
  4. This deviates from spec 33.1, which struck API keys out as NOT REQUIRED.
     That instruction rested on the claim that root SSH covers everything the
     API would do. It does not - see the evidence above. Recorded as
     docs/questions.md Q-40 and decisions.md D-0012.
Why Option B is better: every server this project ever creates - laughtail-dev
     now, laughtail at launch, a scratch server for the restore drill, a replacement
     after the migration in Section 22 - becomes a scripted, repeatable, reviewable
     action instead of a sequence of clicks nobody can audit. That is the whole
     point of Section 29.
What I will do when it arrives: create laughtail-dev with the allocation and heap
     that satisfy pre-flight 9 and 10, install the pinned Paper 1.21.11 build 132,
     and run the aarch64 load-proof on all nine manifest components (deviation D5).
What I am doing meanwhile: repo-side Phase 0.2 work that needs no server -
     deploy.sh, drift.sh, and the database schema in db/migrations/.
```


```
BLOCKED - OA-26 Decide whether to rotate the RCON password and management secret
What I need: a yes or no on rotating two credentials, plus the same answer for the
     Pelican SFTP and Panel passwords if you reused anything.
Why: an earlier version of one of my read-only scripts ended with
     `cat server.properties`, which printed the live RCON password (32 characters)
     and the 1.21.9 management-server secret (40 characters) into a session
     transcript. That is exactly what never-break rule 5 exists to prevent. I have
     removed the dump, written the reason into the script as a comment so it does
     not come back, and recorded it as decisions.md D-0019.
How bad it is, honestly: low, but not zero. Neither credential is reachable from
     the internet - proven, not assumed. The external probe from my PC shows port
     25575 closed, Docker publishes only 25565, and the management server is
     disabled, bound to localhost, on port 0. So exploiting either one requires
     already having a shell on the host, at which point they are the least of the
     problems. Neither value has ever been committed to git.
Steps for the owner:
  1. Decide: rotate now, or rotate at launch with everything else.
  2. If rotating now, reply "rotate rcon" and I will generate a new value on the
     host, write it straight into the live file, and never read it back. It is one
     command and one restart of the dev server. Nothing depends on the old value.
  3. The management secret needs no rotation while the management server is
     disabled, but I will do both together if you prefer.
  4. Do NOT reuse these values anywhere else in the meantime.
What I will do when it arrives: rotate host-side with the value never leaving the
     host, then re-run the drift check to confirm both keys are still non-empty.
What I am doing meanwhile: treating both as live and never reading them again. The
     Section 22.7 migration step rotates every secret anyway, so this is a question
     of timing rather than of whether.
```


```
BLOCKED - OA-27 Choose between older-client support and a reliable anti-cheat
What I need: a decision on whether LaughTail supports older Minecraft clients, or
     requires 1.21.11 and up.
Why: GrimAC prints this on every boot, unprompted -
       "GrimAC has detected that you have installed ViaBackwards on a 1.21.2+
        server. This setup is currently unsupported and you will experience issues
        with older clients using vehicles."
     Both plugins are installed because the specification asks for both: 4.3 wants
     older-client support (ViaBackwards), 14.1 wants a simulation anti-cheat
     (GrimAC). They do not cooperate - GrimAC predicts movement, ViaBackwards
     rewrites the packets it predicts from.
Why it matters more than a compatibility note: acceptance row 50 needs the
     anti-cheat to catch a test flight and a test reach cheat. If predictions are
     unreliable for some clients, either those players get punished for lag - on a
     server that sells fairness, to people who paid - or the checks are relaxed for
     them and that becomes the preferred client for cheating, which is worse than
     no anti-cheat because it is invisible.
Steps for the owner - pick one:
  1. "Require 1.21.11+" - I remove ViaBackwards and ViaVersion from the manifest.
     The store page must then state the version requirement BEFORE purchase, or a
     buyer on an old client is a guaranteed refund. This is my recommendation: it
     keeps the fairness promise absolute, and Minecraft's launcher auto-updates so
     the affected group is small.
  2. "Keep old clients" - I research a different anti-cheat. Expect it to be weaker
     or paid; 14.1 says do not buy anti-cheat you have not proven you need.
  3. "Keep both and accept it" - I will do this if you instruct it, but I will
     record that the vendor calls it unsupported and that row 50 cannot then be
     honestly claimed.
What I will do when it arrives: update server/manifest.yml, re-run the aarch64
     load proof, and note the version requirement for the store page (OA-10).
What I am doing meanwhile: nothing removed. Both plugins remain installed and
     loading. Recorded as questions.md Q-42.
```

```
BLOCKED - OA-28 Approve or amend the proposed numbers in docs/proposals.md
What I need: a yes, a no, or a different figure for each proposal. Nothing in that
     file is implemented and nothing will be until you say so.
Why: three of the four things blocking whole phases are missing NUMBERS rather than
     missing work - questions.md Q-10 (the economy has no figures anywhere in the
     specification), Q-11 to Q-13 (Appendix B and Section 9 contradict each other on
     the ranking maths), and OA-12 (the access price). I can build the machinery
     around all of them, and have, but the machinery is inert without values.
     Rather than ask you to invent thirteen numbers, docs/proposals.md contains a
     concrete figure for each, how it was derived, and WHAT BREAKS IF IT IS WRONG in
     each direction - so you are approving or amending rather than starting blank.
Steps for the owner:
  1. Read docs/proposals.md. It is thirteen items and each is a few lines.
  2. Reply "approve P1" / "P1 should be 149" / "reject P1" per item.
  3. If thirteen is too many at once, approve ONLY P1 (the access price) and P2
     (target berries per hour). Those two unblock more than the other eleven
     combined, and P3 to P10 are all expressed relative to P2 so they are not
     meaningful until it is fixed.
What I will do when it arrives: build Phase 1's paywall against P1, and the economy
     skeleton against P2. Record each approved value in decisions.md with your
     approval as its authority, so nobody later mistakes a proposal for a decision.
What I am doing meanwhile: the parts of Phase 4 that do not need the ranking maths -
     the season lifecycle, the reset job and its idempotency, the archive, and the
     Champion mechanism. All of it is testable without a single rating point.
```

## OA-31 - roleplay needs one paragraph from the owner before anything can be built

**What is blocked.** The roleplay system. Asked for twice, recorded as D-0033, still undesigned.

**Why I have not guessed.** "Roleplay" describes at least five different products and they contradict
each other: custom professions and skills; in-character chat with radius and radio; player-run towns
with law and taxes; quest and story content with NPCs; or hard-RP where breaking character is
punishable.

Two of those five directly contradict this server's founding rules. **Professions that grant advantage
break Law 1's total equality.** **Player-run towns with taxes create a second economy** alongside the
Berry ledger that the arbitrage audit depends on - and a second economy is the same class of mistake as
the shard shop that was refused in D-0035.

Building the wrong one is worse than building nothing, because roleplay touches identity, chat,
progression and land - the four things hardest to change afterwards.

**What I need.** One paragraph describing what a player DOES during an evening of roleplay on this
server. Not a feature list - a description of an evening. That answer decides the schema, and the
schema decides everything after it.

**What I will do meanwhile.** Continue with the auction house, claims, chat protection and the tested
gaps. None of them depend on this answer.

## OA-32 - anti-cheat is the launch blocker and needs a decision, not more engineering

**Status.** Row 50 requires flight and reach cheats to be caught and logged. GrimAC was installed and
tested twice on Minecraft 26.2 and failed both times with `NMS_ITEM_STACK_CLASS is null`. The version
is too new for any anti-cheat to support yet.

**The three options, with their real costs.**

1. **Wait for support.** Launch is delayed by however long that takes, which nobody can predict.
2. **Launch without it.** Cheaters on a server whose entire value is a fair PvP ladder. This is the
   worst option for this specific product, and I would argue against it.
3. **Return to Minecraft 1.21.x**, where anti-cheat works. This is what made the owner's own movement
   unplayable and caused the move to 26.2 in the first place (D-0028). It would need the setback
   problem re-diagnosed rather than assumed solved.

**I cannot decide this** - every option trades away something the owner cares about.
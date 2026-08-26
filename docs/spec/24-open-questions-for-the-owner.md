## SECTION 24 - OPEN QUESTIONS FOR THE OWNER

These are the only decisions genuinely left open. Batch them; do not stop work waiting for answers. Each has a working default so building can continue.

### 24.1 The price, and whether it recurs

The single most consequential unanswered question, because it determines the entire economics of the project.

* **A one-time fee** is simpler, feels fairer, avoids subscription churn and dunning, and has far lower support overhead. But revenue is front-loaded and does not cover ongoing hosting.
* **A recurring fee** funds hosting sustainably and naturally removes inactive players. But it requires subscription management, failed-payment handling, and access-expiry logic, and it creates a monthly reason for players to reconsider.

**Recommendation: a one-time access fee for launch.** It is far less to build, far less to support, and you can add a subscription later. Going the other way - taking subscriptions and then trying to convert to one-time - is much harder. Whichever is chosen, remember 3.3: the fee must be a direct fee for server access, not access gated on some out-of-game product or platform.

**Default while waiting:** build the whitelist and store pipeline to support both. Key access on a boolean plus an optional expiry timestamp. If the expiry is null, access is permanent. That one nullable column keeps both options open at zero cost.

### 24.2 Shop tier behaviour at the monthly reset

keep_peak, drop_one, or full_reset (10.4). **Default: drop_one.** All three are implemented behind one config key, so this is a one-line change after the owner sees real player reaction.

### 24.3 Which voice chat route

All three are built (13.2), but which is presented as **the** recommended route on the website matters:

* **Proximity voice with a client mod** gives the best experience but requires an install and needs a bridge for Bedrock.
* **Browser-based voice** works for absolutely everyone with no install but has lower fidelity and depends on an external service.

**Recommendation: lead with browser-based voice for universality, and offer the mod as the upgrade path for Java players who want the best quality.** That ordering means no paying player is ever excluded, which satisfies Law 3, while enthusiasts still get the premium experience.

### 24.4 Lifesteal hearts

A popular mechanic - win a fight, take a heart of maximum health from the loser. It is genuinely compelling and fits a combat-first server, but it is also brutal for newer players and can create an unrecoverable spiral.

**Built, and switched OFF.** Enable it for one season as an experiment once the playerbase is established, if the owner wants it. Do not launch with it - it changes the difficulty of the entire server and you will not be able to tell whether it or something else caused a retention problem.

### 24.5 Team, clan and guild structures

A clan system with shared claims, a clan tag and clan leaderboards is one of the strongest retention mechanics available, because it converts individual play into social obligation - which is what actually brings players back.

**Recommendation: not at launch, but early.** It is in Tier 1 of the roadmap (26.2). Launching with it would violate Law 2, but it should not wait long.

### 24.6 Bedrock support at launch, or after

Bedrock support roughly doubles the addressable playerbase and is genuinely valuable. It also brings real complexity: separate cosmetic packs, chat-signing differences, the voice bridge, and its own class of bugs.

**Recommendation: launch with it enabled but explicitly marked as best-effort**, with the known limitations published (11.2, 13.4). Do not hide it, and do not promise parity you cannot deliver.

### 24.7 Additional languages

Given the likely playerbase, a Hindi option for the rules, the store, the settings menu and key messages could measurably widen reach.

**Recommendation: build every user-facing string into a language file from day one**, even if only English is populated. Retrofitting internationalisation into a codebase that hardcoded its strings is genuinely painful work, and doing it right at the start costs almost nothing.

---


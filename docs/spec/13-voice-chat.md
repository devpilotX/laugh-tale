## SECTION 13 - VOICE CHAT

New requirement from the owner: voice chat in game. This section exists because the naive answer ("install the voice plugin") quietly excludes a large fraction of the playerbase, and because the voice port is the single most commonly broken thing in a server migration.

### 13.1 The core problem

Minecraft has no native voice chat. Every solution is an add-on, and they split into two families with a real trade-off:

| Approach | Who can use it | Audio quality | Cost to players | Cost to us |
|---|---|---|---|---|
| **Mod-based proximity voice** (the Simple Voice Chat family) | Java players **who install a client mod**. Bedrock players cannot. | Best. Proper spatial audio, noise suppression, Opus codec | A one-time mod install | A server plugin plus one open UDP port |
| **Browser-based proximity voice** (the OpenAudioMc family) | **Everyone**, Java and Bedrock, with no install at all | Good, not as good | Keep a browser tab open | A server plugin plus a dependency on an external web service |
| **Discord voice** | Everyone with Discord | Excellent, but not positional | Nothing | Nothing at all |

### 13.2 The decision

**Build all three, in this order, and let players choose.** This is the only answer that respects Law 3, because a voice system available to only some paying players is an unequal feature.

1. **Discord voice channels first.** Zero cost, zero risk, works today, works for everybody, and you should have a Discord anyway. Ship this on day one by simply creating the channels.
2. **Mod-based proximity voice as the flagship experience.** This is what players actually want in a survival server - hearing footsteps and voices getting louder as someone approaches is a genuinely transformative feature for both immersion and PvP tension.
3. **A browser-based bridge so Bedrock and unmodded players are not excluded.** There are Geyser bridge extensions that put Bedrock players into the same proximity voice through a web interface with no client mod. Treat these as promising but young: several are explicitly in development, and at least one warns that its audio is **not fully encrypted** and must be run behind an HTTPS proxy. Evaluate carefully, run it behind TLS, and if it is not stable enough, fall back to option 1 for Bedrock players and say so honestly on the website rather than shipping something broken.

### 13.3 Implementation requirements

| Requirement | Detail |
|---|---|
| **UDP port** | The mod-based voice server needs its **own UDP port**, separate from the game port. The conventional default is 24454. It must be open in the host firewall, in the cloud security group, and in the container port mapping. |
| **UDP cannot be tested with a normal port checker** | UDP is connectionless, so standard TCP port-check tools will report nothing useful. Use the voice plugin's built-in test command, or a UDP-aware tool. Add this to the migration checklist explicitly. |
| **DDoS protection must forward UDP** | Many cheap or free protection layers proxy TCP only. If you enable protection without UDP support, voice chat silently dies. Verify UDP support before choosing a provider. |
| **Bandwidth is a real cost** | Voice is roughly 20 to 32 kbps per active speaker, relayed to every nearby listener - so cost scales with speakers multiplied by listeners. On a provider that charges for egress, this is a measurable line item. Measure it during the load test, and factor it into the migration decision in Section 22. |
| **Cross-mod compatibility** | If you support more than one voice mod, use a server-side bridge so players on different mods can still hear each other. Do not fragment the playerbase into two audio worlds. |
| **Permissions and moderation** | Voice must be moderatable: staff need mute, per-player and global. Voice-based harassment is subject to the same punishment ladder as chat, and the rules must say so. |
| **Opt-in, always** | Nobody is forced into voice. Push-to-talk should be the default over open-mic, both for player comfort and to reduce relayed traffic. |
| **Never a requirement** | No gameplay feature, event or reward may require voice chat. It is an enhancement, never a gate. |

### 13.4 Known limitations to publish honestly

* Java players need a client mod. This is a small hurdle but it is a real one.
* **Lunar Client users are covered** - Lunar supports importing community modpacks, and a well-maintained voice-chat pack for Lunar exists with a one-click install. Document the exact steps on the website, with screenshots, because this is the single most common support question you will get. Note that some HUD icons may not render correctly on Lunar; the functionality still works.
* Bedrock players depend on the bridge, which is newer and less proven than the core plugin.
* Voice traffic is encrypted in transit by the main plugin but the authors do not guarantee its security. Do not promise players that voice is private. Say it is encrypted, not that it is secure.

### 13.5 Acceptance criteria

* [ ] Voice works between two Java clients on the target host, over the public internet, not just on localhost.
* [ ] The UDP port is verified open with a UDP-aware method, and is documented in the port table and the migration checklist.
* [ ] A Bedrock player can either join voice through the bridge, or is clearly told on the website that Discord is their route.
* [ ] Staff can mute a player in voice, and the action is logged.
* [ ] Voice bandwidth is measured under load and recorded in the performance doc.
* [ ] Disabling voice entirely, via one config flag, leaves the server fully functional.

---


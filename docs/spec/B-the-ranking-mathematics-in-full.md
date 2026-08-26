## APPENDIX B - THE RANKING MATHEMATICS, IN FULL

    Constants
      K                = 24
      STARTING_CR      = 1000
      MIN_GAIN         = 2
      MAX_GAIN         = 40
      DECAY_RATE       = 0.01 per week
      DECAY_AFTER      = 7 days of inactivity
      RESET_FACTOR     = 0.35
      RESET_BASE       = 1000

    On a kill
      E     = 1 / (1 + 10 ^ ((CR_victim - CR_killer) / 400))
      raw   = K * (1 - E)
      gain  = clamp(raw, MIN_GAIN, MAX_GAIN)
      gain  = gain * repeat_multiplier(killer, victim)
      gain  = gain * zero_if_alt_or_reciprocal(killer, victim)
      gain  = gain * zero_if_spawn_region(location)

      CR_killer = CR_killer + gain
      CR_victim = max(tier_floor(CR_victim), CR_victim - gain)

    repeat_multiplier, per killer-victim pair, resetting after 6 hours
      1st kill  = 1.00
      2nd kill  = 0.50
      3rd kill  = 0.25
      4th kill  = 0.10
      5th onward = 0.00

    Weekly decay, only after DECAY_AFTER days of inactivity
      CR = max(tier_floor(CR), CR * (1 - DECAY_RATE))

    Monthly season reset
      CR_new = RESET_BASE + (CR_old - RESET_BASE) * RESET_FACTOR

    Rank points shown to the player
      RP = CR

**Invariants to assert in tests:**

* A kill can never reduce the killer's CR.
* A death can never take a player below their tier floor.
* No non-combat action changes CR by any amount.
* Two applications of the reset are identical to one application followed by no-op.
* The sum of CR changes in a single kill event is zero before clamping and flooring.

---


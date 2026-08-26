-- V7 - narrow the dynamic price band from +/-40% to +/-20%.
--
-- WHY THIS MUST CHANGE WHEN THE SPREAD CHANGES. The owner asked for buy price to be double sell price -
-- a 50% spread instead of 12%. That is a much safer shop in the obvious sense: buying something and
-- selling it straight back now loses half its value instead of an eighth.
--
-- But it interacts with the band, and the interaction is the whole reason for this migration.
--
-- The dangerous case is two items linked by a recipe - raw iron and an iron ingot, nine ingots and a
-- block. An attacker buys the input at the CHEAPEST the band allows and sells the output at the
-- DEAREST, so what matters is:
--
--     sell at ceiling   vs   buy at floor
--
-- With the old numbers, a 12% spread and a +/-40% band:
--     sell ceiling = 0.88 x 1.40 = 1.232 x base
--     buy floor    =        0.60 = 0.600 x base      -> profit of 105%. Exploitable.
--
-- That is why V3-era pricing had to EXCLUDE the smelted form of every ore (D-0036): with both sides
-- priced, the band alone created a money printer regardless of the spread.
--
-- With a 50% spread and the band left at +/-40%:
--     sell ceiling = 0.50 x 1.40 = 0.700 x base
--     buy floor    =        0.60 = 0.600 x base      -> profit of 17%. Still exploitable.
--
-- With a 50% spread and a +/-20% band:
--     sell ceiling = 0.50 x 1.20 = 0.600 x base
--     buy floor    =        0.80 = 0.800 x base      -> LOSS of 25%. Safe at every point in the band.
--
-- So narrowing the band is what makes it possible to sell EVERYTHING the owner asked for - ingots and
-- blocks and raw ore all at once - because a 1:1 transformation can no longer be profitable no matter
-- where in the band the two prices happen to sit. The wide band was only ever affordable next to a thin
-- spread, and swapping which one is generous is what buys the bigger catalogue.
--
-- The visible cost is that prices move less. At +/-20% a heavily farmed item still loses a fifth of its
-- value, which is enough to discourage dumping without making a market that swings wildly.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- A CHECK constraint cannot be altered in place; it is dropped and recreated.
ALTER TABLE shop_prices DROP CONSTRAINT chk_price_band;

ALTER TABLE shop_prices ADD CONSTRAINT chk_price_band CHECK (
  current_price >= GREATEST(1, ROUND(base_price * 0.8))
  AND current_price <= ROUND(base_price * 1.2)
);

-- Any price already outside the new, narrower band is pulled back inside it. Without this the new
-- constraint would be violated by existing rows the moment anything tried to update one.
UPDATE shop_prices
   SET current_price = LEAST(ROUND(base_price * 1.2),
                             GREATEST(GREATEST(1, ROUND(base_price * 0.8)), current_price)),
       updated_at = UTC_TIMESTAMP(3)
 WHERE current_price < GREATEST(1, ROUND(base_price * 0.8))
    OR current_price > ROUND(base_price * 1.2);

-- Sell prices are recomputed from the new spread on the next read by Database.currentPrice, which
-- self-heals any row whose stored sell price disagrees with Shop.sellPrice. Nothing to do here.

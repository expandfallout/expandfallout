# Items, Stacking, and the Rarity System

## ⚠ THE BIGGEST PORT PROBLEM: Helix has no item stacking

**Verified:** `grep` for `SetQuantity|GetQuantity|isStackable|maxQuantity|OnCombine` across the entire
Helix gamemode returns **nothing**. In Helix, `inventory:Add(uniqueID, quantity)` just creates `quantity`
*separate item instances*. One grid slot = one item, always.

Their NutScript fork has a full stacking layer:
```lua
ITEM.isStackable, ITEM.maxQuantity, ITEM.canSplit
item:getQuantity() / item:setQuantity()
ITEM:onCombine(other)   -- drag item onto item to merge
netstream "itemSplit"   -- right-click → Split, with a quantity prompt
```
Merging also **refuses to combine items of different rarity** — rarity is per-instance.

**Why this matters:** this schema has ~40 crafting materials, ~28 ammo types, food, drink, drugs and junk.
Without stacking, a normal player's inventory is unusable within an hour.

**This must be built before any economy/crafting work.** It's a foundational Helix extension —
item metatable methods + inventory merge-on-add + a split UI + grid rendering of the quantity number.
Not enormous, but it gates everything downstream. Flagging it as the first real engineering task.

## Item bases (22 total)
| Base | Plugin | Purpose |
|---|---|---|
| `sh_junk` | schema | stackable materials, split/combine, rarity |
| `sh_clip` | schema | ammo |
| `sh_deployable` | schema | doors, vehicles, farm plots, cooking stations |
| `sh_blueprint` | schema | crafting recipes |
| `sh_syringeweapon` | schema | injector weapons |
| `sh_armorv2` | armorv2 | the 14-slot armor system |
| `sh_moddableweapons`, `sh_weaponmods`, `sh_oneuseweapons`, `sh_blueprint` | moddable_weapons | attachments |
| `sh_food` | thirsthunger | food/drink |
| `sh_aid` | drugs_simple | chems |
| `sh_beaker`, `sh_customchem` | drugs_advanced | SS13-style chemistry |
| `sh_plant` | plants | harvestables |
| `sh_farming` | farming | crops |
| `sh_fish` | fishing | fish (rarity-named) |
| `sh_implant` | implants | permanent buffs, lost on PK |
| `sh_bobblehead` | bobbleheads | SPECIAL bonus + free perk |
| `sh_idcard` | idreligioncards | equippable ID/religion cards |
| `sh_armormodulator` | modulators | armor attachments |
| `sh_item_crate` | itemcrates | bulk containers |

**1,389 item definition files total.** ~680 are armor.

## Crafting material set (~40, from `schema/items/junk/`)
`acid, adhesive, ballistic_fiber, ceramic, circuitry, cloth, copper, crudeoil, crystal, duct_tape, egg,
fiberglass, gears, glass, gold, leather, nuclear, oil, plastic, processedoil, rubber, scrapelectronics,
scrapmetal, screws, silver, springs, steel, wood, technical_documents, highqualframe`

**Ore/bar pairs** (mining → smithing): `iron, gold, silver, bronze, uranium, saturnite, coal`
→ `ore*` and `bar*` variants.

Plus **schematics** as items: armor mod insertion, black market vendor, blueprint vendor, frame vendor,
melee vendor, oil vendor, mines, oil derrick, oil refinery, fusion generator, purified water well,
sharecropper, stash, tribal chem bench.

**Collectibles:** 11 snowglobes (Goodsprings, Hoover Dam, Lonesome Road, Sierra Madre, The Strip, Zion,
Big MT, Mormon Fort, Mt Charleston, Nellis AFB, Test Site), platinum chip, GECK, FEV can, severed ears/fingers.

## Rarity system (`nutscript/gamemode/core/meta/sh_rarity.lua`) — port this nearly verbatim
Genuinely the best-designed thing in the codebase. 8 tiers:

| # | Name | Colour | Base chance | Dmg mult | Shown? | Renameable? |
|---|---|---|---|---|---|---|
| 1 | None | white | 60.6 | 1.0 | no | no |
| 2 | Common | white | 35 | 1.0 | yes | no |
| 3 | Uncommon | green | 20 | 1.1 | yes | no |
| 4 | Rare | blue | 5 | 1.2 | yes | no |
| 5 | Superior | purple | 0.5 | 1.3 | yes | no |
| 6 | Legendary | orange | 0.03 | 1.4 | yes | **yes** |
| 7 | Pearlescent | animated rainbow | 0.001 | 1.5 | no | **yes** |
| 8 | Unique | cyan | 0 (never rolled) | 1.0 | no | **yes** |

Pearlescent uses `pearlescentShifter()` — lerps through 6 colours on `CurTime()`. Nice touch.

### Luck-weighted rolling — the clever part
`nut.rarity:buildLuckWeights(luck)`:
1. `effectiveBonus = Clamp(1 - 1/(1 + luck * 0.05), 0, 0.99)` — diminishing returns, can never hit 1
2. **Drain** weight out of Common+Uncommon: `drain = chance * effectiveBonus * 0.4`
3. **Redistribute** it into Rare/Superior/Legendary weighted by `1 / (idx^1.5)` — lower tiers get more
4. Add flat `chanceCoeffs` per tier
5. Past `luckSoftCap = 25`, add `over * postCapCoeffs[tier]` so high tiers keep climbing instead of flattening

So Luck doesn't just add a flat bonus — it *moves probability mass upward* from the junk tiers.

### Damage scaling is curve-softened (also smart)
```lua
dmgScale = Clamp(1 / (1 + dmg * 0.01), 0.3, 1)
finalDmg = 1 + (dmgMult - 1) * dmgScale
```
A rarity multiplier is worth **more on low-damage weapons than high-damage ones** — stops a Legendary
sniper from being absurd. Per-item override via `ITEM.rarityMult`.

### Built-in tuning tools
`rarityTest <rolls> <luck>` and `rarityChances <luck>` concommands (admin-only) print the actual
distribution. Worth reimplementing — makes balancing painless.

**Note:** `rollRarity` calls `math.randomseed()` on every roll. That's unnecessary in modern GMod and
slightly harmful (reseeding from a low-entropy source can cluster results). Drop it in our port.

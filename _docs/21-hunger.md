# 21 - Hunger and thirst

Two independent 0-100 meters on the character, draining faster the harder you
move, each with five tiers that hand out SPECIAL modifiers. Ported from
Phoenix's `thirsthunger` plugin.

Library `schema/libs/sh_hunger.lua`, server half `sv_hunger.lua`, drunk screen
effect `cl_hunger.lua`, item contract `schema/items/base/sh_food.lua`.

---

## The tiers go both ways

This is the part that separates it from radiation. Rads only ever hurt you;
these do not. Below 40 you are penalised, **above 60 you are rewarded**.

| Value | Hunger | SPECIAL | | Thirst | SPECIAL |
|---|---|---|---|---|---|
| 0 | Starving | STR −1, INT −1 | | Dying of Thirst | END −1, AGL −1 |
| 20 | Hungry | STR −1 | | Dehydrated | AGL −1 |
| 40 | Peckish | — | | Parched | — |
| 60 | Fed | STR +1 | | Hydrated | END +1 |
| 80 | Well Fed | STR +1, INT +1, **+1 HP/tick** | | Well Hydrated | END +1, AGL +1 |

So keeping fed is a reason to eat well, not just a timer to avoid. There is no
100 tier — 80 is the top band, so "Well Fed" is a state you hold rather than a
moment after eating.

Both meters contribute, and they are **summed then floored once**. Flooring
each source separately would let a penalty be swallowed: −1 from starvation
against +1 from hydration should cancel, but clamping the first to zero before
adding the second turns a wash into a bonus.

Applied in `ix.special.Get` — the single point every consumer already passes
through — exactly as radiation is.

---

## Draining

One timer for everyone, not a think per player. Rates are Phoenix's:

| State | Per tick |
|---|---|
| Still | 0.01 |
| Moving | 0.02 |
| Running | 0.03 |

At the default one-second tick that is roughly two and a half hours idle, or
fifty minutes at a run, from full to empty. All seven values are configs under
**Hunger and Thirst**.

`IsSprinting` decides "running" rather than a speed comparison, because armour
and a dead fusion core both change what fast means — a player pinned to walk
speed in an unpowered suit is still working hard.

**Tier changes drive everything, not values.** The meters move every tick, so
reacting to the number would recompute speed and fire a notification once a
second forever. Speed is re-applied and the player told only when the tier
actually changes.

Test bots are skipped. A target that slowly starves is a target that changes
what it measures.

---

## Stamina

From `reference/03_armor_and_survival.md`, applied in `AdjustStaminaOffset`:

- thirst > 50 → `+0.5`
- thirst ≤ 10 → halved
- hunger < 10 → halved

**Regeneration only.** A negative offset is drain, and being hungry should not
make running *cheaper*, which is exactly what halving a negative would do.

---

## Food items

**201 items.** 56 converted from Phoenix, 145 new.

The item contract is theirs: `sustenance`, `hydration`, `radiation`,
`isAlcohol`, `useSound` (a *function*, so an item can randomise between chew
samples) and `eatMeText`. Eat and Drink are the same action with different
labels — the split is by stat, so a stew says Eat and a bottle says Drink
without either declaring which. `Feed` is a five-second stared action that
feeds someone else, re-checked on completion because five seconds is long
enough for the item to have been dropped or eaten.

Their base item's own description read *"An armor base, used to create armor
items"* — copied from the armour base and never corrected. Fixed here.

### The 145 new ones

Phoenix's set is almost entirely drinks, snacks and packaged meals: no meat, no
produce, no eggs, no cooking. Every new item is built on a model that was
**already installed and unused**, so nothing new has to be downloaded and
nothing renders as an ERROR prop.

Stats follow a per-category rule rather than being picked per item, so the set
stays internally consistent and is tunable in one place:

| Category | Sustenance | Hydration | Radiation |
|---|---|---|---|
| Raw meat | 18 | — | 6 |
| Cooked | 38 | — | 1 |
| Eggs | 12 | — | 3 |
| Omelettes | 34 | — | — |
| Produce | 10 | 4 | 1 |
| Meals | 48 | 6 | — |
| Snacks | 14 | — | — |
| Water | — | 40 | — |
| Dirty water | — | 35 | 9 |
| Soda | 5 | 25 | 1 |
| Alcohol | 2 | 12 | — |

That gives cooking a point: raw meat is food with real radiation attached, and
cooking roughly doubles the sustenance while removing the rads.

Covers meats (deathclaw, mirelurk, radscorpion, gecko, yao guai, ant, bloatfly,
stingwing, nightstalker and more), steaks and roasts, nine kinds of egg and four
omelettes, twenty-nine crops and produce, twenty-three prepared meals and soups,
thirteen snacks, water and sodas, and eight more alcohols.

### Alcohol

Ported whole: a one-in-fifty chance per second, for sixty seconds, of stumbling
over and blurting out one of fifty lines. On screen it is motion blur, a sharpen
pass and a tilt-shift for ninety seconds.

Their death check is kept and is cleverer than it looks — rather than hooking
death, it records `Deaths()` when the effect starts and clears it the moment
that number changes, which survives a disconnect, a character switch and a
respawn without listening for any of them.

---

## Notes

- **`models/models/fallout/apple1.mdl`** in the Golden Apple is **not** a typo.
  The content pack really ships the doubled path; `models/fallout/apple1.mdl`
  does not exist, so "correcting" it breaks the item.
- Three source models were absent and are substituted: Nuka-Cola Quantum,
  Deathclaw Egg and Human Flesh now point at models that exist.
- `phoenix_sound_content` was junctioned for the eating and drinking sounds -
  all 56 converted items referenced them and were silent without it.
- The **Golden Apple** sets you to level 50. Levelling is not built, so the
  effect is written out in full behind an `ix.leveling` guard and tells the
  player plainly that nothing happened, rather than being a silent no-op.
- `ix.hunger.HasHunger` reads `race.hasHunger`, defaulting to true. Phoenix gate
  the whole system and the HUD rows on the same flag; the HUD rows disappear
  rather than sitting at a permanent 100.

`CharSetHunger` and `CharSetThirst` are admin commands for reaching any tier
directly.

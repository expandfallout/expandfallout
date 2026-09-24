# 17 — S.P.E.C.I.A.L.

Seven attributes in `schema/attributes/`, wired up by `schema/libs/sh_special.lua`,
displayed by `schema/derma/cl_special.lua`.

## Helix already had most of this

The `attributes` character var (`sh_character.lua:596`) builds the whole
allocation UI at character creation, enforces a budget and stores the result.
Two things drive it:

| | |
|---|---|
| `GetDefaultAttributePoints(client, payload)` | the starting budget |
| `ix.config.Get("maxAttributes")` | the per-attribute ceiling |

So this system supplies numbers and effects, not machinery. Phoenix's values:
**15 starting points, 25 ceiling.**

`ATTRIBUTE.maxValue` is deliberately **not** set in the attribute files — it is
read once at load, which would freeze the value and ignore later config changes.
`maxAttributes` is defaulted to 25 instead.

## Exact spend

Helix's own validator only rejects **over**spending, so a character can be
created with points left on the table and no way to recover them. A
`CanPlayerCreateCharacter` listener requires the budget to be spent exactly, as
Phoenix does.

## The duplicate-attribute problem

Helix ships `stamina` and `strength` plugins that register their own attributes
and do real work with them:

| Key | Effect | How it reads the value |
|---|---|---|
| `end` | stamina drain | `GetAttribute("end")` inside its own hook |
| `str` | melee damage | `GetAttribute("str")` inside its own hook |
| `stm` | run speed | its own `ATTRIBUTE:OnSetup` |

Left alone those show duplicate "Strength"/"Endurance" bars at creation. Rather
than editing the plugins, they are **hidden from the UI** (`PruneAttributeList`)
and SPECIAL is **mirrored into the keys they read**, so the plugins keep working
untouched and SPECIAL stays the single source of truth.

**`stm` is the exception, and it is a trap.** Its effect lives in `OnSetup`,
which only runs for attributes still in `ix.attributes.list` — so pruning it
means the effect silently never happens. Agility's speed bonus is therefore
applied directly in `ix.special.Apply`, not through the plugin. The other two
are safe because their plugins read `GetAttribute` inside their own hooks.

## Reading a value

Always `ix.special.Get(character, key)`, never `character:GetAttribute` directly
— it lowercases the key. Phoenix stores attributes lowercase but reads them
capitalised in several places, which silently returns the default, and is why
some of their attributes appear to do nothing.

`ix.special.order` is the canonical S-P-E-C-I-A-L ordering; `ix.attributes.list`
is a hash and iterates arbitrarily.

## Effects

Semantics are the server owner's spec, not guesses:

| Attribute | Effect | Status |
|---|---|---|
| Strength | melee damage | done |
| Perception | **ballistic** weapon damage | done |
| Endurance | how much stamina you have, and **how many times you can jump** | done |
| Charisma | lowers how many caps you can be mugged for | done |
| Intelligence | **energy** weapon damage (laser/plasma/gauss/tesla) | done |
| Agility | **walk and run** speed | done |
| Luck | more items in lootables (**not better** items), XP gain, crafting luck | loot done; XP/crafting are getters |

**Every rate above is editable live**, in `/liveedit` under SPECIAL — see
[44-live-editor.md](44-live-editor.md). The configs are the source of truth; the
editor is a screen onto them.

### Damage: Phoenix's numbers

From their `damageview` plugin, which computes the same bonus it displays:

```lua
if energyAmmo[primary.Ammo] then  modifier = 0.010 * intelligence
elseif isMelee then               modifier = 0.010 * strength
else                              modifier = 0.010 * perception
bonus = damage * modifier
```

**+1% per point**, so +25% at the ceiling. Their server-side application is not
in the scrape (glua-steal never captures `sv_*`), but the readout is
authoritative for the numbers.

Melee is detected exactly as they do it: `weapon.Base == "dangumeleebase"`.

### Energy weapons are classified by AMMO, not by SWEP.Type

```lua
MicrofusionCell   EnergyCell   ElectronChargePack
```

Phoenix's exact list. `SWEP.Type` is **not** usable: the arsenal has tesla
weapons typed `Heavy` and gauss typed `Sniper`, while `Energy` itself spans
several ammo types. Keying off type would mis-bucket precisely the weapons this
attribute is meant to cover.

### Endurance and the fixed stamina pool

The stamina plugin's pool is hardcoded 0-100 everywhere, so the tank cannot be
resized directly. Scaling the per-tick offset through the plugin's own
`AdjustStaminaOffset` hook achieves the same thing: a bigger effective pool moves
the same 0-100 bar more slowly in both directions, so it lasts proportionally
longer. Nothing in the plugin needs editing.

`ix.special.GetMaxStamina(character)` is what that 100 represents.

### Jumping costs stamina, and Endurance buys more jumps

The charge itself is **`libs/sh_jump.lua`** and predates this — see
[25-chems.md](25-chems.md#jumping--libssh_jumplua) for the winded rule, the
rising-edge detection and why it lives in `SetupMove`. What is new is that the
cost now scales with the pool:

```lua
ix.jump.Cost(client) = jumpStaminaCost * (100 / GetMaxStamina(character))
```

Endurance cannot make the bar bigger — it is hardcoded 0-100 in Helix's plugin —
so `AdjustStaminaOffset` makes the same bar drain more slowly instead. A flat
jump cost was the one thing left that ignored the pool entirely, so an Endurance
10 character had a bar that lasted twice as long at a sprint and *exactly* four
and a half jumps. At the defaults the cost is now 22.2 of the bar at Endurance 0
and 13.9 at Endurance 10: four and a half jumps, and a little over seven.

`jumpStaminaCost` is edited in `/liveedit` as **jumps from a full bar** rather
than as a cost — the box holds 4.5 and the field's `Read`/`Write` do the
division, because "four and a half jumps" is the thing being decided.

### Agility moves you at both speeds

`specialWalkPerAgility` (2) and `specialSpeedPerAgility` (4). It used to add to
running only, which made Agility an attribute that did nothing at all in a
settlement — and walking is what a character does for most of the time they are
alive. Both are applied in `ix.special.Apply`, which sets speed **absolutely**
and re-runs on every spawn and attribute change; anything applied anywhere else
is wiped the next time a point is spent.

### Luck loot comes in steps

`specialLootLuckStep` (5) and `specialLootPerStep` (1): every 5 points of Luck
is one more item in a container. A tenth of an item per point — what it was —
is a number nobody can feel: the difference between Luck 6 and 7 was nothing,
and the difference between 9 and 10 was a whole item arriving without
explanation.

### An earlier version double-applied

Helix's `stamina` and `strength` plugins do their own damage and drain work off
`str`/`end`. A first pass MIRRORED SPECIAL into those keys so the plugins would
apply the effects. Once this file implemented them itself, that mirror would have
applied each bonus twice. The legacy keys are now pruned and left at 0.

## Damage readout

`libs/cl_damageview.lua`, ported from Phoenix's `plugins/damageview`. On weapon
switch it prints the weapon's damage and the bonus SPECIAL adds, beside the
crosshair, then fades:

```
DMG: 20 (+12.03)
```

Two bugs fixed on the way over:

- **Their line 61 crashes on melee.** `self.energyAmmo[primary.Ammo]` is tested
  *before* the melee branch, and a melee weapon has no `Primary` table, so
  indexing it throws. Classification here goes through
  `ix.special.ClassifyWeapon`.
- **Unrounded floats.** They concatenate `damage * modifier` raw, printing
  `12.030000000001`. Formatted to two decimals.

Their `nut.rarity:dmgMult` call is dropped for now; the `GetWeaponDisplayDamage`
hook is where a rarity system plugs in, so this file will not need editing again.

## Fists

`ix_hands` and anything else with no ammo type counts as **melee**, so Strength
governs it. Phoenix never hit this: their fists went through a separate
`PlayerGetFistDamage` hook and never reached the classifier, so their version
would call `ix_hands` ballistic and scale it with Perception.

## Verifying

`fo_special` prints the character's attributes, whether each one registered, the
held weapon's classification, and every derived multiplier. The effects are
multipliers on other systems, so "is SPECIAL doing anything" is otherwise hard to
answer by looking.

**Attributes are set at character creation.** A character made before SPECIAL
existed has 0 in everything and will show no effect — make a new one.

## Configs

All under **Characters**, and all editable in `/liveedit` under SPECIAL.

| Config | Default | |
|---|---|---|
| `specialPoints` | 15 | the creation budget, spent exactly |
| `maxAttributes` | 25 | ceiling on one attribute |
| `specialDamagePerStrength` | 0.01 | melee damage per point |
| `specialDamagePerPerception` | 0.01 | ballistic damage per point |
| `specialDamagePerIntelligence` | 0.01 | energy damage per point |
| `specialBaseStamina` | 100 | the pool before Endurance |
| `specialStaminaPerEndurance` | 6 | pool per point |
| `staminaDrain` | 1 | sprint drain per quarter-second tick (Helix's) |
| `staminaRegeneration` | 1.75 | regeneration per tick (Helix's) |
| `staminaCrouchRegeneration` | 2 | regeneration per tick while ducked (Helix's) |
| `punchStamina` | 10 | a bare-handed punch (Helix's) |
| `jumpStaminaCost` | 22.22 | stamina one jump costs at Endurance 0 — shown as *jumps from a full bar* in `/liveedit`. Its own library, `sh_jump.lua`, under **Movement** |
| `specialMugReductionPerCharisma` | 0.01 | share of a mugging demand talked down |
| `specialWalkPerAgility` | 2 | walk speed per point |
| `specialSpeedPerAgility` | 4 | run speed per point |
| `specialLootLuckStep` | 5 | Luck per extra container drop |
| `specialLootPerStep` | 1 | items each of those steps is worth |
| `specialXPPerLuck` | 0.02 | experience per point |
| `specialCraftPerLuck` | 0.02 | crafting luck per point |

The three damage rates **were one number**. Splitting them means a server that
wants Perception to matter more no longer has to make Intelligence matter more
as well. `ix.special.damagePerPoint` survives as the shared default.

## Hook collisions

Everything here uses `hook.Add`, not `function Schema:Name()`. A Schema method
is a single slot — `sv_hooks.lua` already defines `Schema:PlayerSpawn` for race
proportions, and defining it again would silently replace it.

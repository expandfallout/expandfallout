# Progression: SPECIAL, Leveling, Karma

## S.P.E.C.I.A.L. (plugin `attributes`, 817 LOC)
Seven attributes as sub-plugins, each `plugins/<name>/attributes/sh_<name>.lua`:
Strength, Perception, Endurance, Charisma, Intelligence, Agility, Luck.

Every one is just:
```lua
ATTRIBUTE.name = "Strength"
ATTRIBUTE.desc  = "..."
ATTRIBUTE.startingMax = 20
```

**Config:**
- `maxAttribs` = **15** — starting attribute points at character creation
- `maxAttribsInSpecial` = **25** — hard ceiling per attribute
- `strMultiplier` = **0.3** (default in code, `0.1` fallback in the getter — inconsistent, pick one)

**Validation on creation** (`onValidate`) requires spent points to be **exactly** `maxAttribs` — not under,
not over. Hook `GetStartAttribPoints` can override the budget per-player (races/factions use this).

**Actual mechanical effects wired up — only three:**
| Attribute | Effect |
|---|---|
| Strength | `PlayerGetFistDamage` → `+ attrib * strMultiplier` |
| Charisma | `GetSalaryExtra` → `pay = pay + charisma` |
| Agility | triggers `client:updateSpeed()` on purchase/respec (movement speed) |
| Endurance | referenced by `stamina` plugin |
| Luck | drives the **rarity roll** — see `07_items_and_rarity.md`. Its one real effect, but a big one |
| Perception / Intelligence | **flavour only** — no code effects |

So Perception and Intelligence do literally nothing mechanically. That's a real gap in their build and
an easy place for us to do better.

**Quirk to avoid:** attributes are stored under the lowercase filename key (`strength`) but read with
capitalised names (`char:getAttrib("Strength", 0)`). Their validator does `string.lower(k)`, the getters
don't. Pick one convention and hold it — Helix's `ix.attributes` keys off the filename, so use lowercase
everywhere.

**Helix port:** `nut.attribs` is a near-copy of Helix's built-in `ix.attributes`. Almost 1:1 —
`ATTRIBUTE.desc` → `ATTRIBUTE.description`, `onSetup` → `OnSetup`, `startingMax` is ours to reimplement
(Helix uses `maxValue` + `ix.config.Get("maxAttributes")`).

## Leveling (plugin `leveling`, 244 LOC)
Stored as **character data**, not registered vars: `char:getData("level", 1)`, `char:getData("XP")`,
`char:getData("skillPoints", 0)`, `char:getData("respecs", 0)`.

**XP curve:**
```lua
nut.leveling.spike = 50

function nut.leveling.requiredXP(level)
    if level > 50 then
        return requiredXP(50) + math.floor(1.22 ^ level)   -- exponential wall past 50
    elseif level > 0 then
        return (92 + (level * 2)) * math.max(level - 1, 0) + 200
    end
    return 0
end
```
Quadratic to 50, then brutal exponential. Level 50 is the intended "soft cap" — it's also the respec gate.

**Configs:** `XP Multiplier` (1), `XP Per Kill` (2), `Respect Cost` (1000) [sic — their typo],
`Extra Cost Per Respec` (1000), `Clamp Respec Cost Mult` (5), `Free First Respec` (true).

**Respec rules:** level 50+ required; first respec free if configured; else
`cost = RespecCost + (respecCount * ExtraCostPerRespec)`, respec count clamped at 5.

## Karma (plugin `karma`, 246 LOC) — two-axis, genuinely well designed
Stored as `char:getData("karma", {good, bad})` — **two independent counters**, not one signed number.
Networked to clients via player netvar `karma`.

```lua
ratio = (good - bad) / (good + bad)
```

- **Alignment** = which of 3 title columns you get: `ratio > 0.3` → good, `< -0.3` → evil, else neutral
- **Karma level (1-50)** = *total* activity `good + bad` crossing cumulative thresholds:
  `threshold += 100 + (15 * (level - 1))`
- **Title** = `types[level][alignment]` from a 50×3 table
  (L1 `Samaritan / Drifter / Grifter` → L50 `Ascendant / Outcast / Annihilator`)
- **Colour** = red from bad ratio, green from good ratio, blue fades with `|ratio|`

So "karma level" is **notoriety** (how much you've done) and alignment is **which way**. A quiet saint and a
quiet monster both sit at low level. Worth keeping — it's better than a single slider.

**Faction karma:** separate 11-tier table from `+100` (Wasteland Angels) to `-100` (Wasteland Devils),
keyed by `ratio * 100`, each with a HUD icon `phoenix/hud/karma_*.png`.
Per-faction karma awards live on the faction: `FACTION.karma = { kill = {good, bad}, passive = {good, bad} }`.

**Config:** `karmaTimer` = 60s passive karma tick.

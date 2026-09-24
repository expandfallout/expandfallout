# Character Model (Divide Rebirth / NutScript fork) → Helix port notes

## CRITICAL: their NutScript core is FORKED, not stock
Race and appearance are registered as **core character vars** inside
`gamemodes/nutscript/gamemode/core/libs/sh_character.lua` — i.e. they modified the framework itself.

**We must NOT fork Helix.** Everything below gets registered from our schema via
`ix.char.RegisterVar(key, data)` instead. Helix supports this cleanly from schema code, so we get the same
result without maintaining a framework fork. This is a strict improvement over their setup.

## Their full character var list
| Var | DB field | Default | Notes |
|---|---|---|---|
| `name` | `_name` | — | stock |
| `desc` | `_desc` | — | stock (Helix: `description`) |
| `brand` | `_brand` | — | custom — the `branding` plugin |
| `heightDesc` | `_heightDesc` | — | custom flavour text |
| `weightDesc` | `_weightDesc` | — | custom flavour text |
| `model` | `_model` | — | stock |
| `faction` | `_faction` | — | stock |
| `class` | `_class` | — | stock |
| `money` | `_money` | — | stock (currency = Caps, symbol `©`) |
| `gender` | `_gender` | `"male"` | custom |
| `race` | `_race` | `"human"` | custom — drives everything appearance-related |
| `skinColor` | `_skinColor` | `"caucasian"` | custom — really "ethnicity" |
| `hairColor` | `_hairColor` | `"255 255 255"` | custom, stored as string, `string.ToColor` on get |
| `faceMap` | `_faceMap` | `1` | custom — face bodygroup/skin index |
| `hair` | `_hair` | `1` | custom — hair bodygroup index |
| `beard` | `_beard` | `1` | custom — beard bodygroup index |
| `muscles` | `_muscles` | `0` | custom — bool stored as 0/1 |
| `skillPoints` | `_skill` | `0` | custom, `isLocal`, `noDisplay` |
| `attribs` | — | — | registered by the `attributes` PLUGIN, not core |
| `data` / `var` / `inv` | — | — | stock |

## The `tempRace` mechanism (important, and clever)
A **player netvar** `tempRace` temporarily overrides the character's race without touching saved data.
Every appearance var's `onGet` checks it:

- `race:onGet` → returns `tempRace` if set
- `gender:onGet` → falls back to `nut.races:getFirstGender(tempRace)`
- `skinColor:onGet` → falls back to `nut.races:getFirstSkinColor(tempRace, gender)`
- `faceMap` / `hair` / `beard`:onGet → **return 0** when `tempRace` is set (non-human models have no
  face/hair/beard bodygroups)

Used by: `transformationchambers`, Unstable F.E.V., psyker transformations.
Port note: Helix has `client:SetLocalVar` / `SetNetVar`; same pattern works. Registering our vars with
`OnGet` in `ix.char.RegisterVar` reproduces this exactly.

## Appearance is layered, on ONE model
Most humans use a single model — `models/phoenix/humans/animations.mdl` — and the look is composed from:

```
race → gender → skinColor (ethnicity) → faceMap / hair / hairColor / beard / muscles
```

So character customisation is bodygroup + skin manipulation, not a model list. This is why
`FACTION.models` in their schema is a **keyed** table (`["models/....mdl"] = true`) — it's a validation
set, not a picker list. Helix's `ix.faction.LoadFromDir` iterates with `pairs` and expects values to be
model strings or `{model, skin, bodygroups}` tables, so **every faction needs converting to array form**
or character creation silently breaks.

## Leveling is NOT a registered var
`plugins/leveling/sh_plugin.lua` uses `char:getData("level", 1)` / `char:setData("level", ...)`.
Same for XP. Helix equivalent: `character:GetData("level", 1)` / `character:SetData(...)`.
Cheaper than a registered var, but no automatic networking — they network manually to
`select(2, player.Iterator())`.

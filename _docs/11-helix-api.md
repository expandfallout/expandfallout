# 11 — Helix API notes

Things I had to dig through the framework to establish. Saves re-reading it.

## Hook dispatch — the most important one

Helix **overrides `hook.Call`** (`gamemode/core/libs/sh_plugin.lua:342`):

```
plugins  →  Schema[name]  →  gamemode
```

A **non-nil return short-circuits**. So `function Schema:TranslateActivity(...)`
cleanly overrides Helix's `GM:TranslateActivity` with no framework edits.

Two consequences:

- Returning **nil** hands the event on to Helix — which is *not always safe*.
  Its `GM:DoAnimationEvent` indexes `client.ixAnimTable` without checking it,
  and that's nil for a model class we registered ourselves.
- You can **suppress** a Helix behaviour by returning non-nil. `Schema:KeyPress`
  returns `true` only for `IN_RELOAD`, which kills Helix's raise-on-R while
  leaving `IN_USE` (doors) working.

## Character variables

`ix.char.RegisterVar(key, data)` generates `Get<Key>`/`Set<Key>` on the
character metatable. Options:

| Field | Effect |
|---|---|
| `field` | DB column, auto-added to the `ix_characters` schema |
| `default` | |
| `isLocal` | network to the owning client only |
| `bNoNetworking` | server-only |
| `bNotModifiable` | no setter generated |
| `OnSet` / `OnGet` / `OnValidate` | override behaviour |
| `index`, `ShouldDisplay` | charcreate ordering/visibility |

**This is how we add race, gender, skinColor, hair, beard, muscles and
skillPoints without forking Helix** — which is exactly what Phoenix had to do
to NutScript. Do not fork.

Stock vars: `name description model class faction attributes money data var
createTime lastJoinTime schema steamID Inventory`.

Cheaper alternative for simple values: `character:GetData(k, default)` /
`SetData(k, v)`. No automatic networking — Phoenix used this for level and XP.

## Factions

`ix.faction.LoadFromDir` iterates `FACTION.models` with **`pairs` and precaches
the VALUE**, expecting a model string or `{model, skin, bodygroups}`.

```lua
FACTION.models = { ["models/x.mdl"] = true }   -- WRONG, silently breaks charcreate
FACTION.models = { "models/x.mdl" }            -- correct
```

Phoenix wrote the keyed form throughout, so **every ported faction needs
converting**. Also `FACTION.desc` → `FACTION.description`.

Each faction needs exactly one class with `isDefault`, or `KickClass` errors.

## Animations

- `ix.anim.SetModelClass(model, class)` / `ix.anim.GetModelClass(model)`
- `ix.anim.<class>` holds the tree; ours set `useADV = true`
- `client:IsWepRaised()`, `SetWepRaised(bool, weapon)`, `ToggleWepRaised()`
  — **`ToggleWepRaised` is `@realm server`**, so it must be networked
- Helix's `GM:CalcViewModelView` rotates the viewmodel by `SWEP.LowerAngles`
  (default `Angle(30,0,-25)`) while lowered
- `GM:DoAnimationEvent` receives **`PLAYERANIMEVENT_*`**, not `PLAYER_*`

`TranslateActivity` must return an **activity**, so for sequence names:
`LookupSequence` → `SetSequence` → return `GetSequenceActivity`.

## Weapon raise

Bound to `IN_RELOAD` in `gamemode/core/hooks/sv_hooks.lua:115`, held for
`ix.config.Get("weaponRaiseTime")`. There's also a `ToggleRaise` chat command.

`GM:PlayerSwitchFlashlight` is **not** a usable input hook — GMod only fires it
if the player is permitted a flashlight and Helix never calls
`AllowFlashlight`. Use `PlayerBindPress` (client) + a net message.

## Config, commands, attributes

```lua
ix.config.Add(key, value, description, callback, data, bNoNetworking, bSchemaOnly)
ix.config.Get(key, default)
ix.config.SetDefault(key, value)
```

Commands are **typed** — better than NutScript's syntax strings:

```lua
ix.command.Add("Name", {
    description = "...",
    adminOnly = true,
    arguments = {ix.type.player, ix.type.number},
    argumentNames = {"target", "amount"},
    OnRun = function(self, client, target, amount) end
})
```

Helix registers a CAMI privilege automatically. `data.group` is deprecated.

Attributes: `ix.attributes.list`, `ix.attributes.Setup(client)`,
`character:GetAttribute(k, d)`, `SetAttrib`, `UpdateAttrib`, `AddBoost`,
`RemoveBoost`. Keys are the **lowercase filename**.

## Database

SQLite by default — no `helix.yml` needed, `sv.db` already exists.
`ix.db.Connect()` falls back to sqlite when `ix.config.server.database` is
absent. `ix.db.AddToSchema(table, field, type)` adds columns; `ix.char`
registers them automatically for vars with a `field`.

For MySQL later: copy `gamemodes/helix/helix.example.yml` to `helix.yml`.

## Useful player/character methods

```lua
client:GetCharacter()          character:GetPlayer()
client:Notify(msg)             client:NotifyLocalized(key, ...)
client:GetNetVar/SetNetVar     client:GetLocalVar/SetLocalVar
character:GetData/SetData      character:GetInventory()
ix.currency.Get(amount)        ix.currency.Set(symbol, singular, plural, model)
```

## What Helix does NOT have

- **Item stacking** — no quantity, no merge, no split. See `07-gotchas.md`.
- **Races** — ours to build as `ix.races`.
- **A rarity system** — port `nut.rarity` as `ix.rarity`.
- **An admin list** — CAMI only, falling back to GMod usergroups.

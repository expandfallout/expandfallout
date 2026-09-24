# Fallout RP — Reference Notes

Mined from the NutScript "Divide Rebirth" scrapes so we can build the **Helix** schema in
`garrysmod/gamemodes/falloutrp/`. Nothing here is code to copy — it's design, data and gotchas.

## Index

| Doc | Contents |
|---|---|
| `00_plugin_inventory.txt` | all 94 plugins, LOC, file count, description — sorted by size |
| `01_character_model.md` | character vars, race/appearance layering, the `tempRace` trick |
| `02_progression.md` | SPECIAL, XP curve, respec rules, the two-axis karma system |
| `03_armor_and_survival.md` | 14 armor slots, DR, Power Armor, radiation, stamina, dismemberment |
| `04_factions_data.md` | all 33 factions — flags, colours, karma weights, capture rules |
| `05_races_data.md` | all 43 implemented races (+15 stubs) with HP/scale/jump/rules |
| `06_weapons_data.md` | all 177 weapons — type, ammo, damage, clip, recoil, cone |
| `07_items_and_rarity.md` | item bases, the crafting material set, **the 8-tier rarity system** |
| `08_configs.md` | all 175 server configs with defaults and categories |
| `09_pvp_territory.md` | raids, wars, conquest, ambush, capture points, PK penalties, guilds |
| `10_geck_and_crafting.md` | the GECK (and why most of it is unusable), working crafting systems |
| `11_ui.md` | their two widget libraries and how Helix's UI differs |

## Source material at a glance

| Source | What it is |
|---|---|
| `latest_dev_scape/` | **best copy** — NutScript "Divide Rebirth", updated to v0.3.0 (May 2026) |
| `lastest_client_scrape/`, `old1–old5/` | earlier scrapes of the same server; `old1` also holds three *other* servers |
| `old1/<scraped-server>_27062` | an unrelated **SCP-RP / DarkRP** server — not useful here |
| `random_fallout_schema/` | small unrelated NutScript Fallout schema by netzona.org, ~10 plugins |
| `incursion-source-HAS_BACKDOORS/` | **empty**, 0 files |
| `phoenixsourceaddons/` | 78 workshop addons — content for the above, none installed yet |

**Scale:** 147k LOC schema (2,057 files, 94 plugins) + 128k LOC addons.
**Every scrape is client-side only** (glua-steal): 1,770 `sh_` files, 186 `cl_` files, **0 `sv_` files**.
Server logic inside `if (SERVER)` blocks of shared files survived; standalone `sv_*.lua` did not.

---

# NutScript → Helix translation guide

## Core naming

| NutScript | Helix |
|---|---|
| `nut.*` | `ix.*` |
| `SCHEMA` | `Schema` |
| `PLUGIN` | `PLUGIN` (same) |
| `nut.util.include` / `includeDir` | `ix.util.Include` / `ix.util.IncludeDir` |
| `PLUGIN.desc`, `FACTION.desc`, `ITEM.desc` | `.description` |
| camelCase methods (`getName`) | PascalCase (`GetName`) |
| `onRun`, `onSet`, `onCanBe` | `OnRun`, `OnSet`, `CanSwitchTo` |

## Character

| NutScript | Helix |
|---|---|
| `client:getChar()` | `client:GetCharacter()` |
| `char:getName()` / `getFaction()` / `getMoney()` | `character:GetName()` / `GetFaction()` / `GetMoney()` |
| `char:getData(k, d)` / `setData(k, v)` | `character:GetData(k, d)` / `SetData(k, v)` |
| `nut.char.registerVar(key, data)` | `ix.char.RegisterVar(key, data)` |
| `client:getNetVar` / `setNetVar` | `client:GetNetVar` / `SetNetVar` |
| `client:getLocalVar` / `setLocalVar` | `client:GetLocalVar` / `SetLocalVar` |
| `client:notify(msg)` | `client:Notify(msg)` |
| `client:notifyLocalized(k, ...)` | `client:NotifyLocalized(k, ...)` |

`ix.char.RegisterVar` auto-generates `Get<Key>` / `Set<Key>` on the character metatable. Options:
`field` (DB column, auto-added to `ix_characters` schema), `default`, `isLocal` (network to owner only),
`bNoNetworking`, `bNotModifiable`, `OnSet`, `OnGet`, `OnValidate`, `index`, `ShouldDisplay`.

**This is how we add race/gender/skinColor/hair/beard/muscles/skillPoints without forking Helix** —
which is exactly what they had to do to NutScript.

## Config, commands, attributes

| NutScript | Helix |
|---|---|
| `nut.config.add(k, v, desc, cb, data)` | `ix.config.Add(k, v, desc, cb, data, bNoNetworking, bSchemaOnly)` |
| `nut.config.get(k, d)` / `setDefault` | `ix.config.Get(k, d)` / `ix.config.SetDefault` |
| `nut.command.add(name, {onRun = …, syntax = "<string x>"})` | `ix.command.Add(name, {OnRun = …, arguments = {ix.type.string}})` |
| `nut.attribs.list` / `.setup` | `ix.attributes.list` / `ix.attributes.Setup` |
| `char:getAttrib(k, d)` | `character:GetAttribute(k, d)` |
| `char:setAttrib` / `updateAttrib` | `character:SetAttrib` / `character:UpdateAttrib` |
| `char:addBoost` / `removeBoost` | `character:AddBoost` / `character:RemoveBoost` |

**Helix commands are typed.** Instead of a `syntax` string you declare
`arguments = {ix.type.player, ix.type.number}` and optional `argumentNames`. Helix parses and validates
for you, and registers a CAMI privilege automatically. Strictly better — use it.

## Factions and classes

| NutScript | Helix |
|---|---|
| `nut.faction.indices` / `.teams` | `ix.faction.indices` / `ix.faction.teams` |
| `nut.faction.get` | `ix.faction.Get` |
| `nut.class.list` | `ix.class.list` |
| `CLASS.onCanBe(client)` | `CLASS.CanSwitchTo(client)` |
| `char:setClass(i)` / `joinClass` | `character:SetClass(i)` / `character:JoinClass(i)` |

**Faction gotchas when porting the 33 faction files:**
1. `FACTION.desc` → `FACTION.description`
2. `FACTION.models` keyed table (`["model"] = true`) → **must become an array** —
   Helix iterates `pairs()` and precaches the *value*, so `true` silently breaks charcreate
3. `FACTION.races`, `karma`, `radio`, `flagModel`, `flagSkin`, `canCapture`, `canAmbush`, `raidImmune`
   are all custom — they carry over as-is, we just have to write the code that reads them
4. Helix requires each faction's classes to have exactly one `isDefault` or `KickClass` errors

## Items and inventory

| NutScript | Helix |
|---|---|
| `nut.item.list` / `.instances` | `ix.item.list` / `ix.item.instances` |
| `item:getData` / `setData` | `item:GetData` / `item:SetData` |
| `ITEM.functions.X = {onRun, onCanRun}` | `ITEM.functions.X = {OnRun, OnCanRun}` |
| `inv:add(id, qty)` (promise-based) | `inventory:Add(id, quantity)` |
| `item:removeFromInventory()` | `item:Remove()` |
| **`item:getQuantity` / `setQuantity` / `onCombine` / `isStackable`** | **DOES NOT EXIST — must be built** |

## Known-absent in Helix, must be built by us

1. **Item stacking** — see `07_items_and_rarity.md`. Blocks all economy/crafting work.
2. **Rarity system** — port `nut.rarity` as `ix.rarity`. Self-contained, high value.
3. **Race system** — port as `ix.races` via `ix.char.RegisterVar`, no framework fork.
4. **Everything in `10_geck_and_crafting.md`** — loot tables and recipes don't exist in any form.

## Things in their build we should deliberately NOT copy

- Forking the framework to add character vars (`RegisterVar` from the schema does it properly)
- Clients calling an external webserver directly
- Three naming conventions for one attribute (`strength` / `Strength` / `STR`)
- Two parallel Derma widget libraries
- `math.randomseed()` on every rarity roll
- `Explosive` dismemberment `HITGROUP_LEFTLEG = 15` (typo for `1.5`)
- `r_cleardecals` printing to console every 5 minutes
- The dead `cw_*` / `wf_*` crosshair check
- Perception and Intelligence having zero mechanical effect

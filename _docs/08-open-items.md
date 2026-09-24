# 08 — Open items

## Needs verification (small)

**Wattz sniper scope offset.** `SWEP.ScopeOffset = {x = 0, y = 0.048}` is an
**unverified estimate** from a screenshot. Tune live with `ls_scope_tune_y`
(positive = crosshair down), then bake the final value in and reset the convar.

## UI - what is still stock

Appearance is done: the derma skin, the accent-colour bridge, the `ixFO*` widget
set and the `cl_panels.lua` patches cover the look of every Helix panel
(`16-ui.md`).

What is NOT done is **layout**, and the reason is the same in every case -
Phoenix's panels are built on systems this schema does not have yet:

| Phoenix panel | Blocked on |
|---|---|
| `derma/cl_charcustomize.lua` (36 KB) | races and bodygroup sets. SPECIAL now exists (`17-special.md`), so that half is unblocked |
| `derma/cl_special.lua` | SPECIAL attributes |
| `plugins/perks/derma/cl_perks.lua` | the perk system |
| `vgui/cl_fo_inv.lua` | its own drag-drop against `nut.item.held`; Helix's grid inventory already works and is structurally equivalent, so this is a rewrite with no functional gain |
| `derma/cl_mainmenu.lua`, `cl_charload.lua` | mostly cosmetic over Helix's flow, but assumes their faction/guild data |
| `schema/tgui/` | a second widget set Phoenix uses for admin tools; nothing needs it yet |

The sensible order is to build the underlying systems first (races, SPECIAL,
perks) and port the panel alongside each - porting the panel first would just
mean writing it twice.

**Diagnostics still installed** — remove once their questions are closed:
- `addons/falloutrp_weapons/lua/autorun/sh_firerate_diag.lua` (`fo_firerate`)
- `addons/falloutrp_weapons/lua/autorun/server/sv_firerate_trace.lua`
  (`fo_tracefire`, `fo_tracefire_report`)
- `addons/_zz_verify/` (boot report)

**Dev commands** — `sv_dev_weapons.lua` (`fo_give`, `fo_giveall`, `fo_ammo`,
`fo_weapons`). Delete when real ammo items exist.

---

## Blockers

### Missing appearance content

The human race declares 53 appearance models and 112 facemap materials. Of
those, **14 beards and all 112 facemaps are not installed** — `phoenix_anims`
ships only `animations.mdl`, five files, with no face pack.

`ix.races` drops them at load, so nothing renders as an error model; the beard
and face pickers simply do not appear. `fo_races_report` prints the current
answer, which is the one that counts.

To close this, the content pack containing
`models/roadkill/fallout/player/male/beard/*.mdl` and
`materials/phoenix/humans/shared/skin/*_facemap*` needs mounting. Nothing in
the code changes — the entries are still declared, so a restart picks them up.

### Item stacking — blocks all economy work

Helix has **none**. `grep` for `SetQuantity|GetQuantity|isStackable|maxQuantity|
OnCombine` across the whole gamemode returns nothing. `inventory:Add(id, 5)`
creates **five separate item instances**, each taking its own grid slot.

With ~40 crafting materials, 28 ammo types, food, drink, chems and junk, an
unstacked inventory is unusable within an hour of play.

**Spec** (NutScript's shape, which is a good one):

```lua
ITEM.isStackable = true
ITEM.maxQuantity = 20
ITEM.canSplit    = true

item:GetQuantity() / item:SetQuantity(n)
ITEM:OnCombine(other)     -- drag item onto item to merge
```

Behaviour to reproduce:

- **Merge on add** — adding to an inventory that already holds a compatible
  stack tops it up rather than making a new instance
- **Overflow** — merging past `maxQuantity` leaves the remainder on the source
  item instead of destroying it
- **Split** — a right-click action with a quantity prompt
- **Rarity-aware** — refuse to merge items of different rarity. Rarity is
  per-instance, so a Rare stimpak and a Common one are not the same item
- **Grid rendering** — draw the quantity number on the item's icon

Touch points: `ix.meta.item`, `ix.inventory` (`Add`, and the grid fit logic),
and the inventory derma.

**Do this before any economy, crafting or ammo-item work.** Ammo items in
particular are meaningless without it.

### GECK data is gone

Phoenix's loot tables, containers, crafting recipes and custom perks lived on
an external webserver (`<phoenix-geck-host>:2001`). There are **no local data
files** in any scrape — only the editor UIs.

All loot and recipes must be designed from scratch regardless of framework.
Don't point anything at that address; it isn't ours.

If we build an equivalent, it persists to the **local** Helix database and the
**server** fetches — never the client, which is how theirs worked.

---

## Next systems, roughly in dependency order

Done since this list was first written: **SPECIAL**, **races** (`ix.races`), the
**appearance layer** and customiser, and **height/weight/age**. What follows is
what is actually left.

### SPECIAL attributes that compute a value nothing uses

Three of the seven do real work today — Strength/Perception/Intelligence feed
weapon damage, Agility feeds run speed, Endurance feeds stamina. The other two
have their maths written and no consumer, because the systems they feed do not
exist yet:

| Getter | Waiting on |
|---|---|
| `ix.special.GetExperienceMultiplier` | levelling / XP |
| `ix.special.GetBonusLootCount` | lootables + rarity |
| `ix.special.GetCraftingLuck` | crafting |
| `ix.special.GetMugReduction` | the mugging system |

`fo_special` prints all four, which is the only thing calling them. Charisma and
Luck are therefore cosmetic at the moment — worth knowing before balancing them.

### The list

1. **Item stacking** — see Blockers. Still gates all economy work.
2. ~~**Levelling / XP**~~ — **done**, see `22-leveling.md`. The F1 SPECIAL tab
   is now interactive: skill points are spent there and RESPEC works. Perks are
   unblocked. Luck and Charisma still have no consumers of their own.
3. **Perks** — depends on levelling.
4. **Rarity** (`ix.rarity`) — port near-verbatim, it is the best-designed thing
   in their codebase. Drop the `math.randomseed` call.
5. ~~**Armour v2**~~ — **done**, see `20-armour.md`. 685 items, 14 slots, DR
   split head/body, worn models swapped through `cl_bodyparts.lua`. What is
   still missing from it is listed at the end of that document: stealth, fusion
   core drain, radiation, and `playerHeight`.
6. **The remaining races** — 1 of 43 ported (`human`). Data in
   `reference/05_races_data.md`.
7. **The remaining factions** — 2 of 33. Data in `reference/04_factions_data.md`.
   Remember `FACTION.models` must be an **array**.
8. **Karma**, then the PvP layer (raids, wars, capture points).

### Built since that list

- **Vehicles** — see `53-vehicles.md`. Sixteen LVS definitions with
  positions read off each model, deploy items, ownership, packing, despawn
  and refunds. Needs in-game tuning of seats and wheels on the box-guessed
  models; `fo_vehicle_report` prints what to tune.
- **NPC spawners** — see `54-npcs.md`. Presets in the schema's armour and
  guns, pods that wake and sleep, a VJ weapon per weapon item.

### Recently done

- **Developer tools** — see `24-devtools.md`. The terminal rebuilt into four
  sections, and a toolgun for placing lootables at speed.
- **Looting** — see `23-looting.md`. Loot tables, containers, the in-game
  configurer and placer, local persistence. Luck now has a real consumer.
- **Levelling** — see `22-leveling.md`. XP, the curve, both popups, the
  under-menu XP bar, skill points and respec.
- **Hunger & thirst** — see `21-hunger.md`. 201 food items, both meters, tier
  debuffs and buffs, stamina interaction, alcohol. Radiation now has real
  sources through irradiated food, so it is no longer admin-command only.

### Known unsatisfying

- **The test bot UI.** The spawning works - real bots, real armour, real damage
  path, respawning in place - but the *selection* interface is not what was
  wanted. Currently a DR-preset row plus a resistance-ordered list. What was
  asked for was a more in-depth way to pick specific armour, per slot, and
  build a set. Left as-is deliberately; revisit with a clearer picture of the
  intended flow rather than another guess.

### Smaller, already discussed

- **Height/weight/age on the HUD** when you look at someone. The vars are stored
  separately for exactly this, so nothing needs parsing out of the description.
- **Player-kill (PK)** — the only thing that may change a character's
  height/weight/age after creation. Deliberately untouched.
- **Main menu logo and music player** — skipped on request, not forgotten.
- **Remove the temporary diagnostics**: `sh_firerate_diag.lua`,
  `sv_firerate_trace.lua`, the `_zz_verify` addon.
- **`ls_wattz_sniper` `ScopeOffset`** still unverified.

---

---

## Deliberately not done

- **`ls_thor_projectile`** — no weapon references it.
- **`ls_heavy_plasma_repeater`** — model absent from all 78 addons; weapon
  removed rather than shipping an ERROR prop.
- **Longsword licensing** — recovered from a scrape, not obtained from its
  author. Fine locally; **a release blocker** before going public.
- **~11 sound files** referenced by weapons don't exist in the content (mostly
  one laser rifle reload segment shared by 5 weapons). Silent, no errors.
- **15 stub races** in Phoenix's data contain only `print("")` — mirelurks,
  brahmin, cazadors and others were never finished. Ours to build if wanted.

---

## Server config, when going public

Checklist is at the bottom of `garrysmod/cfg/server.cfg`: `sv_lan 0`, GSLT,
RCON password, content delivery (workshop collection or FastDL), revisit
`sv_kickerrornum`, and decide whether staff get sandbox spawn access through an
admin mod.

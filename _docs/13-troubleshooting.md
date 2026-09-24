# 13 — Troubleshooting: symptom → cause

Every entry below is a bug that actually happened on this project. If a symptom
matches, check the listed cause **before** forming a new theory.

---

## Weapons and rendering

| Symptom | Cause | Fix |
|---|---|---|
| Gun invisible in third person, viewmodel fine | `LookupAttachment` returned **0** (truthy), then `GetAttachment(0)` returned nil and `DrawWorldModel` bailed | Check `id > 0`, fall back to `ValveBiped.Bip01_R_Hand` |
| No muzzle flash on most weapons | `FireAnimationEvent` returned `true` for events 21/5001/5003/5011/5021/5031, suppressing the engine flash | Only suppress when `MuzzleFlashEffect` is set |
| Tracer starts at the player's **head** | Muzzle lookup fell through to `data:GetStart()` (the eye). These models have **no `muzzle` attachment** — they use `ProjectileNode` | Try `ProjectileNode` first |
| Tracer starts at the player's **waist** | `GetBonePosition` on a viewmodel returns the entity origin when bone matrices aren't built; a viewmodel entity sits at the player's origin | `SetupBones()` then `GetBoneMatrix(bone):GetTranslation()` |
| Tracer starts *past* the barrel | `ProjectileNode` is the barrel tip, ahead of where the flash draws | Raise `EFFECT.MuzzleInset` |
| No tracers at all | `FireBullets` gives its tracer effect **Scale 0**, and the stock `Tracer` treats Scale as velocity | Spawn our own; `Tracer = 0` on the bullet table |
| A model panel's entity loads but nothing draws | The model is `animations.mdl` - the animation skeleton, which has **no visible mesh**. Same cause as invisible players in-world | Bone-merge a body and head onto it (`ix.fallout.bodyParts`), and draw the parts from `DrawModel` - DModelPanel draws only `self.Entity` |
| A `DModelPanel` renders nothing | Its `Paint` was overridden. `DModelPanel:Paint` **is** the renderer - LayoutEntity, `cam.Start3D`, lighting, DrawModel - so replacing it with a background fill draws no model | Never override Paint on a model panel; put the backdrop on its parent |
| A `DScrollPanel`'s canvas will not stay where you put it | `DScrollPanel:PerformLayout` ends with `pnlCanvas:SetPos(0, YPos)` (GMod's `dscrollpanel.lua:90` and `:122`) and re-runs every layout pass, so any canvas position you set is overwritten | Do not offset the canvas. Put the padding on a child's `DockMargin`, which the dock layout applies and DScrollPanel never touches |
| Padding all ends up on one side of a panel | `DockPadding` was set during a PARENT's layout pass, but the panel's own `PerformLayout` - which positions its canvas from that padding - already ran this frame with the padding still at zero, and setting it does not re-trigger it | `panel:InvalidateLayout(true)` after setting the padding, before measuring |
| A panel ignores `SetPos`/`SetSize` completely | It is **docked**. Docking repositions the panel every layout pass and overwrites anything set manually. Helix's own character-menu `SetPos` is dead code for this reason | `panel:Dock(NODOCK)` before positioning |
| A flat `surface.DrawRect` renders as a gradient or an image | **`surface.DrawRect` uses whatever texture is currently bound.** A `SetTexture`/`SetMaterial` earlier in the same paint function leaks into it, so the "solid" rect draws that texture tinted by the draw colour. This is what turned the character creation screen olive | `draw.NoTexture()` before the DrawRect. There were **11** of these across the UI files |
| Tracer purple/black checkerboard | Custom material exists only on the server. **Dedicated servers don't send materials** | Fallback chain checking `IsError()` |
| Tracer visible but stutters | Animated on `CurTime()`, which is tick-quantised | Use `RealTime()` for visuals |
| Weapon appears to fire at double rate | Two tracer spawn sites; the prediction filter didn't suppress the server copy | **One spawn site**, `bIgnorePredictionFilter = true` |
| Extra tracer on energy weapons | `Primary.Tracer = false` eaten by an `or` fallback, **or** keying "is energy" off `SWEP.Type` (5 plasma weapons are typed `Heavy`) | Handle `false` explicitly; key off `MuzzleFlashEffect` |
| Gun off-screen when lowered | Helix's `CalcViewModelView` **and** Longsword both applying a lowered pose | `SWEP.LowerAngles = Angle(0,0,0)` |
| Some weapons never holster | 57 weapons define no `LoweredPos` | File-local default in `GetOffset` — **not** a SWEP field (breaks `CalculateSpread`) |
| Scope fires below the crosshair | Texture's reticle isn't centred; bullets go to true screen centre | `SWEP.ScopeOffset`, tune with `ls_scope_tune_y` |
| Scope entirely black | Black fill drawn *behind* the overlay — the lens is a transparent hole | Fill only the exposed edge strip |
| Silent reload | Weapon has no `SWEP.Events` table at all (5 remaining, all utility items) | Add `RELOAD_START` entries |
| Silent explosion | `grenade_frag_explode` is **visual-only**; `effect_fo3_fatman` carries its own audio | Emit sound from the entity |
| `Tried to use a NULL entity!` at `GetOwner` in an effect | Scraped `fo3_*` effects call `self.WeaponEnt:GetOwner():GetVelocity()` unguarded, **once per particle**. `data:GetEntity()` can be NULL by the time the effect runs | Phoenix's own guard — cache `velocity` once at the top of `Init` (see below) |
| `attempt to index field 'WeaponEnt' (a nil value)` in `EFFECT:Think` | `Init` bailed early, so `self.WeaponEnt` was never set, but `Think` still runs | `if not IsValid(self.WeaponEnt) then return false end` as the first line of `Think` |
| Projectile is an invisible ERROR prop | Entity's `init.lua` was server-only and lost to the scrape | Write one — see `03-weapons.md` |

### The effect velocity guard

Phoenix hit this first and fixed four of their own effects with this exact
pattern. We applied it to the remaining nine rather than inventing a new one:

```lua
local velocity = Vector(0, 0, 0)

if IsValid(self.WeaponEnt) and self.WeaponEnt.GetOwner and IsValid(self.WeaponEnt:GetOwner()) then
    velocity = self.WeaponEnt:GetOwner():GetVelocity()
elseif IsValid(self.WeaponEnt) and not self.WeaponEnt.GetOwner then
    velocity = self.WeaponEnt:GetVelocity()
end
```

The `elseif` matters: some effects are played on a non-weapon entity, which has
no `GetOwner` at all but does have its own velocity.

`fo3_muzzle_gatlinglaser` and `fo3_muzzle_spretel` solve it differently — they
bail at the top of `Init` on `IsValid(data:GetEntity():GetOwner())`. That's
equally safe, so it was left alone. Don't "fix" it to match.

**When batch-editing these files, don't blind-replace the call with the cached
name** — the guard body contains the call too, and you'll produce
`velocity = velocity`, which silently pins the value to zero with no error.


## Animations

| Symptom | Cause | Fix |
|---|---|---|
| Floating gun beside an open hand | Helix's lowered state uses `*_PASSIVE` (empty-handed) poses while the gun still draws | The NV animation system |
| Player invisible, gun floats | `animations.mdl` has **no visible mesh** — by design | `cl_bodyparts.lua` bone-merges body + head |
| Player appears to hover | Race proportions not applied (`scale 0.85`, hull, view offset) | `sv_hooks.lua` on spawn/loadout/model change |
| Arm swings overhead when firing | `SetAnimation(PLAYER_ATTACK1)` picks a melee swing on this model | Play `SWEP.AttackAnim` as a gesture |
| `DoAnimationEvent` check never matches | The hook receives **`PLAYERANIMEVENT_*`**, not `PLAYER_*` | Use the right constants |
| No reload animation in third person | Returning `ACT_INVALID` on a missing sequence **cancels** it | Only suppress attacks; let reload/jump fall through |
| Everything that isn't a gun looks broken | Hold type had no branch in the tree (physgun, tools, crowbar, keys) | `HOLDTYPE_TRANSLATOR` |
| `attempt to index local 'animation' (a nil value)` | Fell through to Helix's `DoAnimationEvent`, which indexes `ixAnimTable` unchecked | Never fall through on an advanced model |
| Animation changes do nothing | Model is a **stored character var** — `FACTION.models` only affects new characters | `/charsetmodel` or a new character |
| Character creation silently broken | `FACTION.models` written as a keyed table | Must be an **array** |

## UI and the skin override

Every one of these came from overriding a Helix skin function. The rule they
all point at:

> **A Helix skin function may do FUNCTIONAL work, not just drawing.** Read the
> original before replacing it. Omitting a functional call throws no error - the
> feature simply stops existing.

| Symptom | Cause | Fix |
|---|---|---|
| **Can't type in chat** - box opens, keys do nothing | `SKIN:PaintChatboxEntry` overridden without `panel:DrawTextEntryText(...)`. Helix's `ixChatboxEntry` overrides `DTextEntry:Paint` completely, so the SKIN function is the *only* thing that draws the text, selection and caret. Input worked the whole time; it was invisible | Call `panel:DrawTextEntryText(text, highlight, caret)` |
| Button / tab / frame-title text invisible | Filled the background **solid** with the palette colour while derma sets the text from `SKIN.Colours.*` - which is also the palette colour | Translucent highlights (`ColorAlpha(primary, 45-90)`), or set the matching `SKIN.Colours` entry to `color_black` |
| Chatbox loses its glow while open | Dropped `panel:GetActive()` - Helix fades the accent in behind the tab strip | Restore the branch |
| Chat autocomplete never highlights | Keyed off `panel:GetSelected()`, which does not exist on that panel; Helix animates `panel.highlightAlpha` | Use `highlightAlpha` |
| Chat tabs lose their unread marker | Dropped `panel:GetUnread()` | Restore it |
| NV HUD meters overflow the plate art | Tick run length was 43 x (magic fraction), unrelated to the artwork, and drifted with resolution rounding | Derive the pitch from the slot: `step = slotW / ticks` |

**Auditing an override.** Diff your version against Helix's original for calls
on `panel` and for return values - `PaintCategoryPanel` returns docking padding,
`PaintInfoBarBackground` calls `PaintManual()` on two children. A quick grep of
Helix's `cl_skin.lua` for `panel:` inside the function you are replacing catches
most of it.


## Load order and framework

| Symptom | Cause | Fix |
|---|---|---|
| `attempt to perform arithmetic on global 'X' (a nil value)`, firing every frame | A refactor removed a `local`, but a later line still reads the name. Lua turns that into a **nil global read** and only raises when the value is used — so an error inside a paint function repeats forever, and everything after it in that function never draws | `python _docs/tools/luaglobals.py <dir>` |
| `attempt to index global 'ix' (a nil value)` in autorun | `lua/autorun` runs **before** the gamemode | Defer to `hook.Add("Initialize", ...)` |
| A fix appears not to have applied, no error | Guarded `ix` access at file scope silently evaluated nil and installed nothing | Same fix — and prefer failing loudly |
| `attempt to call method 'getChar' (a nil value)` | A weapon calls NutScript methods | Compat aliases in `sh_falloutrp_compat.lua` |
| `table index is nil` in a weapon | Phoenix code indexes a table by a `FACTION_*` global. Those only exist if the schema defines that faction — ours defines two placeholders, so they're nil, and `[nil] = true` is a hard error, not a silent miss | `falloutFactionSet("unity", ...)` in `sh_falloutrp_compat.lua` — resolves unique IDs to live indices, skips missing ones |
| `attempt to index global 'nut'` inside a guard clause | The guard can't run if `nut` itself is nil | Minimal `nut` stub table |

## Addons and assets

| Symptom | Cause | Fix |
|---|---|---|
| ~150 `attempt to index global 'VJ'` / `non existant entity npc_vj_*` | Junctioned a Lua-bearing addon without its dependency | `cmd /c rmdir` the junction; copy the asset instead |
| Model shows as ERROR | Asset not in the search path | `resolve_asset.py` |
| Asset "missing" but you're sure it exists | Extraction regex required a leading letter — these names start with digits (`2hareloadj`, `1hpaim`) | Allow `[A-Za-z0-9_]` |
| `Unknown command` on boot | Convar doesn't exist in this GMod build | Remove it; check the sandbox gamemode for the real name |
| Hostname renders as `GÇö` | Non-ASCII in `server.cfg` | Keep it ASCII |

## Content (materials, models)

These come from **KeyValues, not Lua**, so `luacheck.py` never sees them and
they don't produce a stack trace. Sweep with
`python _docs/tools/vmtcheck.py garrysmod --fix`.

| Symptom | Cause | Fix |
|---|---|---|
| `KeyValues Error: LoadFromBuffer: missing {` | An **extra `}`** at EOF. The parser reads the stray brace as a new root key and hits EOF looking for its block | Delete it |
| `KeyValues Error: RecursiveLoadFromBuffer: got EOF instead of keyname` | An **unterminated string or block**. Four variants seen here: a missing `}`; a doubled quote `""path"`; a missing opening quote `$phong"`; a missing closing quote at end of line | `vmtcheck.py --fix` handles all four |
| Material renders but the effect doesn't scroll/animate | The `Proxies` block failed to parse while the root still loaded | Same check |

14 of the 3,636 VMTs shipped broken, across four different workshop addons. It
is **third-party content, not our code** — don't go looking for a Lua cause.

**These edits live in `addons/`, so a workshop update will revert them.** Re-run
the sweep after updating any content addon. Originals of the first batch are in
the session scratchpad under `vmt_backup/`.


## Server

| Symptom | Cause | Fix |
|---|---|---|
| A convar default was changed in code but the old value is still in effect | `CreateClientConVar(name, default, true, ...)` **saves to `client.cfg`**, and a saved value beats any later change to the default. The new default only applies to clients that never set it | Set it explicitly once (`fo_menu_width 0.467`), or create it with `false` for the save flag while the value is still being tuned |
| Server never loads a map (AI-launched) | Source's console needs an interactive session | **Expected.** Ask the user to run the bat |
| `console.log` truncated | `-condebug` is buffered; force-kill loses the tail | Write diagnostics to `garrysmod/data/` via `file.Write` |
| Client reports absurd rates | The client re-predicts ~19×/frame at 300 FPS on 16 tick | Guard with `IsFirstTimePredicted()`; trust the server |
| Weapons feel faster than another server | **Tick quantisation.** `Delay 0.1` → 0.125s at 16 tick, 0.1667s at 12 | Not a bug. Tune `Delay` if desired |
| Can't raise weapons at all | `IN_RELOAD` swallowed and the replacement never fired | `PlayerBindPress`, not `PlayerSwitchFlashlight` |

---

## When nothing matches

1. **Instrument it.** Counters at each pipeline stage, written to a file.
2. **Check both realms.** Server and client often disagree, and that disagreement is usually the answer.
3. **Diff against the source scrapes.** `some_source_code/old1_client_scrape/<scraped-server>_27064` is the *live* Phoenix server and differs from the dev scrape — 13 weapons were rebalanced between them.
4. **Suspect the API before the logic.** Source returns `0` and entity origins where you'd expect nil.

## A diagnostic command prints nothing in game

Check whether it uses `MsgC`/`print` alone. On a **dedicated** server those go to
the window the server is running in, not to the player who typed the command —
so a report can be working perfectly and look like the feature is dead.

`fo_permaprops` had exactly that fault while `fo_containers` beside it did not:
it printed one permanent prop to the server console every time and nothing to
the superadmin standing next to it.

Every report command should print **both** — chat for the person standing there,
console for the boot-time investigation:

```lua
local function Line(colour, text)
	if (IsValid(client)) then client:ChatPrint(text) end

	MsgC(colour, text .. "
")
end
```

## A method returns nil when its source says it cannot

Run `debug.getinfo(entity.Method, "S")` and look at `short_src`. Something else
may be defining it — an addon that writes to `FindMetaTable("Entity")` shadows
every scripted entity's method of that name. `fo_meta_report` lists every clash.

That was the cause of "pressing E on a container does nothing", below, and it
took five rounds because nothing in the gamemode is wrong.

## Pressing E on a Helix container does nothing

`ix_container:Use` is `if (inventory and (activator.ixNextOpen or 0) < CurTime())`
and nothing else — **no message, no sound, no notification** when either fails.
So a container whose inventory is not in `ix.item.inventories` is
indistinguishable from a prop that is not an entity at all.

`fo_container_report` prints every one of its preconditions for every container
on the map: the inventory id *and its Lua type*, whether the lookup resolves, the
model's definition, locked state, and the receiver list. It also dumps the keys
of `ix.item.inventories` with their types, because "the id is right and the
lookup misses" is a type mismatch until proven otherwise — a string key and a
number key look identical in every other message.

A container whose inventory is missing is now **restored on demand** from
`PlayerUse`, the same repair the faction storage uses: the id is on the entity
and the size is in `ix.container.stored`, so nothing is actually lost.

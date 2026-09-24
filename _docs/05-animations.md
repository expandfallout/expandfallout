# 05 — Animations, player model, proportions

## The problem this solves

Helix maps activities to HL2MP enums and, when a weapon is lowered, to the
`*_PASSIVE` set — empty-handed poses. Longsword draws the gun at the hand bone
regardless, so you got a floating weapon beside an open hand.

First person was always fine (that's the weapon's own viewmodel animations).
**Only third person was broken**, which is the tell that it's the *player*
animation set at fault.

## The New Vegas animation system

`models/phoenix/humans/animations.mdl` (from `phoenix_anims`, 14 MB, zero Lua)
carries **301 New Vegas sequences** with distinct lowered / raised /
ironsighted poses per weapon hold type — which is exactly what stock HL2
animations cannot express.

### Data — `schema/libs/sh_anims.lua` (689 lines)

Ported from Phoenix's animation tables. Only the **data** came across: these
are sequence names baked into the model, so they describe the asset.

```
ix.anim.<class>[<holdType>][<ACT_*>] = { lowered, raised, ironsighted }
```

Four classes: `falloutHuman`, `f4pa` (power armour), `supermutant`,
`securitron`. Each sets `useADV = true`, which is the flag our hooks look for.
`ix.anim.SetModelClass` binds the model to `falloutHuman`.

### Translation — `schema/sh_hooks.lua`

`Schema:TranslateActivity` picks the variant by weapon state and applies it.
The key mechanic: the tree stores **sequence names** but `TranslateActivity`
must return an **activity**, so it does `LookupSequence` → `SetSequence` →
return `GetSequenceActivity`.

**Hold type resolution** (`GetHoldType`): `SWEP.NVHoldType` if present (128
weapons declare one — `1hp`, `2ha`, `2hr`, `2hh`, `2hl`, `2hmo`), otherwise the
GMod hold type mapped through `HOLDTYPE_TRANSLATOR`.

That translator matters: the tree only has `normal / fist / pistol / smg /
shotgun / ar2 / melee / grenade`. Without mapping, physguns, tools, crowbars
and the keys SWEP found no branch and fell back to HL2 animations — "everything
that isn't a gun is broken".

`passive → normal` deliberately differs from Phoenix (they used `smg`), because
`passive` is what Helix's keys SWEP uses and hands-at-sides is the right read.

**Missing sequences:** roughly 15–20 names in the tree don't exist in the model
(`2hrpassive`, `2hr_walk`, `2hr_run`, all `sprint_*`). `TranslateActivity`
falls back through the other variants for that activity, then the `normal`
tree, before giving up.

### Gestures — `Schema:DoAnimationEvent`

Attack / reload / jump play as a **gesture layered over the pose** (slot 6),
using the weapon's own `SWEP.AttackAnim`, `AttackAnimIS`, `ReloadAnim` — 123
weapons declare these.

Two traps here, both hit during development:

- The hook receives **`PLAYERANIMEVENT_*`** constants, **not** the `PLAYER_*`
  ones passed to `SetAnimation`. Checking `PLAYER_ATTACK1` never matches.
- On a missing sequence, **only attacks** return `ACT_INVALID` (suppressing the
  melee swing the engine would otherwise pick). Reload and jump must fall
  through — returning `ACT_INVALID` there cancels the animation entirely, which
  is why third-person reloads showed nothing.

It must also **never fall through to Helix** on an advanced model — see
`04-melee.md`.

## Body rendering — `schema/libs/cl_bodyparts.lua`

`animations.mdl` has **no visible mesh**. It's a skeleton and sequences only —
wear it and you're a floating gun. That's deliberate on Phoenix's part:

```lua
RACE.animationModel = "models/phoenix/humans/animations.mdl"
RACE.hideBody       = true
RACE.defaultModels  = { male = ".../male/defaultbody.mdl", ... }
RACE.heads / hairs / beards / skins / faceSkins = ...
```

The visible character is **composed at render time** from separate meshes
bone-merged onto that skeleton — which is also how armour replaces body parts
(`ITEM.bodyType`, `ITEM.takesBody`) without a model per combination.

Current implementation is the first piece: body + head as clientside models
with `EF_BONEMERGE`, rebuilt on a 0.5s poll (model changes arrive as a
networked var with no dedicated client event). Hardcoded to the human male set
until races exist.

**Anything wearing this skeleton needs it, not just players.** A dead player is
a `prop_ragdoll` wearing `animations.mdl` — so it inherits the skeleton, the
physics and the death pose, and draws nothing at all. That is why no corpse had
ever appeared on this server, Helix's own death ragdoll included, and it read
for two rounds as a fault in the dismemberment.

`ix.fallout.BuildParts(entity, character)` is `BuildBody` with the player taken
out of it, so `libs/cl_corpse.lua` can compose a body onto a corpse with the
same call. A `character` of nil answers with the default body rather than an
empty list — a body whose owner logged off is still a body.

**`EF_BONEMERGE` is only half the contract.** It merges the *skeleton*, so the
mesh follows the animation — it does **not** make the parent's bone *setup*
drive the child, which is what `EF_PARENT_ANIMATES` is for, and a bone
manipulation is part of a bone setup. Phoenix use

```lua
mdlEnt:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL,
    EF_PARENT_ANIMATES))
mdlEnt:Spawn()
```

on every mesh, for players and ragdolls alike (`plugins/armorv2/cl_plugin.lua`),
and this schema used the first flag alone. That single omission is why a
dismembered limb stayed visible: the bones were scaled on the corpse and the
meshes drawn on it never heard about it. Scaling each mesh separately instead
applies a *second* collapse in its own space and throws the geometry off into
the air — so the bones are scaled on the body and nowhere else.

## Proportions — `schema/sv_hooks.lua`

```lua
scale      = 0.85
hull       = { normal = Vector(16,16,72), ducked = Vector(16,16,48) }
viewOffset = { normal = Vector(0,0,66),   ducked = Vector(0,0,40) }
```

Without these the model doesn't line up with the collision hull and reads as
floating. Applied on spawn, loadout and model change. Hardcoded to human;
belongs in race data once races exist.

## Applying the model to a character

`FACTION.models` only affects **newly created** characters — the model is a
stored character var (`field = "model"`). For an existing character:

```
say /charsetmodel <name> models/phoenix/humans/animations.mdl
```

**`FACTION.models` must be an ARRAY.** Phoenix wrote keyed tables
(`["models/..."] = true`); Helix iterates with `pairs` and precaches the
**value**, so `true` silently breaks character creation. This bites on every
faction ported from their data.

## Weapon raise keybind

Helix binds raise/lower to **`IN_RELOAD`** (`sv_hooks.lua:115`), held for
`weaponRaiseTime`. That collides with reloading and disturbed melee mid-swing.

Rebound to **F**:
- `Schema:KeyPress` swallows `IN_RELOAD` (only reload — `IN_USE` still works)
- `Schema:PlayerBindPress` (client) catches the `impulse 100` bind and networks
  `ixFalloutToggleRaise`
- `Schema:PlayerSwitchFlashlight` returns false so F doesn't light a torch

**Do not use `PlayerSwitchFlashlight` to drive this.** GMod only fires it if
the player is permitted a flashlight and Helix never calls `AllowFlashlight`,
so it silently never runs.

Fallback command: `bind f fo_toggleraise`.

Phoenix's own binding is unrecoverable — it would have lived in NutScript's
server-only `sv_hooks`.

---

## Every hold-type tree needs `jump` and `land`

`ix.anim.falloutHuman.fist` had neither, and `ix_hands` is hold type `fist`.
Jumping with the hands out asked `Schema:TranslateActivity` for `jump`, found
nothing, returned nil, and fell through to Helix's HL2MP translation — which
the New Vegas model answers with sequence 0, the reference pose. That was "the
T-pose only when jumping with hands out". The gun trees (`pistol`, `shotgun`,
`smg`, `ar2`) had the same hole and were spared only because Longsword weapons
carry an `NVHoldType` and index the New Vegas trees instead.

Every human tree carries both keys now, and `TranslateActivity` borrows the
`normal` tree's entry for any key a tree still lacks, so the worst case is the
unarmed pose rather than a T-pose. Names are checked against the file — there
is no `h2h_walk` and no `*_jumpend` on this model, only `h2haim_walk` and
`*_jumpland`:

```bash
python _docs/tools/mdlseq.py --act models/phoenix/humans/animations.mdl jump
```

prints each matching sequence with the activity it carries and its frame
count. Only `mtjumpstart` (`ACT_MP_JUMP`) and a handful of idles carry one at
all; the rest round-trip through `TranslateActivity` as `-1`, which leaves the
sequence it set by name in place.

---

## Which animation class fits a model is a question about the FILE

An animation class is a table of **sequence names**, and Helix plays them by
name. Point a model at a class whose names it does not have and it falls back to
sequence 0 — which in these packs is the reference pose. That is the T-pose, and
the spasm is it flicking between a name that exists and one that does not.

`libs/sh_animfallback.lua` originally guessed from what the creature *is*: a
behemoth is a super mutant, both models ship in the same pack, so point
`supermutant.mdl` at `behemoth`. That is a story about Fallout, not about the
file, and it was **20% present** — four sequences in five resolved to nothing.

`_docs/tools/mdlseq.py` answers it properly. It parses `mstudioseqdesc_t` out of
the .mdl, follows `$includemodel`, and scores every class:

```bash
python _docs/tools/mdlseq.py --match
python _docs/tools/mdlseq.py models/fallout/supermutant.mdl
```

| model | was | is |
|---|---|---|
| `models/fallout/supermutant.mdl` | behemoth 20% | **supermutant 73%** |
| `models/roadkill_fallout/robots/securitron.mdl` | robobrain 6% | **securitron 77%** |
| `models/fallout_4/actors/powerarmor/powerarmorframe.mdl` | none | **f4pa 46%** |
| `models/fallout/dogvicious.mdl` | dog 31% | dog 31% (unchanged) |

**27–31% is what a correct creature registration scores** — the tables carry
entries for weapon types these models never hold — so read the numbers against
each other, not against 100%.

Three things this turned up:

- **`$includemodel` matters.** `supermutant.mdl` holds exactly one sequence
  (`ragdoll`); its 97 real ones live in `supermutant_animations.mdl`. Reading
  only the file the race names says the model has no animations at all.
- **The sets were already in the schema.** `supermutant`, `securitron` and
  `f4pa` are three of the four classes in `libs/sh_anims.lua`, written out in
  full and registered against nothing. Phoenix have the same tables and no
  `setModelClass` for them either — theirs is presumably in a server-only file,
  which is the half of their codebase no scrape contains.
- One line covers `supermutant`, `nightkin` and `frankhorrigan`, which all
  share the model.

`dogvicious.mdl` is the one inference left and it is a safe one: its sequence
table is *identical* to `dogskin.mdl`, which Phoenix register to `dog` — 51
names, no difference either way.

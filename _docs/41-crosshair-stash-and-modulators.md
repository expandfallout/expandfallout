# Crosshair, hit markers, the stash, trade-up and modulators

Five things that arrived in one batch. They share nothing mechanically, so this
is five short sections rather than one system.

| | Phoenix's | Ours |
| --- | --- | --- |
| Crosshair | `adv_crosshair` | `libs/sh_crosshair.lua`, `cl_crosshair.lua`, `derma/cl_crosshairconfig.lua` |
| Hit marker | inside their weapon base | `libs/sv_hitmarker.lua`, drawn by `cl_crosshair.lua` |
| Stash | `stash` plugin | `libs/sh_stash.lua`, `sv_stash.lua`, `entities/entities/ix_stash.lua` |
| Trade up | a bench type | bench **mode** `tradeup`; `libs/sh_tradeup.lua`, `sv_tradeup.lua`, `derma/cl_tradeup.lua` |
| Modulators | `modulators` plugin | bench **mode** `modulate`; `libs/sh_modulator.lua`, `sv_modulator.lua`, `derma/cl_modulate.lua`, `items/modulator/` |

---

## The crosshair

`/crosshair` (or `fo_crosshair`) opens the editor: a live preview on the left,
every setting on the right, and no Save button — a change applies as it is made
and is written to `data/falloutrp/crosshair.json` on the player's own machine.
It is a **preference**, not character state, so it follows somebody between
characters.

**It replaces every other crosshair.** `CHudCrosshair` is hidden through
`HUDShouldDraw`, and every registered weapon's `SWEP.DrawCrosshair` is turned
off — that is a field on the weapon table with no hook behind it, so the only
way to suppress it is to write to the table. The original values are
**remembered** and put back if the crosshair is switched off, so nothing is
left quietly modified for the rest of the session.

**One table drives all three halves.** `ix.crosshair.settings` in
`sh_crosshair.lua` holds nineteen entries — key, display name, kind, default,
bounds, and the note shown under it. The drawing reads it, the editor is
*built* from it, and the file is validated against it by `ix.crosshair.Clean`,
so a new setting is one entry rather than three edits, and a hand-edited JSON
file cannot put a string where a number belongs.

Three shapes (cross, circle, dot), an optional centre dot on top of either of
the first two, a T shape that drops the top arm, an outline, a gap that **opens
with the weapon's spread** (read off the longsword base's `LastSpread`, which is
what Phoenix do), an aim-follow that traces where the shot would actually land,
a hide-when-lowered, and an **only with a weapon**.

**It shows everywhere by default, including empty-handed.** The first version
had `hideLowered` on, and empty hands are never *raised* — `IsWepRaised` is
false for `ix_hands` — so the crosshair vanished the moment you were not holding
a drawn weapon. Both of the settings that can hide it are now off by default,
and `hideLowered` is only asked about an actual weapon: hands and keys are
weapon entities as far as the engine is concerned, so "is holding a weapon"
means something not in `ix.armor.validStealthWeapons`, which is the same
question stealth asks.

The editor's slider is drawn rather than a `DNumSlider`: Derma's is grey-on-grey
and would be the only control in the schema that is not terminal green.

## Hit markers

Four diagonal ticks that fade, and **no sound** — that was asked for explicitly
and is also what Phoenix's does.

The longsword base already sends `longsword_hitmarker` when a **bullet** lands
on a player, an NPC or a nextbot. This schema also sends its own `ixHitMarker`
from `PostEntityTakeDamage`, so a pickaxe, a knife, a melee weapon and a grenade
mark as well. The client listens for both; the first to arrive wins, and a gun
firing marks once.

`PostEntityTakeDamage` rather than `EntityTakeDamage`, because the second runs
*before* the damage lands and is where the rest of the schema scales it — a
marker sent from there would flash for a hit that armour or a hook then
cancelled.

---

## The stash

A box you press E on that opens **your own** storage. Every stash on the map
opens the same one, two people at the same box open two different ones, and
deleting a box takes nobody's things with it: the inventory id lives in
character data, not on the record.

**It is a point, not a deployable.** Placed with the `fo_point` tool, saved by
`sv_points.lua`, listed by `/points` and removed by `/pointdelete` — the same as
a cap stash, because it is the same kind of thing. Size is `stashWidth` ×
`stashHeight` in the dev terminal (6×6, Phoenix's), and raising it enlarges every
existing stash the next time it is opened. Lowering it **hides** anything already
outside the new grid rather than deleting it; put the number back and the items
are still there.

**The model needed installing.** Phoenix's
`models/galang/fallout/furniture/stashboxcontainer.mdl` lives in
`phoenix_contributor_content` (workshop **3504308895**), which was not mounted
here — it is junctioned now like every other content pack, so the server has it.
**It is on this machine only until 3504308895 is added to the collection**
(`02-server-setup.md`); a client without it sees an ERROR box that opens and
works perfectly, which is exactly the kind of fault nobody notices until a
screenshot. `models/roadkill/fallout/containers/footlocker.mdl` is the fallback
if that pack is ever dropped — anything typed into the point tool's model field
overrides the default for that one box.

**The storage context is torn down before every open.** Helix keeps one context
per inventory and reuses it, remembering the entity it was opened at — so a
stash opened in one town and walked away from would leave later opens waiting on
a `DoStaredAction` against a box on the other side of the map. A context whose
receiver never sent `ixStorageClose` also counts as *in use*, which on a shared
container is a nuisance and on your own box is a lockout. Both are one line, and
it is only safe here because a stash has exactly one legal user.

---

## Trade up

Five weapons of the same kind **and** the same quality make one of the same kind
one tier better, straight into your pockets.

It is a **bench mode**, so it is placed, gated, moved and deleted by the same
commands as every other bench — see `30-benches.md`. What is different is the
window: `ix.bench.modes` entries may name a `panel`, and `cl_bench.lua` opens
that instead of the recipe list. `ix.bench.Validate` skips the "a bench with no
recipes does nothing" rule for those modes, because their list is whatever the
person standing there is carrying.

| Config | Default | |
| --- | --- | --- |
| `tradeupAmount` | 5 | how many go in |
| `tradeupMaxRarity` | `legendary` | the best it will ever produce |

**The ceiling is the point.** Master Craft and Pearlescent are 1% and 0.1% at
fifty Luck; letting a bench reach them would make the top of the curve a matter
of grinding rather than of building for Luck. Both live on the RARITY page of
the dev terminal, next to the curve they are a statement about.

Equipped weapons are never consumed — the bench cannot know which rifle you were
relying on. The new weapon is created **before** the five are removed, so a
failure cannot cost somebody four rifles; the cost of that ordering is that you
need a free slot for a moment.

---

## Modulators

Eight permanent upgrades fitted to a suit of **body** armour: one per SPECIAL at
+3, and one worth +15% radiation resistance. One of each kind per suit, never a
helmet or a plate, and the modulator is spent when it is fitted.

`items/modulator/` holds one file each, and the numbers live *in* those files —
`ITEM.modSpecial` keyed by the canonical attribute names, `ITEM.modFields` for
armour fields like `radResistance`. **There is no registry to keep in step:**
anything flagged `isModulator` is one, so adding a ninth is one file. The blank
`junk_modulator` is deliberately in `items/` root rather than that folder,
because everything in the folder is something the bench offers to fit.

What is fitted is stored on the **item instance** as `mods`, so it survives being
dropped, traded, stored and restarted, and two suits of the same armour carry
different modulators. `ix.armor`'s own sums add
`ix.modulator.Field` and `ix.modulator.Special` alongside the armour's own
numbers, which is what makes a fitted modulator indistinguishable from an armour
that always had the stat — the networked DR, the rad pool, the HUD's modifier
list and the damage path all read those sums and know nothing about it.

The armour's description grows a `Modulators:` section listing what is in it.
The line is **built from the numbers** rather than written beside them, which is
the failure Phoenix have: their `armorDesc` strings sit next to the bonus and two
of theirs no longer match it.

The `modulate` bench shows the suit you are wearing on the left and every kind on
the right, each row saying which of the three states it is in — fitted, in your
pockets, or none owned. There is no model preview: a modulator changes nothing
visible, so it would be a picture that never changes.

**Two things were making that window twitch**, and both are fixed:

- **`SIMPLE_USE` fires again while E is held.** Every one of those presses sent
  the window's open message, which tore the panel down and built it again
  several times a second. `ix_workbench:Use` now takes one press per second per
  player — the stash already did.
- **It rebuilt on a timer.** Both this window and the trade-up one now compare a
  one-string **signature** of everything they draw and rebuild only when it
  changes, so the row under the cursor keeps its hover and a click cannot land
  on a button that was replaced a frame earlier. Nothing on either window
  changes without the player doing something, so the check costs one walk of the
  inventory every quarter second.

Opening any bench window now closes whichever one was already open; each panel
used to remove only its own kind, so walking from a modulate bench to a chem
bench left the first one behind the second.

---

## Where the settings are

Dev terminal → **WORLD** for the stash, **RARITY** for trade up. The crosshair is
per player and has no server config at all.

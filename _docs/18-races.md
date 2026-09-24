# Races and character appearance

`schema/libs/sh_races.lua`, `schema/races/*.lua`,
`schema/fallout_ui/cl_customizer.lua`, `schema/libs/cl_bodyparts.lua`.

Diagnostics: `fo_races_report`, `fo_create_report`.

---

## Why races exist separately from factions

Helix has factions, and a faction carries a list of whole player models. That is
the wrong shape here: Fallout characters are **composed** at render time from a
meshless animation skeleton plus separate body, head, hair and beard meshes,
because that is what lets armour replace body parts without needing a model per
combination.

A faction says which side you are on; a race says what you are made of. A
Wastelander and an NCR Trooper are both `human`.

---

## The library

`ix.races` is Phoenix's `nut.races` in Helix form. Their accessors are all
`nut.races:getX(char)` — a mix of "look this up for a race" and "look this up
for a character". Ours splits those: `ix.races.GetHairs(class, gender)` takes
the pieces, `ix.races.GetCharacterRace(character)` resolves a character.

Races load from `schema/races/` with a `RACE` global, mirroring
`ix.attributes.LoadFromDir`. The **filename is not the key** — `RACE.class` is,
because race classes are named from faction and item data and must survive a
file rename.

Helix auto-loads `attributes/`, `factions/`, `classes/` and `items/` but knows
nothing about races, so `sh_schema.lua` loads the directory explicitly. That is
safe because `core/libs/sh_plugin.lua` runs `IncludeDir("libs")` first and
`sh_schema.lua` last, so `ix.races` exists by then.

---

## Content availability is enforced at load

Every model path is checked with `file.Exists(path, "GAME")` when the race
registers, and dropped if missing. The customiser is built from what survives,
so it can never offer an option that renders as an error model — the beard
picker simply does not appear rather than showing fourteen broken entries.

`fo_races_report` prints what was dropped, grouped by category. This matters
because a silently shortened list is indistinguishable from a race that never
had those options.

**Current state for `human`** — 39 of 53 declared models present:

| | |
|---|---|
| bodies, male + female | installed (`af_content_pack_1`) |
| heads, both genders incl. ghoul | installed |
| hairs, 10 male + 22 female | installed |
| **beards, 14 male** | **not installed** |
| **faceSkins, 112 materials** | **not installed** |

`phoenix_anims` ships only `animations.mdl` — five files, no face pack. The
unavailable entries are left **declared** in `sh_human.lua` rather than deleted:
the filter drops them at load, so adding the content later needs a restart and
no code change, and the declaration is the record of what the race should have.

`RACE.startingGear` is deliberately not ported — Phoenix's list names items like
`armorv2_wasteland_wanderer` that do not exist in this schema, and handing a
spawn hook item IDs that resolve to nothing is a runtime error.

---

## Appearance vars need `OnValidate`, and not for safety

Six character vars carry appearance: `race`, `gender`, `ethnicity`, `hair`,
`beard`, `hairColor`. All are `bNoDisplay`, because the customiser sets them
rather than Helix's generic character-var UI (which would render a raw text box
for each).

That combination is a trap. Helix strips undisplayed vars out of a creation
payload unless they validate:

```lua
for k, _ in pairs(payload) do
    local info = ix.char.vars[k]
    if (!info or (!info.OnValidate and info.bNoDisplay)) then
        payload[k] = nil
    end
end
                      -- core/libs/sh_character.lua, ixCharacterCreate
```

Without an `OnValidate` every one of these is **discarded at creation with no
error**. Every new character would come out as the default appearance and the
customiser would look broken for no visible reason.

The return value also *replaces* the payload entry, so these coerce as well as
check — an out-of-range index becomes a valid one rather than a rejection the
player cannot act on. Validation runs in registration order
(`SortedPairsByMemberValue(ix.char.vars, "index")`), which is why `race` is
registered first: everything else validates against it.

Indices are clamped rather than rejected because the lists are filtered for
missing content — a perfectly reasonable hair index can point past the end on a
server whose content differs from the one the player last joined.

---

## The race sets the player model, and nothing did until it was reported

**Every faction's `FACTION.models` is the human animation carrier**, because
that is what `genfactions.py` writes for all 45. So Helix hands every character
`models/phoenix/humans/animations.mdl` at spawn whatever race they are, and
nothing anywhere set it from the race.

For a human that is correct and everything worked. For a super mutant it is not:
`cl_bodyparts.lua` only bone-merges a body onto a player whose model is *their
own* race's carrier, a super mutant's is `models/fallout/supermutant.mdl`, so
the test failed, no parts were built, and there was nothing to see at all.

`/charsetrace` respawns and its comment says the hull and view offset are
"applied on spawn" — which was true of `ApplyProportions` in `sv_hooks.lua`, and
true only for humans. That function was hardcoded to `HUMAN.scale`,
`HUMAN.hull` and `HUMAN.viewOffset` with a `local ANIMATION_MODEL` it bailed out
on. It is now race-driven, in Phoenix's own order — model, scale, view offset,
hull.

Three things it does that are worth knowing:

- **it corrects the character's own `model` var, not just the entity.** That var
  is what Helix re-applies on every spawn, what the character select screen
  previews, and what goes to the database. Fixing only the entity would hold
  until the next respawn. It is also what repairs a character created before
  this existed — on their next spawn, with no command to run.
- **an armour override is not persisted.** `ITEM.replaceAnimModel` (the Power
  Armour frame) is applied to the entity only, because it has to come off again.
- **base health is not here.** `characterMeta:ApplyBodyState` in
  `sv_radiation.lua` already owns it, and two places setting max health is how a
  race change silently reverts.

`RACE.jumpBoost` was also read by nothing — +70 on a super mutant. It is now
added in `ix.special.Apply`, which is the one function that sets jump power, for
the same reason speed boosts live there: it re-runs on every spawn and every
attribute change, so anything applied elsewhere is wiped the next time a point
is spent.

**Race animation models are precached at registration.** Helix precaches
`FACTION.models`, which means the model a super mutant actually wears was one
nothing had told the engine about — and the stall would happen the first time
somebody picked the race, not at load.

---

## Body composition

`ix.fallout.GetBodyParts(character)` returns
`{model = path, skin = index, hair = true}` entries, and `cl_bodyparts.lua`
bone-merges each onto the animation skeleton. Ethnicity is a **skin index on the
shared body mesh**, not a separate model, which is why five ethnicities need one
body file. Hair and beard meshes are untinted and coloured at render time, so
one model serves every hair colour.

Rebuilds are driven by a **signature** — race/gender/ethnicity/hair/beard/colour
joined into a string. Appearance can change without the model changing (the
model is the same animation skeleton for every human), so there is nothing on
the entity to compare against; the signature is what makes "did anything
change?" answerable at all.

---

## The customiser

A step inside Helix's creation flow, not a popup. Phoenix's is a separate panel
reached from the faction screen, but that flow owns the payload and the
validation, and a popup writing into it from outside would have to reimplement
both.

Pickers are `ixFOCycler` — `< LABEL   value >`. Phoenix uses a single button
whose text advances on click; with 22 female hairstyles that means 21 clicks to
get back to the one you passed, so these have arrows and wrap.

The preview composes from the **payload**, not a character — there is no
character until creation finishes. `ix.fallout.SetPreviewModel` takes an
`ixPartsSource` callback for exactly this.

Gender and race changes **rebuild** the whole column rather than reconcile it:
both change what the other pickers may offer (a female character has 22
hairstyles and no beards; a male has 10 and 14), and hair/beard indices are
per-gender so they reset rather than carry across.

Hair colour is a full `DColorMixer`. The picker only appears when there is hair
or a beard to tint.

### Three fixes after the first playthrough

**SPECIAL order: `SetZPos` does not reorder these rows.** Setting the
z-position is the obvious move and it did nothing — the rows stayed
alphabetical whatever z they were given. They are re-parented instead:
re-parenting a panel appends it to the end of its parent's child list, so
re-adding them in the wanted order leaves the child list in that order, and
docking follows the child list. The points-remaining bar goes back first so it
stays on top.

**The faction step could be a dead end.** Its proceed button is Helix's own,
found by searching the model container's children — and when that search comes
back empty there is no way forward from the screen at all. It is now created if
it was not found, and `fo_create_report` prints `faction proceed` either way, so
"there is no continue button" is never a guess again.

**Hair colour is a full picker.** `DColorMixer` with the palette and alpha bar
turned off — alpha is meaningless on a tint multiplied into the model, and the
swatch palette only duplicates what the wheel already covers. It writes the same
`"r g b 255"` string the fixed list did, so nothing downstream changed.

`ValueChanged` fires continuously while the cursor is dragged, and each event
would recompose four model panels. It refreshes on a change of VALUE instead, so
dragging costs one rebuild per actual colour rather than one per frame.

### Step order

```
faction  ->  appearance  ->  description  ->  attributes
```

Appearance comes second because it is what you decide first: who the character
looks like, then what they are called, then what they are good at. It also means
every later screen already shows the body you chose.

Navigation lives entirely in `RouteAppearanceStep`, not split between there and
the button definitions. Where only the DESTINATION changes, the handler is
rebuilt rather than wrapped — wrapping would run Helix's navigation and then
immediately navigate somewhere else, animating the slide twice. Each rebuilt
handler reproduces Helix's own body with the target changed, and quotes the
original in a comment so the copy can be checked.

Three things that are easy to miss:

**The one-faction skip has to follow the reorder.** Helix jumps straight past
the faction step when only one faction is whitelisted, and it jumped *to
description*. Left alone, a one-faction server would never see the appearance
step at all.

**The back button delegates without decrementing.** Helix's faction-step return
already decrements the progress bar, so decrementing before calling it takes the
bar back two steps for one click.

**The progress segment is inserted, not appended.** `AddSegment` only appends,
which would label the bar faction/description/skills/appearance for a flow that
runs faction/appearance/description/skills. Its index depends on whether the
faction segment exists at all, since Helix only adds that one when there is more
than one faction.

### Every preview is driven by the customiser

`AddPreview` registers a model panel, and all four are registered — the
appearance step's own plus faction, description and attributes. They share one
`ixPartsSource` that reads the payload when called rather than taking a
snapshot, so a panel registered before any choice is made is still correct
afterwards.

Without this, choosing **female** would change the appearance step's preview and
leave a male body on every later screen.

### Hair colour: two different mechanisms

The same tint has to be applied two ways, because the parts are drawn two ways.

**In the menu preview** the parts are drawn by hand inside the model panel's
`DrawModel`, and `ixModelPanel:DrawModel` — which runs immediately before —
ends with `render.SetColorModulation(1, 1, 1)`. An entity colour set on the part
is never consulted, so every hair colour rendered identically. The preview uses
`render.SetColorModulation` around each tinted part instead, resetting after so
the tint does not bleed onto whatever draws next.

**In the world** the parts go through the engine's render path, so `SetColor`
is the right call — but only once the part has `RENDERMODE_TRANSCOLOR`, since
the default render mode does not consult the entity colour.

**In the world** the parts are engine-drawn and bone-merged onto the player, so
the tint goes in `Entity.RenderOverride`. The engine calls that in place of the
entity's normal render, so `DrawModel` inside it draws the mesh once and nothing
re-enters.

`SetColor` is not enough there — it clamps at 255 and so cannot express the 5x
male boost at all.

**Do not reach for `PostPlayerDraw`.** It looks like the natural place, and it
recurses: these parts are PARENTED to the player, so calling `DrawModel` on one
from inside the player's draw re-enters the player render path, fires
`PostPlayerDraw` again, and repeats until GMod cuts it off with

```
PostPlayerDraw: We are 10 layers deep, runaway infinite loop?
```

### What the hair textures actually are

Measured from the VTF headers' `reflectivity` field, which is the texture's
average colour baked in at compile time:

| | reflectivity |
|---|---|
| male, own textures | 0.047 – 0.080 |
| female `fairytails` (shared by 5 other styles) | **0.016** |
| female `the_sophisticate` | **0.259** |

All neutral grey, none pre-tinted — but a **sixteen-fold brightness spread**.
Colour modulation multiplies, so the same tint lands very differently depending
on the style, and on the darkest textures a light shade cannot come out light at
all: there is nothing to multiply up from.

`render.SetColorModulation` accepts values above unity, which is what makes
compensating possible at all.

`RACE.hairBoost` carries a value per gender — `male = 5.0`, `female = 1.0` for
humans, measured by eye against the real assets. It lives with the race because
it describes the ASSETS: a race shipping different hair models needs its own
value, and nothing in the interface can work it out on its own.

`fo_hair_boost` remains a global multiplier on top, defaulting to `1.0`, for
tuning without editing race data.

Both renderers apply it, and they have to do it differently:

- **The menu preview** draws its parts by hand, so it multiplies through
  `render.SetColorModulation`.
- **The in-world body** uses `Entity.RenderOverride` — see below.

Two things ruled out along the way, both worth not re-checking:

- **The materials are not the difference.** Every hair VMT is a plain
  `VertexlitGeneric` with `$alphatest 1` and no `$color`/`$color2`. Several
  styles share one texture — male `punked`, `terrorsaur` and `warhawk` all point
  at female `fairytails`.
- **The models are not the difference.** Male and female hair models are
  structurally identical: 8 skinrefs, 1 skin family, 1 bodypart, 1 model each.
  They all carry head/eye/teeth/mouth materials alongside the hair, left over
  from being exported out of head+hair scenes, but nothing extra is drawn.

Phoenix's `SetModelColor` is not a lead either — it stores a `.Color` field on
the part that their own draw loop never reads.

### The progress bar

Rebuilt as discrete cells rather than one continuous fill: completed steps in
the dimmer accent, the current step bright, upcoming steps empty, with the label
inverting to the background colour on a filled cell. Helix's version showed how
far along you were but not which steps were behind you.

`GetProgress` (integer step) decides each cell's state; `GetFraction` (animated)
clips the leading edge, so the fill still slides between steps rather than
snapping.

The segment list is rebuilt from the flow rather than accumulated with
`AddSegment`, which fixes two things at once: **faction now always appears**,
where Helix omitted it whenever only one faction was whitelisted, and appearance
lands second instead of last. Attributes is still conditional, because Helix
skips that step entirely when nothing registered any attributes and a segment
for an unreachable step would be worse than none.

**Progress is derived from the active subpanel, not from counting clicks.**
Increment/Decrement cannot survive this flow — the one-faction skip jumps a step
without incrementing, the appearance return delegates to a handler that
decrements on its own, and Helix's description proceed can skip attributes
entirely. Each of those leaves the bar off by one. `SetActiveSubpanel` calls
`OnSetActive` last, after the buttons have finished incrementing, so a sync
there runs afterwards and wins.

### Splicing a step into Helix's flow

Three things that are not obvious:

**`AddSubpanel` only appends**, and the array order is what the slide animation
traverses. Left as added, moving from description to appearance would visibly
sweep *past* the attributes step and back. The array is reordered and
`SetupSubpanelReferences()` rebuilds the left/right chain from it.

**Clear the subpanel links before reordering** - see the cycle below, which hung the client outright.

**The two buttons crossing the seam are wrapped, not replaced.**
`descriptionProceed` runs `VerifyProgression("description")` and refuses to
advance on a bad name. The wrapper diverts to appearance *only if Helix actually
advanced* — diverting unconditionally would step straight past the validation
error the player needs to see.

**The progress bar is rebuilt from the flow**, not appended to — see above.

Entry is hooked on `step.OnSetActive` rather than at each call site, since every
route in — forward from description, back from attributes — goes through it.
---

## Client freeze after races landed — what was found

Symptom: the client stops responding shortly after clicking **Create**, and the
server logs `"<player> timed out"` with no Lua error of its own. **Client Lua
errors never reach the server console**, so `garrysmod/console.log` on the
server cannot diagnose this — it only shows the timeout.

The `[ERROR] stack overflow` in that log is a **red herring**: it is dated
09/03 17:07 and comes from an older `ix.special.Apply` that called `SetAttrib`,
which fires `CharacterAttributeUpdated`, which called `Apply` again. Today's
`Apply` only sets walk/run speed. Check the timestamp before chasing it.

Two genuine defects were found by reading, both introduced with races:

### `SetSkin` was not bounds-checked

Ethnicity is a skin index 0-4 on the shared **body** mesh. The composer applied
that same index to the **head** as well — but Phoenix varies the head by
ethnicity through facemap submaterials (`RACE.faceSkins`), not through skins, so
a head model may carry exactly one skin.

`SetSkin` past the end of a model's skin family is not a no-op in the engine; it
is a known route to corrupt rendering and, on some models, a client crash.
`ix.fallout.ApplyPartSkin` now checks `SkinCount()` first, and both composers go
through it.

### The composer ran twice per refresh

`ComposeModelPanel` overrides a panel's `SetModel` to route into
`ix.fallout.SetPreviewModel` — and that function calls `SetModel` itself. Its
re-entry guard was set by the *override*, so entering through the front door
(`Refresh`, which calls the composer directly) left the flag clear and ran the
entire body twice, building two of every part.

The guard now lives in `SetPreviewModel`, saved and restored around the whole
call, so it holds no matter which door is used.

### `Bad sequence (4 out of 0 max) ... for model 'error.mdl'` is stock Helix

Not a fault, and not ours. `ixCharMenuNew:Init` sets `models/error.mdl` as the
initial faction model, and `ixModelPanel:SetModel` ends with a hardcoded
fallback when it can find no idle sequence:

```lua
if (!found) then
    entity:ResetSequence(4)
end
```

`error.mdl` has zero sequences, so index 4 is out of range and the engine says
so. It appears once per model panel pointed at `error.mdl` — three in the
creation flow, plus the character select preview.

### The console buffer dies with the crash

The client's `console.log` ends at whatever had already been flushed, so a hard
crash on clicking Create leaves **no record of the crash in it**. That is why the
log looked clean and stopped at startup.

`ix.fallout.CreateTrace` writes breadcrumbs to
`garrysmod/data/fo_create_trace.txt` with `file.Write`, which commits
immediately. After a crash the last line is the last step that completed.
`fo_create_trace 0` turns it off; `fo_create_trace_clear` empties it.

### Localising it in one run

`fo_create_appearance 0` builds the creation flow exactly as it was before races
— no fourth subpanel, no customiser, no composed preview. Read at panel
construction, so reopen the character menu after setting it.

If the crash survives with it off, it is not in the appearance step.

### The trace localised it: inside Helix's own `Populate`

First run produced:

```
12.009  Init: start
12.009  compose: patched ixModelPanel   x3
12.009  appearance: entered
12.009  compose: patched ixModelPanel   x1
12.009  appearance: preview attached
12.009  Init: appearance step built
12.009  Init: routed
```

Init completes; nothing after it. That is sharper than it looks, because
`ix.fallout.WrapPanel` runs **Helix's original first and ours second** — so a
trace line in a wrap only prints once the wrapped function has already
succeeded. `Populate: start` never printing means Helix's `Populate` did not
return, not that it was never called.

`WrapBefore` exists in `cl_creation.lua` for exactly this: tracing needs to
happen on the way IN. It is used only for the Populate trace; the ordinary
`Wrap` remains the default for everything else, for the reason in
`cl_panels.lua`'s header.

The heaviest new work inside Populate is Helix's `model` payload hook calling
`SetModel` on three model panels, which `ComposeModelPanel` intercepts into a
bone-merge. Hence the separate switch.

### The actual cause: a cycle in the subpanel chain

It was never a crash. The client **hung**, and the server reported a timeout —
which reads like a crash and is why this took several passes.

`SetupSubpanelReferences` only ever SETS left/right links, never clears them,
and its guard means the LAST panel's `right` is left exactly as it was:

```lua
if (IsValid(nextPanel)) then
    panel:SetRightPanel(nextPanel)
end
```

So `AddSubpanel` ordered them `[faction, description, attributes, appearance]`
and set `attributes.right = appearance`. Reordering to
`[faction, description, appearance, attributes]` then set
`appearance.right = attributes` — and `attributes.right` still pointed at
appearance. **A cycle.**

`SetSubpanelPos` walks that chain with `while (IsValid(currentPanel))` and never
terminates. The fix is to clear every link before rebuilding.

Why it was hard to see:

- No Lua error, because an infinite loop is not an error.
- No console output, because the buffer dies with the process.
- Nothing traced, because the hang happens in the create button's
  `SetActiveSubpanel` — which Helix calls **before** `SlideUp`, and therefore
  before `Populate` and every trace point that had been placed.

```lua
self:Dim()
parent.newCharacterPanel:SetActiveSubpanel("faction", 0)   -- hangs here
parent.newCharacterPanel:SlideUp()
```

The empty trace file was the decisive clue: `fo_create_trace_clear` had written
it at 10:28:32, proving the tracer worked, and nothing followed — so the hang
was upstream of every trace point, not in `Populate` as the first trace had
suggested.

`fo_create_report` now walks the chain with a hard bound and prints
`CYCLE back to 'x'` or `BROKEN - n of m reachable`. A cycle there is an infinite
loop inside a mouse click, so it is worth checking every time.

### The switches

| Convar | |
|---|---|
| `fo_create_appearance 0` | drop the whole appearance subpanel |
| `fo_create_compose 0` | keep the flow, stop composing bodies on creation panels |
| `fo_create_trace 0` | stop writing breadcrumbs |
| `fo_create_trace_clear` | empty the file before a run |

Turn them off one at a time; whichever makes the crash stop names the culprit.

### The trace file is on the CLIENT

`garrysmod/data/fo_create_trace.txt` inside the **client's** GMod install, not
the server's. `file.Write` always writes to the writing realm's `data/`, and
this tracer is clientside.

### Getting the client's side

Add `-condebug` to Garry's Mod's Steam launch options. The client then writes
its own `garrysmod/console.log` inside the **client's** GMod folder, and it
survives the crash — which is the only way to see a clientside error or the last
thing that ran before a freeze.

---

## Height, weight and age

`schema/libs/sh_biography.lua`.

Forced into the description in a fixed format:

```
6ft 5in | 120lbs | 18 | A wastelander that is awesome!
```

They are stored **both** ways: as three separate character vars, and composed
into the description string. The description is what a player reads; the
separate vars are what code reads — they are going on the HUD when you look at
someone, and parsing them back out of a free-text field would break the first
time somebody types a pipe.

### The fields

Height is entered as **feet and inches** — two boxes side by side — and stored
as a single inch count. Storage wants one number, which is far easier to clamp
and compare; nobody gives their height in inches, so that is a storage detail
and not what the field should ask for.

Feet alone is a complete answer (`6ft` means 6ft 0in), so an empty inches box is
fine and an empty **feet** box is what makes the field unanswered.

**Nothing is seeded.** The boxes start empty with the valid range as a
placeholder, and `GetValue` returns nil until something is typed. A prefilled
default is a value the player never chose and will walk past without reading;
this way an unanswered field is a rejection with a message rather than a silent
default.

The unit suffix width is **measured**, not assumed. A fixed reserve was too
narrow for "inches" at 1440p, so it overran the panel and rendered as `nches` —
clipped by the container rather than by the field.

Clamping happens on **focus loss**, not per keystroke: clamping as you type makes
`18` impossible to reach from an empty box when the minimum is 18, because the
first `1` snaps straight to it.

### `L()` is not the same function on both realms

`OnValidate` runs on the server as well as the client, and server-side the
signature is `L(key, client, ...)` — a call like `L("height")` passes nil where a
player is expected. The fault also travels to the client as a **key** to be
translated there, so translating it early would be wrong even if it worked.

Hence three distinct keys (`heightRequired`, `weightRequired`, `ageRequired`)
rather than one shared message taking a field name.

### Where the forcing happens

`AdjustCreationPayload`, server-side. It is Helix's own hook for this: it runs
after every var has validated and before `ix.char.Create`, and what it writes
into `newPayload` is merged over the payload.

Composing there rather than in the description var's `OnValidate` means the
values are already validated and clamped — the description can never be built
from an age that was about to be rejected.

### Ranges

| | |
|---|---|
| `minimumAge` (config) | 18 |
| age maximum | 90 |
| height | 60–84 in (5ft–7ft) |
| weight | 100–350 lbs |

The age minimum is a **rule**, not a technical limit, so it is a config an admin
can move. It is enforced in `OnValidate` on the server, not only by the widget —
the widget clamps for convenience, but a payload can be sent by anything.

### Two traps

**`index` collides.** It decides both display order within a category and the
order validation runs in. Helix's own go up to 4, and vars registered without an
index are numbered from the table count as it grows — which already produces
duplicates (`class` and `attributes` are both 4). These sit at 20+ so the order
is defined.

**Helix already labels the field.** `cl_charcreate.lua` adds a label above every
character-var panel from `L(key):utf8upper()`, so `ixFONumberEntry` draws its own
label only when one is set, and the creation screen leaves it empty. The
language file supplies `height`/`weight`/`age` so those labels read properly.

`ixFONumberEntry` clamps on focus loss rather than per keystroke: clamping as you
type makes `18` impossible to reach from an empty box when the minimum is 18,
because the first `1` snaps straight to it.

## Spawning with the race's health

A securitron has 500 base health and spawned with 100 of it. `ApplyBodyState`
(`sv_radiation.lua`) is the one place maximum health is set — race base,
radiation tier and any HP buff, together — and nothing ran it at spawn:
Helix's `GM:PlayerLoadout` fills health to the saved value or to the
*maximum*, and on a freshly spawned player entity the maximum is the engine's
100 until something says otherwise. A `PlayerLoadout` listener now runs
`ApplyBodyState` first — `hook.Add` listeners run before the gamemode's own
method — so the ceiling is right when Helix fills to it.

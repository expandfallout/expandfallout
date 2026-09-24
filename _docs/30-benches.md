# 30 - Workbenches

Chem benches, crafting benches, processing benches. Phoenix's `workbench`
plugin rewritten for Helix, with an in-game creator and configurer.

| | |
|---|---|
| `libs/sh_bench.lua` | types, recipes, the rules, `FormatTime` |
| `libs/sv_bench.lua` | persistence, placing, the production loop, net |
| `libs/cl_bench.lua` | the synced type list, and which window to open |
| `libs/sv_benchseed.lua` | the four starter benches |
| `libs/sh_benchprops.lua` | the C-menu entries |
| `entities/entities/ix_workbench.lua` | the thing standing in the world |
| `derma/cl_bench.lua` | the window you get for pressing E |
| `derma/cl_benchconfig.lua` | `/benchconfig` |

| command | who | what |
|---|---|---|
| `/benchconfig` | admin | the creator and configurer |
| `/benchplace <id>` | admin | place one, with the deploy ghost |
| `/benchremove` | admin | remove the one you are looking at |
| `/benchlist` | admin | every kind, and how many are out |

Right-clicking a bench with the C menu open gives an admin **Configure**,
**Open** and **Remove**.

---

## A type is not a bench

Phoenix configure each **placed bench** separately: the model, the size, the
recipes and the timings all live on the entity. Two chem benches are two piles
of configuration to keep in step by hand, and their 1273-line creator wizard
exists to assemble one of them.

Here the recipes, the model, the size and the gating are a **type**, and a
bench standing in the world is a **placed record** pointing at one.

- Editing the chem bench edits every chem bench.
- Placing a second one is `/benchplace chembench`.
- There is exactly one place to look when a recipe is wrong.

Same split, and the same reason, as `sh_factionstorage.lua` makes between a
record and the entity standing on it.

**Two saves, not one.** Types are configuration; placed benches are world
state. An admin editing a recipe should not rewrite where every bench in the
world is standing. They are also read at different times — types have to exist
before a placed record can be restored against one, which is why `Load` reads
them in that order. Reading them the other way round would drop every bench in
the world on every restart.

---

## Six modes

Four that say when a recipe fires, and two whose window is not a recipe
list at all.

| mode | theirs | what it is |
|---|---|---|
| `craft` | multicraft | you pick a recipe and press Craft. Takes time. |
| `instacraftory` | — | as `craft`, but there is no storage at all: the output goes straight into your pockets and the experience is paid on the spot rather than owed. |
| `process` | singlecraft | runs any recipe it can fill from its own inventory, over and over, unattended. |
| `infinite` | infinitecraft | produces on a timer and consumes nothing. |
| `tradeup` | a bench type of theirs | five weapons of one kind and quality make one of the next, straight into your pockets. See `41-crosshair-stash-and-modulators.md`. |
| `modulate` | a bench type of theirs | fits modulators to the body armour you are wearing. Same doc. |

For the first four the difference is only **when** a recipe fires. A recipe is
the same shape in all of them, so a bench changed from one to another keeps its
recipes and means something different by them.

**The last two ignore recipes entirely.** A mode may name a `panel`, and
`cl_bench.lua` opens that window instead of the recipe list - because what is
being chosen there is not a recipe but something the person standing at the
bench is carrying. `ix.bench.Validate` skips the "a bench with no recipes does
nothing" rule for them, and leaves any recipes already on the bench alone, so
one switched to a panel mode and back is exactly where it started. A `panel`
that does not exist on the client falls back to the ordinary window rather than
to nothing.

**A processing bench's recipe list is a priority list.** A smelter that can
make both steel and lead makes whichever is higher up. Clicking a recipe sets
the one it prefers while that one can still be filled. Picking at random is a
rule nobody can use.

**An infinite bench jams rather than spills.** `ix.bench.HasRoom` is asked
*before* an automatic bench consumes anything, so a condenser with a full
output bin simply does not start — rather than putting an item on the ground
every three minutes for as long as the server is up. That is the one failure
in this system that would have been unbounded, and it is checked first.

---

## Workspace or output bin — `allowInput`

STORAGE opens Helix's own inventory window for the bench, and whether anything
may be put **in** is the type's own setting.

- **On** (the default) — a workspace you load. A **processing** bench needs
  this, since it draws materials from its own inventory.
- **Off** — an output bin. Things only come out, so it cannot be used as a
  locker that ignores every rule the faction storages enforce. The seeded
  condenser is the one that ships this way: it consumes nothing, so anything
  put in could only ever be stored.

`CanTransferItem` is the guard rather than the window: a transfer can start
from anywhere Helix allows one, and the rule has to hold whether or not the
thing enforcing it is on screen. Taking **out** is never blocked.

**The storage window and the bench window cannot be stacked against each
other**, and it took two wrong fixes to see why.

`ixStorageView` is a fullscreen `Panel` that is never a popup. Its two grids
are `SetPaintedManually(true)` and its own `Paint` draws them:

```lua
function PANEL:Paint(width, height)
    ix.util.DrawBlurAt(0, 0, width, height)
    for _, v in ipairs(self:GetChildren()) do
        v:PaintManual()
    end
end
```

So the grids take **input** at their own popup depth but are **rendered** at
the parent's — and the parent, not being a popup, is below every popup on
screen. Raising the children fixes the clicking and changes nothing about the
drawing. Raising the **parent** puts an invisible screen-sized panel over its
own children and swallows every click meant for them: the window appears and
nothing in it can be touched.

**Input depth and paint depth are not the same thing here**, which is why one
fix made it clickable-but-behind and the other made it in-front-but-dead. The
bench window steps aside instead — alpha 0 and no input while the storage view
exists, restored when it closes. Alpha rather than `SetVisible(false)`, because
a hidden panel is not guaranteed to keep thinking, and that think is what has
to notice the storage closing. The first attempt at this removed the storage window entirely and
drew the contents inline, which fixed the z-order by also removing the only way
to **load** a processing bench.

---

## Experience is owed, not paid

A finished craft stamps `benchXP` on what it made. Taking it **out** of the
bench hands that over and clears the mark, so it is paid exactly once and an
item passed around afterwards is worth nothing extra.

Paying at the moment a job finished paid somebody standing somewhere else for a
smelter they loaded an hour ago, and paid nobody at all when they had logged
off. A bench full of uncollected output is a bench holding wages rather than
one that has already paid them into the air.

`OnItemTransferred`, not `CanTransferItem` — this has to run only when the move
actually happened. The latter is asked *before*, and a transfer refused after
it (no room, most likely) would have paid for work nobody collected.

The **collector's** Luck applies, multiplied by the size of the stack. The
crafter is a character id who may have left the server a week ago; the only
person the game can ask about is the one standing here.

---

## The queue

Press CRAFT again to queue another, up to the type's `queueMax` (10 by
default).

**Materials are spent when a job is queued, not when it starts.** Charging at
the front is what makes a queue honest: you can only line up what you can
afford, and the fifth stimpak cannot quietly fail forty seconds from now
because somebody took the steel out of your pocket in the meantime.

**`parallel` is the difference between a bench and a workshop.** Off, the queue
is a line and one thing is made at a time. On, everything queued counts down at
once, so ten stimpaks take as long as one — which is a bench with no cost to
using it, so it is off by default.

A job with no `finish` is one that has not started. In a line only the front of
the queue has one; in parallel everything does the moment it is queued. That
single field is the whole difference between the two modes, which is why
neither needs a branch anywhere else.

**Cancel takes the back of the queue**, not the job that is running — that is
what somebody who queued one too many actually wants, and it means pressing it
repeatedly walks backwards through your own mistake instead of throwing away
the craft that is nearly done. The materials do not come back either way.

---

## Where the materials come from

**The bench, then your pockets, added together.**

A bench that could only see its own inventory would make every craft a
drag-items-in chore. One that could only see your pockets would make a loaded
processing bench impossible. Reaching into somebody's inventory is worth being
careful about, and this is the case where it is not surprising: they pressed
Craft on a recipe with its inputs listed in front of them.

Output goes to the bench, then the crafter, then the floor. The floor is a last
resort rather than a failure, because a finished craft that produced nothing is
worse — and a processing bench filling up while nobody is watching is exactly
the case where there is nobody to tell.

**Counted before anything is taken.** `ix.bench.Consume` asks the whole list
before it removes the first item. Half-consuming a recipe and then failing is
the one outcome worse than refusing.

Cancelling a craft does **not** return the materials. They were spent at the
start, and giving them back would make a bench a way to hold materials where
nobody can steal them for exactly as long as you like.

---

## Luck pays in a bonus item, not a better one

`ix.special.GetCraftingLuck` has existed since the SPECIAL work and had no
consumer until now. It is a multiplier a point above 1 — Luck 10 is 1.2 — so
the fraction is the chance of one extra coming out.

Making Luck improve the **output** would mean a lucky character crafting
something an unlucky one cannot, which is a different game. Getting two out of
the machine now and then is the same game with better odds. Same answer as the
loot tables, which pay Luck in quantity and never in rarity.

---

## Gating

Faction, rank, level and **how many people are actually playing** — the first
three are the set the shop asks, because somebody who may not buy the faction's
weapons should not be able to build them either.

### `minPlayers`

**Loaded characters, not connections.** Somebody sitting in the character menu,
still downloading, or at the main menu is connected and is not playing —
counting them would make an empty server look busy, which is the exact thing
the number exists to detect. Bots do not count either: `sv_devbots.lua` can put
dummies on the map, and a population gate satisfiable by spawning your own
company would not be a gate.

1 by default, which reads as "somebody has to be playing". Raising it is how a
bench stops being a thing one person farms alone at four in the morning — the
output is meant to cost the risk of other people being around, and a bench that
pays the same either way removes that.

Below the threshold a bench **cannot be opened and will not start a job**. It
is asked before faction and rank, because being told the server is too quiet is
a more useful answer than being told your rank is too low when both are true.

**A job already running still finishes.** The gate is on starting, not on
completing: the materials for that one were already spent. What it will not do
is keep turning ore into bars on a dead server for somebody to collect in the
morning.

**Transfers are re-checked, in both directions.** The window was opened by
somebody who passed `CanUse`, and nothing stops that stopping being true
afterwards — the other four people log off and the one left standing there
keeps emptying the bench through a window already on screen. Same reasoning
`sh_factionstorage.lua` gives for checking a demotion on every transfer rather
than trusting the open window.

The rank menu lists **the faction's own rank names** via `ix.class.GetRanks`,
not Enlisted→Lead, for the same reason the shop configurer does: not every
faction runs those four.

Admins are let past all three, because they are the ones who have to stand at a
bench nobody has built yet and find out whether it works.

---

## Things that bit, and what was done about them

**Dragging one item onto another never stacked them**, and nothing about the
item was wrong. `fo_stack_report` walked the same path the drag does and every
part answered yes — `combine=true`, both instances present, `CanMerge = 1`,
`OnCanRun -> true`.

The fault is entirely in how Helix's drag decides what you dropped on.
`PaintDragPreview` finds the combine target with `vgui.GetHoveredPanel()`, and
the icon being dragged called `self:MouseCapture(true)` when it was pressed — a
panel holding mouse capture *is* the hovered panel as far as vgui is concerned,
whatever the cursor is over. So `hoveredPanel != itemPanel` is false,
`combineItem` is never set, and the drop lands in a branch that does nothing.
Nothing errors; the item springs back.

There was a **second fault behind it**. Helix computes the drop cell from the
dragged panel's own corner:

```lua
dropX = math.ceil((x - 4 - (panel.gridW - 1) * 32) / self.iconSize)
```

`x` is where the panel's top-left landed, offset from the cursor by wherever
you grabbed the icon — so dragging left-to-right and right-to-left round into
*different* cells for the same apparent drop. That is why the first fix worked
one way round and not the other: refuse it one direction, immediately drag the
other way, and it merges. For ordinary moves this is invisible, because any
empty cell will do.

`libs/cl_stackdrag.lua` therefore takes the target from the **cursor**, and
sends the combine itself rather than handing `combineItem` back to Helix —
going through their handler would put it behind the `IsAllEmpty` test again,
which is the branch that eats the drop when the rounding disagrees. It falls
back to Helix's cell if the cursor is outside the grid, so it is never worse
than the old behaviour. Whether two items may merge at all is still the item's
own `OnCanRun`, re-checked on the server.

**The lesson is the split.** Two of those four diagnostic lines were about my
code and two were about Helix's; printing both sides is what said, in one run,
that no amount of reading my item files would have found it. `07-gotchas.md`
principle 1.

**Nobody ever got paid for a craft.** `JobOwner` took the *record* and read
`record.job` — and `Finish` clears `record.job` before it works out who to pay.
It answered nil every single time, so no experience, no notification, and no
output into the crafter's own inventory when the bench was full. Nothing
errored; crafting simply paid nothing. It takes the **job** now, which cannot
be asked after it has been cleared because the argument is the thing that would
have been cleared.

**A `SpawnIcon` docked TOP fills the width it is given** and renders the model
to fit *that* — so a 300-wide column produced a 300-wide icon and an item the
size of a dinner plate. Previews go in a container at a fixed square now, and
the container is what docks.

**An automatic bench has no player.** The first version called
`ix.bench.CanUse` on every job, and a processing bench starting its own job has
nobody to check a faction, rank or level against — so every automatic bench
refused itself for ever with "No character." `CanCraft` now treats a nil client
as *the bench running itself*. The permission was spent when an admin placed
it.

**`ix.util.FormatStringTime` does not exist.** `ix.util.GetStringTime` is a
**parser** going the other way; handed 240 it answers 14400, because it reads
the number as minutes. That mistake has now shipped twice — a chem description
and this file — so `ix.bench.FormatTime` is written out. See `07-gotchas.md`.

**`ix.inventory.Delete` does not exist either.** Helix deletes inventories by
hand-written SQL during character deletion. `Destroy` removes the items and
leaves the row, which is what `ix.factionStorage.Destroy` already decided.

**A NetworkVar set before `Spawn` is lost.** `SetBenchID` is called *after*
`entity:Spawn()`. This is the bug that made the first faction storage answer
"this storage is still loading" for ever.

**One net message for every type would overflow.** A message is capped at 64KB
and a definition has no ceiling on its recipe count. The sync is one message
per bench, with a count first so the client can swap the whole set in at once —
a half-applied list is what would make a window draw a recipe the server had
already deleted.

**The client has no records.** `ix.bench.list` is server-only, so the "3 / 5
steel" line polls the server once a second for what is in the bench and adds
its own inventory locally. A window that counted only what the player carried
would tell somebody who had just loaded a smelter that it was empty.

**One tick, not a timer per bench.** Phoenix create a named timer per workbench
and remove it from inside itself — their own callback opens with a validity
check and a `timer.Remove` because it happens. One loop over a table that the
loading and the removing both already maintain cannot get out of step with
itself.

**Three models are deliberately missing from the preset list.** The
two-wastelands prop pack keeps its benches at
`addons/<pack>/models/models/fallout/anvil.mdl` — a **doubled** `models`
directory — so the path the game wants is not the one the file tree reads like.
Sixteen models need no guessing; those three are typed in by hand if wanted,
and the creator's preview is the check.

---

## The starter benches

Written **once, on the first boot that has no saved types at all** — not when
the saved list is merely empty. Those are different states, and `ix.data.Get`
returning nil against returning `{}` is what tells them apart: an admin who
deletes the chem bench has decided something, and a seeder that could not tell
the difference would put it back every restart.

| id | mode | what |
|---|---|---|
| `chembench` | craft | stimpaks, RadAway, Med-X, healing powder |
| `craftbench` | craft | screws, duct tape, gears, springs, ballistic fibre |
| `smelter` | process | six ores into six bars |
| `condenser` | infinite | purified water, every three minutes |

They are **ordinary benches** — each is exactly what `/benchconfig` would have
produced, and all four can be edited, renamed, re-modelled or deleted. A recipe
naming an item that is not installed is dropped whole rather than written
without it, because a stimpak costing two antiseptic instead of two antiseptic
and a steel is a silently cheaper recipe rather than the one anybody meant.

---

## The configurer

One window, three columns: benches, that bench's settings and recipes, the
recipe you are editing.

Phoenix's is a five-page wizard with Next and Back, plus a preset system to
avoid retyping what the wizard makes you retype, plus a separate frame per
bench type. That shape exists because their data is spread across the entity
and the wizard is what assembles it. Ours is one table.

**Edited on a copy.** `self.editing` is a deep copy and nothing is sent until
SAVE — and the open form is deliberately *not* refreshed when a sync arrives,
because a sync arrives every time anybody saves anything and refreshing would
throw away a half-written recipe.

**The size only applies to benches placed after it.** A placed record carries
the size it was made at. Shrinking a type would otherwise leave items in slots
that no longer exist, and Helix has no concept of an item being outside its
inventory — those items would be unreachable rather than dropped, which is the
worst of the three possible answers.

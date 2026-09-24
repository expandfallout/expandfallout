# 28 - Faction management, storage and deployables

`/factionmanagement` (`/fm`) for your own faction, `/adminfactionmanagement`
(`/afm`) for any of them.

| | |
|---|---|
| `libs/sh_deploy.lua`, `cl_deploy.lua` | the placement ghost |
| `libs/sh_factionstorage.lua`, `sv_factionstorage.lua` | storage records, persistence |
| `entities/entities/ix_factionstorage.lua` | the locker in the world |
| `libs/sv_factionmanage.lua` | the roster and the actions |
| `derma/cl_factionmanage.lua` | the window |

---

## Class was never saved, and had to be fixed first

`ix.char.RegisterVar("class", {bNoDisplay = true})` declares **no `field`**, so
there is no database column for it and `character:Save()` writes nothing. Every
character came back on their faction's default class after a reconnect or a
restart, silently undoing every promotion anyone had been given — and it looks
like it works right up until the next restart, which is the worst shape a bug
can have.

Class is now kept in character **data**, which is a real column, under the class
uniqueID rather than its index (an index is a load-order artefact; adding one
class file would re-point every stored class above it in the alphabet).
`sh_classrank.lua` writes it on any `CharacterVarChanged` for `class` and
restores it in `Reconcile`, which runs after Helix has already applied the
faction default.

That fix is also what makes offline management possible at all: `data` is a
column, so an absent member's class is readable from the database.

---

## The window

**Open to everyone in the faction.** It shows what you can do rather than
refusing you at the door — an enlisted member sees the roster and no buttons,
which is worth more than being told they are not allowed, because knowing who is
above you is most of the point of a roster.

**Members** lists everyone in the faction, online or not, sorted by rank then
name, with a dot for who is currently here. Rename, Set class and Kick appear
only on people you outrank.

**Deployables** is Lead only, so the page is not offered below that — an empty
page you are allowed to open is a worse answer than a page that is not there.

### `/afm` is superadmin, and is the whole server

It is every roster, every rank in them and every faction's property, and it
bypasses the rank rule that governs everyone else — so it sits at the same level
of trust as destroying a faction storage, not at the level of spawning a prop.

The window gains a **column of factions** down the left, with how many
characters and storages each has, sorted so the ones with people in them come
first. A list rather than an argument because there are forty-five uniqueIDs
nobody remembers, and because the useful question when you open it is usually
"which faction has anyone in it", which a list can answer and a text field
cannot. The faction argument still works as a shortcut.

A superadmin may also deploy and stow a faction's storages for them —
`CanManage` otherwise asks for Lead *of that faction*, which nobody running
`/afm` is, and somebody has to be able to place a storage for a faction whose
Lead has not logged in for a week.

**Which faction and which powers are two questions.** The first version answered
both from one thing — "did they name a faction" — so `/afm` with no argument fell
back to your own faction *without* admin rights, which is just `/fm` under a
different name. The window now says which one it is and the server verifies it
with `IsSuperAdmin`; the flag grants nothing on its own.

### Strictly below, everywhere

You may act on somebody of a **lower** rank than your own. Not equal — two
officers cannot demote each other — and never yourself, which falls out of the
same comparison rather than needing to be said. The same rule as the C-menu
context options in `sh_factionmgmt.lua`.

A superadmin using `/afm` is exempt, because they have no rank inside the
faction to compare against. That is also the only way a faction's **first** Lead
can ever be appointed — nobody inside it can hand out their own rank.

### The roster is memory first, database second

**Loaded characters are read from `ix.char.loaded`, and the query fills in
everyone else.** The first version read the database alone, and the database row
is what was last *saved* — a character is written on disconnect, on the autosave
interval, and when something explicitly asks. Somebody who joined the faction two
minutes ago and is still standing there may not have been written yet, so the
roster showed whoever had been saved and nobody else, which in practice was
whoever had been playing longest.

`fo_faction_roster [faction]` prints both sides — what is loaded in memory and
what the query returns, with the schema name and the raw `faction` column — for
when they disagree again. Printing one of them cannot show a disagreement; that
lesson is in `07-gotchas.md`.

**Acting on a character requires them to be loaded** (`ix.char.loaded`), which
means they have logged in at least once since the last restart. Listing them
always works; changing a character that has never been loaded this session would
mean writing character vars straight to SQL behind the caching layer, which is a
good way to end up with two disagreeing copies of somebody.

---

## Deployables

Phoenix's placement flow: a translucent ghost of the thing follows your aim,
**J** and **K** turn it, left click places, right click gives up. What you place
is frozen.

- **The ghost owns no hooks.** Phoenix add three named hooks when it appears and
  remove them from inside each of the three — so cancelling in one path leaves
  the other two live until they next run and notice. Ours are added once at file
  scope and do nothing while there is no ghost, which cannot leak and cannot be
  half-removed.
- It turns **red** when the click would be refused, so the answer arrives before
  the click rather than as a notification after it. `ix.deploy.CanPlace` is one
  function, asked by both the preview and the server.
- It faces you by default. Something put down in front of you is almost always
  meant to face you.
- `CanPlayerDoPrimaryAction` is blocked while placing, or placing something would
  also swing whatever is in your hands.
- The freeze is re-applied in `PhysicsUpdate`, not just at spawn: a physics
  object woken by an explosion starts moving again, and a faction's storage
  sliding down a hill is a storage nobody can find.

## Buttons are measured, not guessed

`ixFOButton` uses `UI_Bold` — the HUD's font, sized for a title rather than for
three buttons sharing a 34-pixel row, so "SET CLASS" rendered as "SET CL...".
`FitButton` sets `ixLootSmall` and sizes the width from `surface.GetTextSize`,
because the font scale is the player's own setting: a width that fits at one
scale is cut off at another.

---

## Faction storage

**A record is not an entity.** The record *is* the storage — its faction, size,
inventory, name — and the entity is only that record standing somewhere. Stowing
removes the entity and keeps the record, which is what makes "pick it up and put
it down over there" keep the items: nothing about the inventory changes, because
the inventory belongs to the record.

Stored **per schema, not per map**, even though the position is a map's business.
A faction keeps its storages across a map change; they come back *stowed*,
because `pos` on one map means nothing on another. Storing the record per map
would lose a faction's property every time the map changed.

### Sizes

Helix takes inventory dimensions from a **registered type**, not from arguments,
so `ix.factionStorage.InventoryType` registers `factionstorage:WxH` on demand.
That keeps "any size you like" true without a table of every size anyone might
ever want.

### Opening one

`ix.storage.Open`, the library Helix's own containers use — not a net message of
our own. It already owns the search delay, syncing the inventory to the receiver,
one context per inventory so two people see the same thing, closing when a player
walks away from the entity, and closing for everybody when the entity goes. The
first version of the entity hand-rolled `ixFactionStorageOpen` and had none of
that.

`CanTransferItem` re-checks access on every item moved, because the window was
opened by somebody who passed the check and nothing stops the check failing
afterwards — a demotion, a faction change. Distance is **not** re-checked there:
`ix.storage` already closes the window on distance, and duplicating it would mean
two answers to "how far is too far" the first time either changed.

### "This storage is still loading"

**A `NetworkVar` set before `Spawn` is silently lost.** `SetupDataTables` is run
by the engine as part of `Spawn`, so `entity:SetStorageID(record.id)` on the line
above it wrote into nothing. Every deployed storage carried id 0,
`ix.factionStorage.Get(0)` found no record, and `ENT:GetInventory` answered nil
for ever.

The message now names which link of the chain broke — no record, a record with
no `invID`, or an `invID` whose inventory is not in memory — because one message
for three faults is what made this take several rounds to place.
`fo_storage_report` prints the whole chain for every record, plus every storage
entity in the world and whether a record claims it.

It read as a loading problem because that is what the message said — and the
admin route worked throughout, which looked like evidence *against* a wiring
fault when it was the opposite: `/afm` reads `record.invID` from the record it
already has and never asks the entity anything, so it was the one path that
could not have noticed.

The entity had also kept its own copy of the inventory id, set by `SetInventory`
after spawning. That is gone too: the record already knows which inventory it
owns, and a second copy on the entity was only ever a way for the two to
disagree. `ENT:GetInventory` looks the record up by the storage id it carries,
and the entity's only job is to say *which* storage this is.

### The inventory is restored on demand, not required

`ix.factionStorage.ResolveInventory` returns the record's inventory if it is in
memory and **restores it from the record if it is not** — the id and the size are
both written down there, so a missing in-memory inventory is recoverable rather
than fatal. The entity, the admin peek and the load path all go through it.

This replaced a check that answered "not loaded" and stopped, which produced a
failure that `fo_storage_report` could not reproduce a second later — the report
resolved every link while `Use` on the same entity did not. Removing the question
was cheaper than settling the disagreement.

**It is not called `Load`.** `sv_factionstorage.lua` already has an
`ix.factionStorage.Load` for reading records off disk, it loads after the shared
file, and one would have silently replaced the other — a callback that never
fires, which opens nothing and says nothing.

### More than one person at a time

`ix.storage` defaults `bMultipleUsers` to **false**, which is right for a corpse
and wrong for a faction's armoury. Both opens pass `true`.

It also fixed a second symptom: the check reads the *receiver list*, and a
receiver is only removed when the client sends `ixStorageClose`. A window closed
any other way leaves the player in that list for ever, so the same person was
told "someone else is using this" about a storage they had just closed.

### No storage holds money

`ix.storage.Sync` sends `data.money` when the context entity has `GetMoney` **or
is a player**, and the client draws a transfer row whenever that arrives.
`ix_factionstorage` has neither, so a deployed one never showed money.

The admin peek did, because `CreateContext` asserts a valid entity and the first
version passed the admin themselves — so opening a storage offered to move the
*admin's own caps* into it. A deployed storage now peeks through its own entity;
a stowed one gets a hidden, non-solid marker of the same class, removed with the
window.

### The storage view is sized to the screen

`ixInventory` uses `fo_inv_iconsize` (72 at 1080p, scaled), which is right for
one inventory filling a menu page and far too big for **two side by side** — an
8x6 storage next to a 10x7 inventory at that size is wider than the screen, and
Helix does not check. `SetGridSize` sets whatever the grid comes to and the
panels run off the edge.

`fallout_ui/cl_panels.lua` recomputes the icon size from what is available and
only ever **downwards**, so a small pair keeps the size the player chose. It
wraps `SetStorageInventory`, the last of the three calls `ix.storage` makes, and
repositions both panels afterwards — Helix centres them inside the same call
that sets the inventory, and there is no layout pass to correct it.

### Who may do what

| | |
|---|---|
| open it | anyone in the faction at or above the storage's `minRank` |
| deploy / stow | **Lead only** |
| create | superadmin, NEW STORAGE in `/afm` (or `/factionstoragecreate`) |
| deploy / stow for a faction | superadmin, through `/afm` |
| open a **stowed** one | superadmin, OPEN in `/afm` |
| destroy | superadmin, DESTROY in `/afm` (or the command) |
| destroy | superadmin, `/factionstoragedestroy` — irreversible, unlike a stow |

**Opening one that is not deployed.** A stowed storage's contents exist and
nothing in the world points at them, so without an admin route the only way to
look inside is to make the faction put it down first. `ix.storage.CreateContext`
*asserts* a valid entity — it uses one for the distance close and the money
panel — so the admin peek attaches the inventory to **the admin themselves**,
which is a shape the library already handles (it is how a player's own inventory
is opened). The window then closes when they do, rather than when they walk away
from a locker that is not there.

A storage arrives **stowed**: an admin standing in a menu is not standing where
the faction wants it, and the faction's Lead putting it down is the same gesture
as moving it later.

The inventory outlives the entity on a stow, and outlives a destroy only as an
empty orphaned row — Helix has no `ix.inventory.Delete` (character deletion
writes the SQL by hand), and an empty row costs nothing, while a hand-written
DELETE here would be a second place that has to know the schema's table names.

---

## Containers and caps

`libs/sh_containers.lua`.

**Sizes** are re-registered rather than edited into Helix's
`plugins/containers/sh_definitions.lua` — that is the framework's file, and a
framework update would silently take our sizes back. Only what differs from
theirs is listed; the wooden crate is 5x5, the other fifteen definitions are
left alone. It applies at file scope *and* on `InitializedPlugins`, because the
containers plugin builds inventory types from `ix.container.stored` in its own
handler and hook order between the two is not defined — whichever runs last,
the answer is the same.

**No caps in any container.** Caps change hands through `/givecaps` (or
`/givemoney`, its alias — Helix generates both from `ix.currency.plural`) and
nothing else. A container that holds money is a dead drop nobody has to be
present for, which is a different thing from handing somebody caps.

Helix draws the transfer row whenever `ix.storage.Sync` finds money to report —
`if (info.entity.GetMoney) then info.data.money = info.entity:GetMoney()` — and
`ix_container` has `GetMoney`, so every container had one.

`GetMoney` now **returns nil rather than being removed**: `ENT:OpenInventory`
calls it unconditionally (`data = {money = self:GetMoney()}`), so deleting the
method would error on every open. Returning nil makes that `{}`, which is what a
container with nothing to report should send.

The two net messages are replaced with no-ops as well, because hiding a button
is not a rule — re-registering a receiver replaces the previous one, so a
crafted client cannot move caps through a storage with the panel gone.

`ix_factionstorage` never had `GetMoney`, so faction storages were already
clean.

## Commands

```
/factionmanagement, /fm          your faction's roster and deployables
/adminfactionmanagement, /afm    every faction (superadmin)
/factionstoragecreate <faction> <w> <h> [name]
/factionstoragelist              every storage on the server (admin)
/factionstoragedestroy <id>      irreversible (superadmin)
```

## The faction's own log

`libs/sv_factionlog.lua`, `libs/cl_factionlog.lua`,
`derma/cl_factionlogs.lua`. Somebody doing something sus in their own faction
should be findable by their own faction, without staff reading the admin log
for them. Two kinds of line, kept per faction in `ix.data` (key
`factionlogs`, four hundred a faction):

- **shop** — every purchase from the faction shop, written beside the staff
  log in `sv_shop.lua`;
- **storage** — every item put into or taken out of a faction storage, from
  the `OnItemTransferred` hook, by whoever moved it.

A **magnifier** at the end of the shop's tab bar and in the top right of an
open faction storage opens the window: SHOP / STORAGE / ALL, a search box
(a name or an item, Enter), the last two hundred matches newest first. The
server answers only with the faction the asker is in.

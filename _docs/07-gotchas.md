# 07 — Principles

**Looking for a specific bug? Go to [13-troubleshooting.md](13-troubleshooting.md)** —
it's a symptom → cause table. This doc is the mental model behind it: the six
things about this codebase that are counter-intuitive, and why.

---

## 1. Measure. Do not reason about it.

**`continue` is a GMod keyword, so `::continue::` is a syntax error.** Standard
Lua has no `continue`, so `goto continue` with a `::continue::` label is
perfectly legal there — and GMod's parser refuses the whole file:

```
'=' expected near 'continue'
```

which takes the schema down on load. `luacheck.py` parses ordinary Lua and
*passed* the file, so the tool that exists to catch this could not. It now has
a `gmod_problems` pass for things that are valid Lua and invalid GMod Lua —
anything in that class has to be listed explicitly, because the parser will
never object to it.

That check reads **tokens, not lines**: the first version flagged the comment
explaining the rule. Documentation discussing a mistake is not the mistake, and
a checker that cannot tell the difference is one people learn to ignore.

**A scripted edit that does not assert is a change you did not make.** Batch
patches to Lua go through Python here, and this environment mangles `
`
inside heredocs — so a pattern containing one silently fails to match. Every
`str.replace` in a patch script needs an assert or a `sys.exit` on a miss. The
one place that used a bare `.replace` is the one that reported success and
changed nothing, and the bug it left (a weapon's rarity never appearing in its
name) looked exactly like a runtime problem for two rounds.

The single biggest time sink on this project was diagnosing bugs by reading
code and forming plausible theories. Three separate problems were each guessed
wrong **two or three times**, then solved in **one pass** by adding a counter.

- **Tracers invisible.** Three wrong fixes. A diagnostic reporting server
  spawns vs client constructs vs render calls found it immediately: the server
  fired 42, the client constructed 0, and the material was an error material —
  two independent faults that no amount of code-reading separated.
- **"Guns fire too fast."** Instrumenting `SetNextPrimaryFire` showed every
  weapon firing *slower* than configured. There was no bug at all.

The tell is **a symptom that doesn't match what the code says should happen**.
That gap means an assumption is wrong, and you can't find a wrong assumption by
re-reading the code that contains it.

Practically: counters at each pipeline stage, written to a file via
`file.Write` (`console.log` is buffered and truncates). Then ask the user to
restart and paste it. One round trip beats three wrong fixes.

## 2. Source's APIs fail by returning junk, not nil

This caused **three separate bugs**, and it's the single most likely cause of
anything model-related.

```lua
local id = ent:LookupAttachment("muzzle")
if id then ... end          -- WRONG: returns 0 when missing, and 0 is truthy
if id and id > 0 then ...   -- correct
```

`GetBonePosition` is worse — outside a render pass it returns the **entity's
origin** rather than failing, which looks like a plausible position and isn't.

The general rule: **validate the value, don't test its truthiness.** Assume any
Source lookup can return a confidently-wrong answer.

## 3. Two clocks, two realms — pick deliberately

- **`CurTime()`** is quantised to the server tick. Correct for gameplay timing.
  Used for a visual effect at 16 tick, it steps 16×/sec regardless of framerate.
- **`RealTime()`** advances every frame. Correct for anything cosmetic.

Similarly, the **client re-predicts** each command roughly once per rendered
frame — ~19× per tick at 300 FPS on 16 tick. Any client-side counter or side
effect that isn't guarded by `IsFirstTimePredicted()` will fire that many times.
**The server is the authoritative number.**

## 4. The scrapes are half a codebase, and you can predict which half

glua-steal captured only what the server sent to clients:

- `shared.lua` / `sh_*.lua` — **complete**, including `if SERVER` blocks
- `sv_*.lua` and entity `init.lua` — **gone**, unrecoverable

This single fact explains why melee ported in an afternoon and projectiles had
to be written from scratch, and why `ls_euclidbeam` survived when its six
siblings didn't — its author happened to put the logic in `shared.lua`.

**When something's missing, first ask whether it would have been server-only.**
If so, stop looking for it and design a replacement.

## 5. Load order: `lua/autorun` runs before the gamemode

**`libs/` is included in alphabetical order**, which means `cl_*` files run
before `sh_*` ones. `cl_usergroups.lua` seeded its defaults by calling
`ix.admin.DefaultRanks` — defined in `sh_usergroups.lua`, forty files later —
so on the client the rank table stayed empty and the admin menu died with
`attempt to index a nil value` the first time it asked what rank somebody was.

It happened a second time between two *shared* files — `sh_adminverbs.lua` (24)
registering permissions defined in `sh_usergroups.lua` (61). Renaming one file
so the order happened to work would have fixed the symptom and left the trap
for the next file, so the registry moved to `sh_adminbase.lua`, which sorts
ahead of everything that uses it. **Where a dependency exists, make the
provider sort first rather than hoping the consumer does.**

The rule: **a `cl_` file may not call a `sh_` function at file scope.** Inside a
hook or a panel method is fine, because those run long after everything has
loaded. Shared setup belongs in the shared file, at the end of it, where its
own functions exist.


`ix` does not exist there. And the dangerous version isn't the crash — it's the
guard:

```lua
local CHARACTER = ix and ix.meta and ix.meta.character   -- always nil here
if CHARACTER then                                        -- never runs
```

That installs nothing, silently, and the bug it was meant to fix keeps
reproducing with no clue why. **A crash would have been better.**

Defer to `hook.Add("Initialize", ...)`. Weapons, entities and effects are fine —
they're instantiated at runtime.

## 6. Assume nothing about what Helix provides

It's a smaller framework than it looks. Confirmed absent: **item stacking**
(no quantity, no merge, no split — this blocks all economy work), **races**,
**a rarity system**, **an admin list**.

Its hook dispatch is also unusual: `hook.Call` is overridden to run
**plugins → `Schema[name]` → gamemode**, with a non-nil return short-circuiting.
That's what lets our schema override framework behaviour cleanly — and it means
returning nil hands control to Helix code that isn't always safe for our data
(`GM:DoAnimationEvent` indexes `client.ixAnimTable` unchecked).

Also confirmed absent, each found the hard way: **`ix.inventory.Delete`**
(character deletion writes the SQL by hand, so `Destroy` empties an inventory
and leaves the row) and **any time formatter at all**.

That second one is worse than absent, because something that looks like it is
there. `ix.util.GetStringTime` is a **parser** going the other way — handed 240
it answers 14400, because it reads the number as minutes. It has now been
mistaken for a formatter twice, in a chem description and in the workbench
tooltip. `ix.bench.FormatTime` is the written-out one.

**`weapon.ixItem` is server-only.** Helix sets it in `ITEM:Equip`, which calls
`client:Give` and therefore only runs on the server — so the client's copy of
the same weapon entity has no `ixItem` at all. Reading it clientside returns
nil, silently, and anything relying on it quietly does nothing: the crosshair
damage readout showed base damage on a weapon that had a rarity, with no error
anywhere. The client finds the item the other way round instead — its own
inventory is synced to it, and exactly one item of that class is flagged
`equip`. See `ix.rarity.HeldItem`.

**`ix.log.AddType` is server-only.** It is defined inside `if (SERVER)` in
Helix's `sh_log.lua`. Calling it from a *shared* file takes the whole schema
down on the client with `attempt to call field 'AddType' (a nil value)` — and
a client that never finishes including the schema sits on a grey screen after
picking a character. Every `sv_` file is safe; a `sh_` file needs the guard.

**Registering a log type that already exists REPLACES it, silently.** It is a
plain table write. Six of this schema's types quietly took over Helix's own
(`charLoad`, `charCreate`, `charDelete`, `playerDeath`, `connect`,
`disconnect`) — and then Helix's logging plugin called *our* formatter with
*its* arguments:

```lua
ix.log.Add(client, "charLoad", character:GetName())   -- one argument
function(client, name, id, steamID) ... "%d" ... id   -- three expected
```

which threw on every character load, from inside `character:Setup()`. Nothing
was visible at registration time, so `sv_adminlog.lua` now wraps `AddType` and
refuses a name that is already taken rather than overwriting it — the existing
one is the one something is already calling.

**A getter being shared does not make its setter shared.**
`character:GetData` works on both realms - it is an `ix.char.RegisterVar`
accessor reading `character.vars.data`. `character:SetData` is defined inside
`if (SERVER)` and is simply **nil on the client**:

```
attempt to call method 'SetData' (a nil value)
```

The fix was to delete the call rather than guard it. That var is registered
`isLocal = true` with an `OnSet` that networks the change to the owner, so the
client's `GetData` is already correct by the time any message of ours arrives -
the client-side write was storing a second copy of a fact it already had, and
the copy is always the one that goes stale. Worth checking for the same shape
before adding a client cache of anything Helix already networks.

**`Derma_Query` and `Derma_StringRequest` take their buttons differently.**

```lua
Derma_Query(text, title, okText, okFn, cancelText, cancelFn)
Derma_StringRequest(title, text, default, enterFn, cancelFn, okText, cancelText)
```

One is text-then-function pairs; the other takes both functions first. Copying
the trailing `"Cancel", function() end` from a nearby `Derma_Query` puts the
cancel *text* in the cancel *function* slot and hands a function to `SetText`:

```
bad argument #1 to 'SetText' (string expected, got function)
```

The two calls read almost identically and mean different things. Check the
order rather than the shape.

**A plausible name is not evidence.** Grep the framework before calling
anything you have not called before; the failure mode is not a nil error but a
number that is sixty times too large and looks fine.

Check `11-helix-api.md` before assuming an API exists.

---

## 7. A getter is not necessarily the inverse of its setter

`Entity:SetMaterial` on a `ClientsideModel` works. `Entity:GetMaterial` on the
same entity always returns `""`, because it reads a networked field only the
server writes. Guarding a write on reading the value back therefore applies a
material and can never remove it.

That cost four rounds of fixes on the stealth field, each one correct code built
on the assumption that reading back what you wrote gives you what you wrote. See
`20-armour.md`.

The same shape appears in `SetNW2Bool(name, false)`, which does not network
because the value equals the default — so a var can be false on the server and
true on every client at once.

**When a fix that reads correctly changes nothing, stop fixing and print both
sides.** The failure is then usually a disagreement, and no amount of reading
one side shows one.

A third instance: `Entity:SetNetworkVar` before `Spawn` is silently lost, because
`SetupDataTables` runs as part of `Spawn`. The setter succeeds, the getter
answers 0, and nothing errors. See `28-faction-management.md`.

**A replicated convar cannot be set from a client console.** `CreateConVar(...,
FCVAR_REPLICATED)` on the server gives the client a value to *read*; typing it in
the client console answers "Unknown command", because changing it is the server's
to do. A debug toggle a player needs to flip has to be a **concommand**, which
runs where it is typed.

**And a corollary about evidence.** When one route works and another does not,
check whether the working one actually exercises the thing you suspect. The
faction storage opened fine from `/afm` and not from the world, which read as
evidence against a wiring fault — but `/afm` reads the record directly and never
asks the entity anything, so it was the one path that could not have caught it.

## 8. An addon can shadow a scripted entity's own methods

`FindMetaTable("Entity")` is global and shared. An addon that does

```lua
local ENT = FindMetaTable("Entity")

function ENT:GetInventory() return self.tbl_Inventory end
```

has just replaced `GetInventory` **for every scripted entity on the server**,
because a metatable method wins over the SENT's own. `fallout_snpcs_remastered`
does exactly that in `lua/autorun/vj_f3r_meta.lua:377`, and it is why pressing E
on a Helix container did nothing for five rounds of debugging: `ix_container:Use`
is `if (inventory and ...)` with no else, and the addon's version returns nil on
anything that is not a VJ NPC.

**Reading the codebase cannot find this.** The file is not in the gamemode, not a
plugin, and is loaded from `lua/autorun` before the gamemode exists. Every
diagnostic reported the container healthy, because everything except that one
expression was.

**`debug.getinfo(self.Method, "S")` is what finds it** — `short_src` and
`linedefined` name the file and line that actually defines the method being
called, whatever anyone expected. Reach for it the moment a call returns
something its source says it cannot.

`libs/sh_entitymeta.lua` restores the precedence rather than deleting the
addon's method: an entity class that defines its own gets its own, everything
else still gets the addon's. `fo_meta_report` lists every such clash on the
server.

## 9. A `hook.Add` that returns kills the gamemode's own method

`hook.Call` runs every `hook.Add` listener first and **returns the instant one
of them returns a value**. The `GM:` method for that hook is then never called
at all.

So a hook cannot "amend and pass on". This looked completely reasonable:

```lua
hook.Add("PlayerSay", "ixAdminPrefix", function(client, text)
	if (string.sub(text, 1, 1) ~= "!") then return end

	return "/" .. string.sub(text, 2)     -- WRONG
end)
```

The intent was to rewrite `!goto bob` into `/goto bob` and let Helix parse it.
What actually happened is that `GM:PlayerSay` - which is where Helix calls
`ix.chat.Parse` and `ix.command.Parse` - never ran, and the return value became
the result of `PlayerSay`, so the engine said "/goto bob" out loud as ordinary
chat. **Every `!` command silently did nothing.**

The symptom pointed at the wrong layer entirely: it read as the commands not
existing, or as a permission problem, because the thing that broke was not the
command but the parser that never saw it.

**A hook that returns is a hook that ENDS the call.** If the gamemode method
does work you still need, either return nothing, or do that work yourself:

```lua
	ix.command.Parse(client, "/" .. string.sub(text, 2))

	return ""
```

`ix.command.Parse` is exactly what `GM:PlayerSay` calls for a `/command`, so
both prefixes reach the same code by the same route.

**Returning `false` to deny is fine** - the answer is already no and skipping
the rest changes nothing. `sv_sandbox.lua`, `sv_bench.lua` and
`sv_factionstorage.lua` all return `false` or nothing, never a value meant to
be passed onwards. Audit for the difference, not for the return.

## 10. Derma draws children in order, and a panel sized to its content has no corner

Two traps that look like one bug, because a panel that is behind something and
a panel that is off the end of its parent both read as "it never got created".

**Later children draw over earlier ones.** A button added in `Init` is drawn
under everything the panel builds afterwards. `ixInventory` adds its slots in
`BuildSlots`, long after `Init`, so the bin button added in a wrapped `Init`
was under the top-right slot — present, laid out, taking no clicks, erroring
nowhere. `SetZPos` fixes the order; `MoveToFront` also does, but calling it
from inside `PerformLayout` invalidates the parent's layout and loops.

**A panel sized to its content has no free corner.** `ixInventory:SetGridSize`
sets the panel to `w * iconSize + 8` by the grid height, so every pixel of it
is a slot. "In the corner of the inventory" therefore has to mean the corner of
the page the inventory sits on, not of the panel — which in this schema is the
container `MenuSubpanelCreated` hands over.

Before deciding a panel was never created, print its parent, position, size and
visibility. All four were right for the bin button except the one that was not
printable from the screen.

## 11. `CurTime` restarts at zero; `os.time` does not

Anything written to disk that means "when should this happen" has to be a wall
clock. `CurTime` is seconds since the map loaded, so a cap stash saving
`CurTime() + 900` came back after a restart as a moment fifteen minutes into a
session that had just begun — or, saved by a server that had been up for hours,
as a moment already long past. The timer was wrong in both directions and only
ever across a restart, which is the hardest kind of wrong to notice.

`os.time` for the record, `CurTime` for the entity, converted on load where "how
long is left" is the only question either can answer.

## 12. A method call inside arithmetic hides which half was nil

    data.refillAt = os.time() + self:Respawn()

threw "attempt to perform arithmetic on a nil value" on every single cap stash
loot, and the line reports itself rather than the operand — so the error names
line 158 whichever of the two was nil. Three rounds of reading `Respawn`,
checking that nothing shadowed it, and confirming `os.time` works elsewhere got
nowhere, because the answer is not in the source of either.

The consequence was worse than the error: the exception left `refillAt` at 0, so
the refill tick saw a stash that was empty with no timer on it and put it
straight back. **The stashes were infinite because the error was the refill.**

Read the operands into named locals first. A nil is then visible where it comes
from, and can be reported with the record id attached instead of thrown three
lines later with nothing but a line number.

## 13. `ix.item.inventories[0]` is a bare table, and a hook that throws breaks its caller

The world is inventory 0 and Helix stores a plain `{}` there — no metatable, so
no `GetOwner`, no `GetID`, nothing. `sv_tracking.lua` called
`inventory:GetOwner()` straight out to name the inventory in a **log line**, and
threw on every transfer that touched the world: every item picked up off the
ground, every item dropped onto it.

The throw was the real damage. `OnItemTransferred` fires from inside
`ITEM:Transfer`, which is inside the take function, which is inside
`ix.item.PerformInventoryAction` — and an error in a hook takes all three down
with it. By then the item had already been added to its new inventory; what
never ran was the rest of `Transfer`, its `return true`, and

```lua
if (result != false) then
    if (IsValid(entity)) then entity.ixIsSafe = true entity:Remove()
```

So the item was in the inventory **and** still lying on the ground. Pressing E
on it again answered "same inv". Dropping it hit `item.entity:GetPos()` on an
entity that had since been removed — NULL is truthy, so the `if (item.entity)`
guard passed — and threw again before reaching the drop.

**Three unrelated-looking faults, one unguarded method call in a log line.** It
took four rounds of reading `ITEM:Transfer` and `Inventory:Add` to find, because
none of them are where the bug is.

Two rules out of it. Check for the method, not the table: `inventory.GetOwner
and inventory:GetOwner()`. And anything that only writes a log entry belongs in
a `pcall` when it runs inside somebody else's transaction — a wrong log line
should stay a wrong log line.

## 14. `Inventory:Iter()` walks SQUARES, not items

The single most expensive misreading in this project so far.

```lua
function META:Iter()
    ...
    item = self.slots[x] and self.slots[x][y]
    x = x + 1
```

and `Inventory:Add` writes the item into every slot of its footprint:

```lua
for x2 = 0, item.width - 1 do
    for y2 = 0, item.height - 1 do
        targetInv.slots[index][y + y2] = item
```

So **a three-by-two rifle is yielded six times**. Every `for item in
inventory:Iter()` is a loop over occupied squares, and in a schema full of two-
and three-square guns that is a completely different list.

What it cost before anybody noticed:

- `[Helix] Cannot give weapon - ls_ak47 does not exist!` **five times** on every
  spawn. `GM:PostPlayerLoadout` calls `OnLoadout` once per yield; the first
  `Give` succeeded and the other five failed because the player already held
  it. Five failures for a six-square weapon — the count was the shape of the
  item.
- A de-duplication pass written to fix *that* read the six yields as six items,
  kept the "first" and unequipped the other five — which were the same item. It
  unequipped the only rifle the character had, on every join, and found six
  again next time because there had only ever been one.
- `fo_grid_report`'s overlap detector compared that rifle against itself fifteen
  times and reported fifteen overlaps. A report built to find grid corruption
  was manufacturing it.
- `ix.stack.Count` — which decides whether a recipe can be crafted — answered in
  squares.

`ix.inventory.Each(inventory)` in `libs/sh_inventory.lua` yields each item once,
keyed by item id, and is otherwise the same iterator. Every schema loop uses it.
`Iter()` is still right where the position is the point — `cl_quickmove.lua`
wants squares.

**Read the iterator before trusting the loop.** Two of the three bugs above were
"fixes" for the first one, written without looking at what was being iterated.

## 15. Hiding a row in a panel is not a permission

The trash bin suppresses the caps row on the storage window by no-opping
`ixStorageView:SetLocalMoney` and `SetStorageMoney` for one inventory id. That
is fine there — the bin's inventory belongs to nobody and holds no money.

Reusing the same trick to keep a **search** of a restrained player from
including their caps is not fine, and looked identical:

```lua
net.Receive("ixStorageMoneyTake", function(length, client)
    local inventory = client.ixOpenStorage
    ...
    entity = entity:IsPlayer() and entity:GetCharacter() or entity
    character:SetMoney(character:GetMoney() + amount)
```

The money never went through the panel. Helix's receiver only checks that the
inventory is the one you have open, and for a search the storage entity *is*
the person being searched — so one hand-written net message empties their
pockets with the row still hidden.

`sv_restrain.lua` wraps `net.Receivers["ixstoragemoneytake"]` and
`["ixstoragemoneygive"]` and refuses while the open storage is a search.
`net.Receivers` is a real table in GMod's `net.lua` and the dispatcher looks the
function up in it at call time, so replacing an entry works — the same shape as
the `concommand.GetTable()` wrap in `sv_sandbox.lua`, and checked at runtime
rather than assumed.

**Anything the client can send, the client can send without the panel.** If a
rule matters, it belongs on the receiving end.

## 16. This server has no Half-Life 2 sounds

Phoenix's code is full of `physics/flesh/flesh_squishy_impact_hard1.wav`,
`npc/barnacle/neck_snap1.wav`, `common/warning.wav`, `buttons/button5.wav` —
HL2 paths, because their server mounts HL2 content. Copying those paths across
with the behaviour they belong to produces **silence**: no error, no warning,
nothing in the console. A plant that harvested correctly and made no noise read
as "the harvest is broken".

```bash
python _docs/tools/resolve_asset.py sound/physics/flesh/flesh_squishy_impact_hard1.wav
```

`*** MISSING ***`. So is every other HL2 sound tried so far. What this server
*does* have is the Fallout packs:

| Want | Use |
|---|---|
| picking something up | `phoenix/ui/nv/ui_items_generic_up_01..04.mp3` |
| putting something on | `phoenix/ui/nv/ui_items_clothing_up_01..03.mp3` |
| a UI beep / countdown | `phoenix/ui/nv/menu_beep.mp3` |
| a refusal | `phoenix/ui/nv/menu_cancel.mp3` |
| a metallic click | `weapons/reload/357revolver/wpn_357revolver_reloadclick.mp3` |
| arming something | `weapons/mine/wpn_mine_arm.wav` (af_content_pack_4) |
| an explosion | `weapons/explosion/fx_explosion_grenade_frag_high_01..03.mp3` |

**Check every sound path with `resolve_asset.py` before using it**, exactly as
models already are. A missing model is an error-textured box somebody notices;
a missing sound is nothing at all.

## 17. A scripted entity method called `Respawn` answers nil

`self:Respawn()` returns **nil**, whatever the body says:

```lua
function ENT:Respawn()
    return math.Clamp(tonumber(self:Data().respawn) or 300, 10, 86400)
end
```

That function cannot return nil. Called as `self:Respawn()` on `ix_plant`, it
did — every time. `Yield` and `Experience`, sitting three lines below it, built
the same way out of the same `Data()` call and the same `math.Clamp`, worked
fine. Nothing in Helix, the base gamemodes, the schema or any installed addon
defines or assigns `Respawn`, and `math` is not overridden anywhere.

**It cost three rounds of the wrong diagnosis**, because one throw produced
three different symptoms as the code moved around it:

| Where the call sat | What it looked like in game |
|---|---|
| after the sound and XP | plant harvests, makes a noise, gives XP, **never grows back** |
| moved above them, to protect the deadline write | plant harvests, **silent, no XP**, still never grows back |

Both times the deadline was `now + nil` and the throw was swallowed by the
engine's use handler, so the console said nothing until the report was asked
for one directly.

**The cap stash hit this first** and gotcha 12 records the workaround — reading
the number into a local instead of calling the method. That worked, but not for
the reason written there: it worked because it also *deleted the method*. The
plant then reintroduced the name and walked into the identical wall.

**Do not name an entity method `Respawn`.** `RegrowTime`, `RefillTime`,
anything else. If a method on an entity returns nil when its body plainly
cannot, rename it before spending another hour on the body — and read numbers
into locals before arithmetic either way (gotcha 12), so the next one names
itself.

## 18. `DrawTranslucent` never runs without `RENDERGROUP_BOTH`

An entity's `ENT:DrawTranslucent` is only called if it is in a translucent
render group, and an anim entity with an opaque model is not in one. The code is
written, is correct, and simply never runs — no error, nothing in console.

It cost two rounds: the crop plot's water bar, every crop's growth bar and the
ore node's weight label were all reported missing, twice, and all three were the
same line:

```lua
ENT.RenderGroup = RENDERGROUP_BOTH
```

The tell was already in the codebase — `ix_breachcharge`'s glow and the orbital
beacon's dome both draw translucently and *both* set it. If something drawn in
`DrawTranslucent` does not appear, check the render group before checking the
maths.

## 19. A storage context is made once and reused, entity and all

`ix.storage.Open` only builds a context if the inventory does not already have
one:

```lua
if (!inventory.storageInfo) then
    ix.storage.CreateContext(inventory, info)
end
```

Two consequences, and both look like "the box is broken":

- the context remembers **the entity it was opened at**, and that entity is what
  `DoStaredAction` waits for you to keep looking at. Open the same inventory at a
  second box and the open silently never completes, because you are not looking
  at the first one.
- a context whose receiver never sent `ixStorageClose` — a disconnect, a crash,
  a window closed some other way — still counts as **in use**, and the next open
  is refused with `storageInUse`.

Neither matters for a container that is one entity and one inventory. It matters
the moment several entities open the *same* inventory, which is exactly what the
personal stash is. `ix.stash.Open` calls `ix.storage.Close(inventory)` first,
which sends the expiry to any receivers and drops the context, so the open that
follows uses the box actually in front of you. That is only safe because a stash
has exactly one legal user; on a shared storage it would boot whoever was in it.

## 20. `Inventory:Add` does not check the slots when you tell it where

The branch that places an item at a given position writes into whatever is
already there:

```lua
if (x and y) then
    targetInv.slots[x] = targetInv.slots[x] or {}
    targetInv.slots[x][y] = true
    ...
    targetInv.slots[index][y + y2] = item
```

`CanItemFit` is asked on the path that moves an item **within** one inventory
and on no other path at all — so `ITEM:Transfer(invID, x, y)`, which is what
every drag and every shift-click between two inventories ends in, will happily
put two rifles in the same squares. They then draw on top of each other and the
one underneath is unreachable.

The way in is easy: shift-click three things quickly. Each click asks the
**client's** copy of the destination for a free square, and that copy does not
change until the server answers, so all three are told the same square is free.

`libs/sv_gridguard.lua` wraps `ix.meta.inventory.Add` and checks before every
positioned placement, sending the item to the first genuinely free square
instead of refusing — "put this in the box" should not fail over an argument
about which square. `libs/cl_quickmove.lua` also reserves squares locally for a
few seconds so twenty shift-clicks fill twenty squares rather than sending
twenty moves for the server to redirect one at a time.

While in there: `CanItemFit` checks the right-hand edge and **not** the bottom
one (`(x + x2) > self.w`, and nothing about `self.h`), so a tall item placed
near the bottom passes its own test and writes into rows that do not exist. The
guard checks the height too.

## 21. The tree is keyed by ACTIVITY; jumping is keyed by a string

`Schema:TranslateActivity` looks up `tree[act]`. Every hold type in
`ix.anim.falloutHuman` stores its jump under the **string** key `jump`:

```lua
	jump = {"2hraim_jumpstart", "2hraimis_jumpstart"},
	land = {"2hraim_jumpend", "2hraimis_jumpend"}
```

Nothing is keyed by `ACT_MP_JUMP`, which is what Helix's `CalcMainActivity`
asks for while you are off the ground — so the translator returned nil, Helix
mapped it to an HL2MP jump activity, and the New Vegas models have none of
those. **Sequence 0 on these models is the reference pose**, which is the
T-pose, and landing put the activity back to one that resolves — so it fixed
itself and looked like a physics glitch rather than a missing animation.

Fixed with a nil-safe map from the airborne activities onto those two string
keys. Nil-safe because half those enums do not exist in every build
(`ACT_MP_JUMP_LAND` is not a global in GMod at all) and **a nil key in a table
constructor is an error at load** — which would take the whole schema down
rather than one animation.

## 22. A plugin's hook beats the schema's, and `HOOKS_CACHE` is how you win

`hook.Call` in `sh_plugin.lua` runs plugin hooks **first**, then `Schema[name]`,
then ordinary `hook.Add` listeners — and the first non-nil return wins. So a
`Schema:` function cannot override a Helix plugin, and neither can `hook.Add`.

`HOOKS_CACHE` is a global table of `[hookName][pluginTable] = function`.
Replacing the entry replaces the plugin's hook for that name, which is the only
way to change one without editing the framework:

```lua
HOOKS_CACHE.GetCharacterDescription[ix.plugin.list.recognition] = mine
```

`sh_recognizeinteract.lua` uses it to stop the recognition plugin hiding
descriptions from strangers. Note that the cache holds the **function
reference**, so assigning `PLUGIN.GetCharacterDescription` later does nothing —
the cache still has the old one.

## 23. `obj:method` is not a value, and it stops the whole framework

```lua
character:GetThirst and character:GetThirst() or 0
```

reads fine and is a **syntax error**: the colon is call syntax, so Lua demands
the argument list right after it. The dot is what takes the function itself.

It matters more than an ordinary typo because a file that fails to PARSE takes
the schema's include with it, and Helix answers that with "Something has errored
and prevented the framework from loading correctly" - no character menu, and a
cascade of unrelated errors from every plugin that then reads a config which was
never registered (a chatbox comparing `nil` with a number, in this case).

`luacheck.py` now catches it: a `:` followed by a name must be followed by `(`,
a string literal or a table constructor - `obj:method"x"` and `obj:method{...}`
are legal calls - and goto labels are excluded, since `::skip::` tokenises as
two colons around a name.

**AND IT TAKES EVERY FILE AFTER IT WITH IT.** `ix.util.IncludeDir` is a plain
loop over `file.Find` with no `pcall`, so an error thrown by one file propagates
out of the whole directory - every file *alphabetically after* the broken one is
never included at all. `cl_charinfo.lua` sorts near the front of `libs/`, so one
syntax error there silently disabled the crosshair, the doors, the observer
patch, mining, karma and every `sv_` file in the schema.

That is why a load error presents as several unrelated features being broken at
once: noclip teleporting you back (its `CanPlayerEnterObserver` patch never
ran), the chatbox erroring on a nil `chatMax`, no main menu. **Fix the first
error in the console and re-test before chasing any of the others** - most of
them do not exist.

## 24. A panel that lays itself out ignores `SetZPos`

`ixFOMenu` positions its tab buttons by hand:

```lua
for i = 1, #self.tabButtons do
    self.tabButtons[i]:SetPos(x, ...)
    x = x + self.tabButtons[i]:GetWide() + gap
end
```

so a button's place on screen **is its index in that array**. `SetZPos` is the
correct answer for a docked strip, it is a real call that errors nowhere, and it
changed absolutely nothing here — the tab order feature looked implemented and
did not work. Sorting `self.tabButtons` is the fix.

Before reaching for a layout call on a panel in this schema, read its
`PerformLayout`: docking order, z positions and manual `SetPos` are three
different worlds, and only one of them is in play at a time.

## 25. A plugin's flag survives a reload; the patch does not

`ix.plugin.Load` rewrites `HOOKS_CACHE[k][PLUGIN] = v` from the plugin table on
every load, and `GM:OnReloaded` calls `ix.plugin.Initialize()` again. So a
"have I patched this?" flag stored **on the plugin table** is still there after
a reload while the patched function it was guarding has been thrown away — the
guard then refuses to re-apply the patch, and the feature silently reverts.

That is how noclip started teleporting people back to spawn again after having
been fixed. The marker has to be **a set of our own functions**
(`ix.observer.patches[patched] = true`), which cannot survive the thing it is
describing. Functions cannot carry fields in Lua, so it is a table keyed by the
function rather than a field on it.

**And a patch that has to survive is not enough on its own.** `sh_observer.lua`
now patches *both* of the plugin's hooks (`CanPlayerEnterObserver` **and**
`PlayerNoClip`), re-applies from three hooks rather than one
(`InitializedPlugins`, `OnReloaded`, `PlayerInitialSpawn`), and answers
`fo_observer` in the console with what it actually managed to patch and what
the config says. When a fix depends on winning a race against a cache rebuild,
the thing worth building is the way to *ask*.

## 26. `cl_` loads before `sh_`, so a `cl_` file cannot assume its table

`ix.util.IncludeDir` walks a folder in `file.Find` order, which is
alphabetical. Every `cl_` file in `libs/` therefore runs **before**
`sh_live.lua`, `sh_special.lua` and the rest — so this, at file scope in
`cl_live.lua`:

```lua
function ix.live.ToggleSights()
```

is `function (nil).ToggleSights()`, an error, **and it takes the whole
directory with it** (gotcha 23). One missing line meant that on the client
`cl_rarity.lua` never wrapped the item descriptions, no `sh_` library loaded at
all, and the live editor's own kinds were absent — which presented as five
unrelated features being broken and one visible error about a nil
`ToggleSights`.

The fix is the line every other `cl_` file in this schema already has:

```lua
ix.live = ix.live or {}
```

`luacheck.py` now enforces it: a `cl_` file that writes `ix.<name>.<thing>` at
file scope without declaring `ix.<name>` first is a reported problem.
`sv_` files are exempt because they sort *after* their `sh_` partner.

**The symptom is worth memorising**: one nil-function error plus several
unrelated features quietly not working means an include cascade, and the file
to look at is the one alphabetically *before* everything that broke.

## 27. A hook listener that returns a value stops the hook

GMod's `hook.Call` takes the **first non-nil answer**, returns it, and runs
neither the remaining listeners nor `GM:<Name>`. For a hook that asks a question
(`CanPlayerEnterObserver`, `PlayerShouldTakeDamage`) that is the whole point.
For a hook that reports an event, it is a silent cancellation of everything
after you.

```lua
-- Apply() answers true/false so a console command can report what it patched.
hook.Add("PlayerInitialSpawn", "ixFalloutObserverMode", ix.observer.Apply)
```

`GM:PlayerInitialSpawn` is what calls `client:LoadData` and sends `ixDataSync`,
and `ixDataSync` is what ends the client's loading screen. So this one line —
housekeeping, on a hook that was not asking anything — meant **every player who
joined sat on a black "Loading" screen for ever**, and their `ixData` stayed
nil, which is where the server's

```
sv_player.lua:59: bad argument #1 to 'TableToJSON' (table expected, got nil)
```

on disconnect came from. Two symptoms, one cause, neither of them mentioning
noclip.

The fix is a wrapper that discards the answer:

```lua
hook.Add("PlayerInitialSpawn", "ixFalloutObserverMode", function()
    ix.observer.Apply()
end)
```

Two older listeners had the same shape and are now wrapped too —
`AllowDescriptions` on `InitializedPlugins` and `ApplyToolFix` on
`InitPostEntity`, both returning `true` to mean "patched", both able to cancel
every other listener on those hooks depending on iteration order. That is a
class of bug that hides until something else registers on the same hook.

`luacheck.py` now reports both forms — a named function that returns a value
passed to a quiet hook, and an inline listener with a top-level `return` — for
`InitializedPlugins`, `InitPostEntity`, `OnReloaded`, `PlayerInitialSpawn`,
`LoadData`, `SaveData`, `CharacterLoaded` and their neighbours.

`luacheck.py` checks this, and its list of report-only hooks was **too short**
for a long time: `PlayerDeath`, `PlayerSpawn`, `KeyPress`, `PhysgunDrop` and a
dozen others were never examined, so a listener that answered one of them would
have passed silently. The list now covers them.

## 27a. Scale the carrier's bones; never the meshes merged onto it

A body in this schema is an `animations.mdl` carrier with meshes bone-merged
onto it. To hide a limb, scale **every bone of that limb, to exactly zero, on
the carrier** — and touch nothing else. The meshes follow, because they carry
`EF_PARENT_ANIMATES`.

Scaling the same bones on the meshes as well applies the collapse a **second
time in each mesh's own space**, and the geometry lands somewhere off in the
air: a pale shard beside the corpse. Nine rounds of debugging went into that
shard on the assumption it was a missing bone, a bad scale value, or the
carrier's own mesh.

The carrier does have a mesh — `animations.vvd` is 385 KB — but its bodygroup
defaults to the blank option, so it draws nothing and needs no hiding. Do not
`SetNoDraw` it either: a parent that is not drawn is a parent whose bones the
engine has less reason to set up.

And do not re-apply the scaling from the client. The `manipulate_bone` entity
the engine parents to the ragdoll already carries it to every client; a
client-side `ManipulateBoneScale` on the same entity is a second writer to the
same table, and a Phoenix corpse has exactly one.

Confirmed by reading a live Phoenix corpse with `_docs/tools/fo_phoenix_probe.lua`.

## 27b. `EF_BONEMERGE` merges the skeleton, not the bone setup

A `ClientsideModel` with `EF_BONEMERGE` follows the parent's animation. It does
**not** follow the parent's bone MANIPULATIONS — scale, position, angles — until
it also has `EF_PARENT_ANIMATES`.

```lua
part:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL,
    EF_PARENT_ANIMATES))
part:Spawn()
```

Phoenix use all three on every merged mesh. With only the first, scaling a limb
away on a corpse leaves the visible body untouched, and scaling the visible body
instead applies the collapse twice — once through the merge and once in the
mesh's own space — which throws the geometry somewhere off in the air. Six
rounds of debugging went into those two symptoms as though they were separate
problems.

## 27c. A bone scaled to zero keeps its origin, and its children keep theirs

Scaling a bone to zero collapses every vertex weighted to it onto the bone's
**origin** — and the origin stays exactly where the bone was. The scale is
applied to each bone's own matrix after the hierarchy is built, so **children
do not inherit it**: read off a corpse, `Bip01 L Toe0` sits at scale zero eight
units past `Bip01 L Foot`, and `animations.phy` has no physics object that
could have put it there.

So a limb with every bone at zero is not a point. It is a skeleton of points
with every triangle that spanned two of them stretched between them: a leg is
four points nearly in a line and nearly invisible; a hand is a wrist and
fifteen finger joints spread across where the hand was, with the palm still
spanning them — a pale fan with five spikes. That was "the fragment", and why
it was worst on hands and feet.

A ragdoll's **physics bones cannot be moved** by a manipulation — thigh, calf,
foot, upper arm, forearm and hand are placed by their physics objects.
Everything else hangs off one of those through the hierarchy, and
`ManipulateBonePosition` (an offset in the parent's frame) is honoured there,
which is how ragdoll fingers get posed. `ix.dismember.Gather` reads each
non-physics bone's offset from its parent and sets the negative, so it sits on
the parent's origin; then everything is scaled to zero. What is left is one
point per physics object, and triangles between points on a line have no area.

The offsets come from the **model file**, not from the ragdoll. On the server a
ragdoll's bone matrix for a bone with no physics object is the reference pose
at the entity origin — a toe read 38 units from its own foot — so a version
that read them live moved every toe 38 units the wrong way. What the client
actually uses for such a bone is its bind-pose local position,
`mstudiobone_t.pos` in the .mdl, and the offset is added to that in the
**parent's frame**: checked against a live report, bind position plus the
offset written came to 42.96 units and the toe was 42.96 units from the foot.
`ix.dismember.BindPose` reads the bone table out of the .mdl once per model
(`file.Open` in `GAME`, bone count at 156, table at 160, 216 bytes a bone,
position at +32) and the offset is simply the negative of that position.

## 27d. A merged mesh's bones the carrier lacks sit at the carrier's origin

`EF_BONEMERGE` copies matrices for bones the parent **has**. A bone the child
mesh has and the parent does not is computed from the child's own hierarchy,
and the root of that hierarchy is the child entity's origin — the carrier's
origin, since the part is parented with no offset.

The human `head.mdl` has `Dummy001` → `Bip01 Spine2` (58.8 units up) → neck.
Merged onto a human carrier, `Spine2` matches and everything is fine. Merged
onto a super mutant, which has no `Spine2`, that bone lands 58.8 units "up"
from the ragdoll's pelvis in the ragdoll's own frame — which on a body lying
down is a point out in the air — and every neck vertex weighted to it draws a
skin-coloured spike to that point. On a *standing* player the same wrong bone
sits almost exactly where the real one would, which is why nothing shows
until there is a corpse.

The rule: never merge a mesh onto a skeleton it was not made for. A corpse's
parts come from a server-composed recipe now for exactly this reason — the
old fallback merged the human default body onto whatever died.

## 28. `istable` is false for an entity, and a guard built on it lies

```lua
function ix.live.Write(target, path, value)
    if (not istable(target)) then return false end     -- a weapon fails here
```

An entity is userdata with a metatable; its fields are reached through
`__index` into its own table, and `weapon.Primary.Damage = 40` is a perfectly
ordinary write. But `istable(weapon)` is **false**, so this guard turned every
write to a weapon somebody was holding into a silent no-op that returned false.

The result was live weapon editing that half worked in the most confusing
possible way: `weapons.GetStored` got the new damage, so every weapon spawned
afterwards had it and the item description showed it — and the rifle in your
hands kept the old numbers for ever. Nothing errored and nothing was reported.

Use `istable(x) or isentity(x)` when the thing you are indexing might be either,
and be suspicious of any `istable` guard on a value that can be an entity, a
`Player`, a `Vector` or a `Color` — none of those are tables.

## 29. A `DComboBox` reads its convar and never writes one

```lua
-- lua/vgui/dcombobox.lua, PANEL:ChooseOption
-- self:ConVarChanged( self.Data[ index ] )
```

Commented out, in the shipped game. `panel:ComboBox("Label", "some_convar")`
looks like a two-way binding and is a one-way one: `CheckConVarChanges` watches
the convar and updates the box's text, and choosing an option updates *nothing*.

That is why a tool panel could be opened, read, and picked from with no effect
at all — the War Point Placer's faction list, the lootable tool's table, sound
set and lock. Every one of them now sets its own convar:

```lua
combo.OnSelect = function(_, _, value, data)
    RunConsoleCommand("the_convar", data or value or "")
end
```

**And `OnMenuOpened` is a real method that fires too late to refill a list.**
`dcombobox.lua:232` calls it *after* the menu has been built from the current
choices, so a refill there affects the next menu rather than the one that just
opened. Anything whose contents arrive over the network — a loot table list on
a fresh client — has to refill on a timer instead.

## 30. `$color` on a model's material is the entity's render colour

A `CreateMaterial("...", "UnlitGeneric", {["$basetexture"] = "color/white",
["$color"] = "[0.08 0.34 0.16]"})` draws green through `surface.DrawTexturedRect`
and **pitch white** on a model. When a model is drawn the engine writes the
entity's render colour — `SetColor`, white by default — into the material's
`$color` for that draw, so whatever the material said is gone. `$color2` is the
tint the model renderer leaves alone; use it for anything applied with
`SetSubMaterial`. (The black market's monitor screens.)

## 31. `ix.log.AddType` exists on the server only

Helix defines it inside `if (SERVER)` in `sh_log.lua`. A shared file that
registers its log types at file scope errors on every client at
`attempt to call field 'AddType' (a nil value)` — and, worse, **stops loading
there**, so everything below the registration in that file is missing on the
client. `sh_blackmarket.lua` and `sh_squad.lua` both did it. Register log types
in a `sv_` file, or inside `if (SERVER) then ... end` at the very end.

## 32. A second `ixInventory` is "painted manually" while the main grid exists

`ixInventory:SetInventory` checks `ix.gui.inv1.childPanels`, and when that list
exists (Helix's inventory tab makes it) every window for another inventory is
given `SetPaintedManually(true)` and appended to the list. Helix's own menu then
paints those windows itself from its `Paint`. Any other menu — this schema's —
never calls `PaintManual`, so the window is created, sized, filled, on top, and
**never drawn**. A window opened outside Helix's menu wants
`SetPaintedManually(false)` straight after `SetInventory`. (The backpacks.)

## 33. A sequence with no root-bone data renders the model in its raw pose

The Sentry Vertibird's `idle` turns its root bones a quarter turn; its `spin`
(the props) carries no root data at all. Play `spin` and the whole airframe
draws in the model's bind orientation — nose along +Y instead of +X — while the
hull, the physics and every seat placed against the idle stay where they were.
Anything measured against a model (`FOVehicles.Read` poses a copy on its
sequence 0) is only true for the sequence the entity actually plays. Turn part
of a mesh by hand (`ManipulateBoneAngles`) rather than switching sequences.

## 34. A schema `TranslateActivity` that answers first must answer for seats

Helix's own `GM:TranslateActivity` is where a seated player gets
`ix.anim.<class>.vehicle[<seat class>]`. `Schema:TranslateActivity` answers
before it for the New Vegas model classes and returns a tree entry or nothing —
so a seated player, whose activity is `ACT_HL2MP_SIT`, found nothing in the
tree and stood up through the roof. Anything that takes over translation for a
model class takes over its seats too; check `client:InVehicle()` first.

## 35. Nine-way blend cycles need their pose parameters, or the NPC stands still

`mtwalk_npc` and `mtrun_npc` are nine cycles blended by `move_x`/`move_y`, and
the centre one is the idle, with no motion in it. An engine NPC playing that
sequence with the parameters at zero plays the centre cycle, reads a ground
speed of nothing, and never moves on any path it is given. VJ's
`UsePoseParameterMovement` sets the parameters from the move direction; it is
not optional for this model, and setting them by hand instead is not
equivalent. The flag also switches on `OverrideMoveFacing`, which is the only
thing that turns such an NPC to face its own waypoint, and an exemption that
keeps a FAIL_NO_ROUTE_ILLEGAL from throwing the schedule away. Turning it off
and driving `move_x`/`move_y` from the playing sequence cost all three: NPCs
that walked without looking where they were going, re-planned constantly, and
- because a standing NPC can be in a sequence that merely shares an activity
with a walk - marched on the spot against a stale waypoint. `IsMoving` asks
the navigator whether a goal is active, not whether the body has already
travelled, so there is no chicken-and-egg to solve here.

## 36. A delta sequence played as the body's animation shows nothing

Every attack and reload on the Phoenix human model is flagged `STUDIO_DELTA`
(`seqflags` 0x14 in the header): the recoil alone, authored to be layered as a
gesture over an aim pose by the player system. Hand one to an NPC as its main
sequence and the body shows the pose underneath it — arms at the sides, gun on
the floor, bullets coming out regardless. Anything that plays this model's
attacks must play them as gestures (`AddGestureSequence`; VJ's `vjges_` prefix)
over a stance that is a real looping sequence. `GetSequenceInfo(id).flags`
carries the bit at run time.

## 37. A call in the last argument position expands to all its return values

`tostring(a and f())` where `f` returns **nothing** hands `tostring` no
argument at all, not `nil`: a call in the final argument slot expands to every
value it returns, and zero values is a legal count. The error is
`bad argument #1 to 'tostring' (value expected)`, which reads like the value
was wrong rather than absent. Wrapping the call in parentheses truncates it to
exactly one value, `nil` included: `tostring((a and f()))`. VJ's
`CanFireWeapon` has paths that return nothing, and this killed `fo_npc_report`
half way through.

## 38. An NPC can have an enemy the engine thinks is neutral, and then it cannot chase

VJ Base picks its own targets and hands them over with `ForceSetEnemy`. That
sets `GetEnemy()` and nothing else, so an SNPC can be shooting at somebody its
**engine disposition** toward is still `D_NU`. It aims and fires perfectly,
because VJ is doing both, and it never takes a step, because the engine is
doing that part.

The engine's senses enter an entity into **enemy memory** only when the NPC
hates it, and `TASK_GET_PATH_TO_ENEMY` paths to the last known position out of
that memory rather than to the enemy's real position. With no memory there is
no last known position, so the task gets the map origin: the NPC either fails
to path or walks toward 0 0 0. In a report that shows up as a live enemy a few
metres away, a disposition of 4, and a waypoint of `0.000000 0.000000
0.000000`.

Worse, VJ pins the entity back to neutral every time it drops an enemy —
`ResetEnemy` calls `AddEntityRelationship(enemy, D_NU, 10)` — so it does not
stay fixed on its own. State the relationship yourself with
`AddEntityRelationship`, and re-state it while the enemy is held
(`ix.npc.Relate`, and the check in the NPC's `OnThink`).

## 39. A VJ human far from its enemy does not reload where it stands

With `Weapon_FindCoverOnReload` on, which is the default, a human more than
650 units from its enemy starts a `SCHEDULE_COVER_RELOAD` and reloads only in
that schedule's **finish** handler. Meanwhile the weapon state is set to
RELOADING by `SetWeaponState` with no time argument, which means no reset timer
at all.

So anything that stops the schedule finishing leaves the weapon reloading for
good: no cover found, no route to the cover, or any other schedule replacing it
- and a chase replaces it. The NPC then stands at zero rounds forever. It
cannot fire, and every one of VJ's combat behaviours skips it, because they all
begin by asking `CanFireWeapon`, which requires a READY weapon. In a report it
looks like `clip 0`, `weapon state 2`, and nothing fired for a minute.

Turn `Weapon_FindCoverOnReload` off for anything that is meant to press an
attack, and keep a watchdog on the state anyway.

Related: `playReloadAnimation` calls `StopMoving()` whenever the reload plays as
a **gesture**, which is deliberate on VJ's part and means a gesture-reloading
NPC drops its route on every reload. Anything driving a chase has to notice the
NPC has stopped and start it again, rather than trusting that a schedule which
is still named is still running.

## 40. VJ makes "unreachable" permanent, and the engine's chase task then refuses to try

The engine keeps a list of entities an NPC has decided it cannot get to, and
`TASK_GET_PATH_TO_ENEMY` fails **before attempting anything** when the enemy is
on it. The list is designed to be self-clearing: each entry expires on its own,
and is discarded the moment the entity moves more than about 120 units from
where it was written down.

VJ never lets it expire. The first failed path raises COND_ENEMY_UNREACHABLE,
`MaintainAlertBehavior` sees that and calls `RememberUnreachable(enemy, 2)`,
and from then on it re-writes the entry every two seconds because it is reading
its own note back. One failed path and that NPC will never again attempt to
walk to that player. `RememberUnreachable` also calls `ForceChooseNewEnemy` on
the way past, so each re-write drops the enemy too.

The symptom is an NPC that chases *sometimes*: the note clears when the player
walks far enough from where it was taken, so it works again until the next
failed path re-arms it.

Override `RememberUnreachable` to a no-op on your own NPC. The engine's
transient condition still works, and a genuinely unreachable enemy should be
chased with a task that paths to a **position** (`TASK_GET_PATH_TO_LASTPOSITION`
via `SCHEDULE_GOTO_POSITION`), which does not consult the list at all.

## 41. `a and b or c` is not a ternary when `b` can be false

`local ok = IsValid(x) and x:DoThing() or nil` prints `nil` for BOTH "did not
run" and "ran and said no", because `and`/`or` cannot tell `false` from
`nil`. In a diagnostic that is worse than no line at all: the one answer it
existed to give is the one it hides. Use an `if`. (The NPC path test, which
reported `can path to you nil` on a map where the engine had definitely
answered "no".)

## Things that look broken but are not

Before "fixing" any of these, read [15-decisions.md](15-decisions.md):

- **Fire rates** — measured on both realms; everything fires *slower* than
  configured. The difference from Phoenix is tick quantisation.
- **`SWEP.Type` vs `SWEP.Category` disagreeing** — different purposes.
- **The lowered pose being a file-local, not a SWEP field** — setting the field
  changes weapon accuracy.
- **`Error loading cfg/trusted_keys_base.txt`** — standard GMod noise.
- **`sv_setsteamaccount` warnings** — expected on a LAN dev server.

## Drawing an entity parented to a player

Use `Entity.RenderOverride`, not `PostPlayerDraw`.

A bone-merged part is a separate entity PARENTED to the player. Calling
`part:DrawModel()` from inside `PostPlayerDraw` re-enters the player render
path, which fires `PostPlayerDraw` again, and recurses until GMod stops it:

```
PostPlayerDraw: We are 10 layers deep, runaway infinite loop?
```

`RenderOverride` is called by the engine in place of the entity's own render, so
`DrawModel` inside it draws the mesh once and nothing re-enters. It is also the
only way to apply `render.SetColorModulation` to one part - `SetColor` clamps at
255 and cannot brighten past white.

## Finding a panel by its scripted class

`Panel:GetClassName()` does **not** return the `vgui.Register` name. It returns
the engine class — `Panel`, `EditablePanel`, `LuaEditablePanel` — so comparing it
against a scripted name never matches. GMod's own code shows both halves:

```lua
if (prnt:GetClassName() == "EditablePanel" ||
    prnt:GetClassName() == "LuaEditablePanel") then   -- dtextentry.lua
if (v.ClassName && v.ClassName == SeekingClass) then  -- derma.lua
```

`ClassName` is not a dependable substitute either: `derma.DefineControl` puts
the registered name on a `.Derma` **sub-table**, and panels registered with plain
`vgui.Register` may carry nothing usable at all. None of that is confirmable
from the Lua on disk — it is engine behaviour.

**So mark the panels yourself.** Where you already wrap a panel's `Init` — which
runs for every instance — set a flag and search on that. A flag you set is not a
guess about engine naming:

```lua
Wrap("ixMenuButton", "Init", function(panel)
    panel.ixIsMenuButton = true
end)
```

Getting this wrong is **silent**: the search just finds nothing, with no error.
It cost the character creation screen its faction proceed button — leaving that
step a dead end — and left the SPECIAL rows stubbornly alphabetical through two
separate attempts at reordering them, because the bug was in the detection, not
in either reordering method.

That is the tell: when two different fixes for the same symptom both change
nothing, stop improving the fix and check whether the code runs at all.

## Noclip puts you in observer mode

Helix's `observer` plugin turns noclip into something bigger. You **do** noclip
— the movetype is correct — but it also makes you invisible, non-solid, godmoded
and no-target, and on exit teleports you back to where you started if
`observerTeleportBack` is on, which it is by default. That last part is usually
what reads as "noclip isn't working": you fly somewhere, turn it off, and get
yanked back.

```bash
ix.config.Get("observerOnNoclip")   -- false: plain noclip (our default)
                                    -- true:  Helix's observer mode
```

Set it in the Helix config menu under **Server**. With it off, the plugin
declines and control falls through to `GM:PlayerNoClip`, which is
`return client:IsAdmin()` — plain admin noclip.

### Neither obvious way to override it works

Helix replaces `hook.Call`, and the order is **not** GMod's:

```lua
HOOKS_CACHE[name]   -- every PLUGIN hook, first
Schema[name]        -- the schema, second
hook.ixCall(...)    -- ordinary hook.Add listeners, last
                                    -- core/libs/sh_plugin.lua
```

Each stage returns early on the first non-nil value. The observer plugin's
`CanPlayerEnterObserver` returns `true` for anyone with the privilege, so a
`hook.Add` listener — or even a `Schema:CanPlayerEnterObserver` — **never runs
at all**.

`HOOKS_CACHE` is a global holding the exact function reference that stage calls,
so replacing that entry is what changes the answer. The original is kept and
still consulted when the config is on, leaving observer mode intact rather than
deleted.

This is worth remembering generally: **a plugin hook that returns a value cannot
be overridden by `hook.Add`, or by the schema.** Patch its cache entry, or
change the plugin.

## 42. Phoenix's gestures blend on `standing`, and nothing sets it

Every attack and reload on `models/phoenix/humans/animations.mdl` is a 2x1
blend on the pose parameter `standing`, which runs from 100 (the `_stand`
animation, such as `2hrattack7_stand`) to 0 (the `_move` one). Neither the
engine, Helix, VJ Base nor this schema ever sets it, so it stays at the 0 end
and every shot and reload plays the version made for walking, whether the
character is walking or not. Set it yourself: 100 while still, 0 while moving.
The players' own gestures, played from `sh_hooks.lua`, do not set it either.

The aiming on this model is not a blend on the base sequence either. The
aim-yaw and head layers are AUTOPLAY sequences the engine adds to everything,
and each aim stance brings its pitch layer as an autolayer (`2hraim` ->
`2hraimpitch`), so driving `aim_pitch`, `aim_yaw`, `head_pitch` and `head_yaw`
is all it takes. VJ drives them only while its own weapon-attack state is set;
see the NPC's `UpdatePoseParamTracking`.

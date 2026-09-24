# 29 - Materials and item stacking

## Stacking happens on the way in

`ix.stack` could always merge two stacks — you drag one onto the other — and
nothing ever did it for you, so forty ore out of one node was forty slots.
`libs/sv_autostack.lua` fixes that in two places:

- **`Inventory:Add` tops up existing stacks first**, wrapped on
  `ix.meta.inventory`. If the whole amount fits into what you already carry, no
  item is created and no slot is needed — which also means a nearly-full bag
  can still take ore.
- **`InventoryItemAdded`** merges anything that *arrives* as an existing
  instance: picked up off the floor, taken out of a container.

Two things are deliberately left alone: **moving a stack around your own
inventory** (welding it to whatever it landed next to is the sort of help that
undoes the split you just made) and **`ix.stack.Split` itself**, which is
guarded by a flag while it runs — without it, splitting would merge straight
back and be a no-op.

Only the plainest adds are intercepted: a uniqueID, no data, no requested slot,
and a stackable item. Anything carrying data — a weapon with ammo, a collar with
a deadline — goes through Helix's own path untouched.

---

**114 items.** Phoenix's whole `items/junk` folder plus 31 they do not
have, less the fusion core - that one is hand-written at
`items/sh_junk_fusioncore.lua` because it carries behaviour a roster entry
cannot express, and having it in both places registered one item twice.
Generated:

```bash
python _docs/tools/genmaterials.py
```

| | |
|---|---|
| `_docs/tools/materials.py` | the roster |
| `libs/sh_stack.lua` | quantities, merging, splitting |
| `items/base/sh_material.lua` | the base: combine, split, the icon count |
| `items/material/` | 114 generated items |

| category | count |
|---|---|
| Materials | 68 |
| Valuables | 18 |
| Schematics | 18 |
| Access | 6 |
| Junk | 5 |

77 stack, 38 are one of a kind.

---

## Helix has no quantity, so stacking had to be built

An item there is one thing: five pieces of steel are five items in five slots.
Phoenix add `isStackable` and `maxQuantity` to theirs, and `libs/sh_stack.lua`
is the same idea written against Helix.

**The count lives in item data**, not in a new column. `item:GetData` is the
`data` field on `ix_items`, so a stack survives being dropped, put in a
container, and a restart — and nothing had to be added to the database schema
to make that true.

**Stacking is a gesture, not an automatic.** Dragging one onto another merges
them, and Helix already has the mechanism: `ITEM.functions.combine` is called on
the item being dragged *onto*, with the id of the one being dragged. Merging
silently on pickup would take the choice away, and an inventory that rearranges
itself while you are looking at it is worse than one that does what you told it.

**Helix's drag could not deliver the gesture**, and that took a diagnostic to
establish rather than a re-read. `PaintDragPreview` picks the combine target
with `vgui.GetHoveredPanel()`, but the dragged icon holds mouse capture — so
vgui calls *it* the hovered panel whatever the cursor is over, `combineItem` is
never set, and the drop does nothing at all. `libs/cl_stackdrag.lua` sets the
target from the grid cell instead. See `30-benches.md`.

`combine`'s `OnRun` returns **false** deliberately. Helix removes the item a
function ran on unless the result is `false` — and the item it ran on is the one
that just *gained* the stack.

### Five, unless the item says otherwise

`ix.stack.max` is 5. `ITEM.maxQuantity` overrides it per item;
`ITEM.isStackable = false` means it never merges at all.

**That distinction is the interesting one.** A bar of steel is a quantity of a
substance and five of them in a slot is the truth. An Enclave access pad is one
specific object, and two of them sharing a slot would be a lie about what is in
the room. The roster says which is which, item by item — the six access pads,
every schematic, the snow globes and the Platinum Chip are all one of a kind.

### Splitting

`Split` prompts on the **client** and sends its own message, because `OnRun`
runs on the server with no way back to the person who clicked. `OnClick`
returning false is what stops Helix also running the server action.

The new item is created **before** the original is reduced: an inventory with no
room leaves the stack exactly as it was, rather than destroying part of it and
failing to place the rest. The server checks the item is in the character's own
inventory, so it is not a way to reach into a container somebody else is at.

---

## Models

**Five of Phoenix's are not installed here** and are substituted rather than
dropped: their blueprint paper, an Anchorage barrel, two gore props, and the
mining prop they use for every ore. The generator checks every path against disk
and refuses to write a missing one.

**Nothing shares a model without a way to tell it apart.** Thirty-one component
models cover sixty-eight materials, so the seven ores all look alike and a bronze
bar uses the copper model. Same answer as the chems: a small square of the item's
own colour in the corner of the icon. The generator reports any group of two or
more untinted items sharing a model, and the roster has none.

The sixteen schematics that were all one sheet of blueprint paper now use five
different paper models plus tints.

## What Phoenix do not have

The component model pack ships nine materials their roster never used —
**aluminium, antiseptic, asbestos, bone, concrete, cork, fertiliser, fibre
optics and lead** — plus sixteen more from the junk pack that are real Fallout
crafting components with dedicated models: vacuum tube, military circuit board,
sensor module, relay coil, high-powered magnet, makeshift battery, Wonderglue,
turpentine, cotton yarn, tanned hide, deathclaw hide, molerat teeth, bloatfly
gland, fuse, coolant and pre-War money.

And six **access pads** — Enclave, Brotherhood, CIT, Vault-Tec, NCR and Big MT.
They exist to be the thing `isStackable = false` is for.

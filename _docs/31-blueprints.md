# 31 - Capturing benches, frames and blueprints

Two systems on top of `30-benches.md`.

| | |
|---|---|
| `libs/sv_benchcapture.lua` | taking a bench |
| `libs/cl_benchcapture.lua` | the bar along the bottom of the screen |
| `libs/sh_blueprint.lua` | what a character knows, and what things cost |
| `libs/sv_blueprint.lua`, `cl_blueprint.lua` | learning, and the admin's edits |
| `libs/sh_blueprintdefaults.lua` | **generated** - 259 starting recipes |
| `items/base/sh_frame.lua`, `sh_blueprint.lua` | the two bases |
| `derma/cl_blueprintconfig.lua` | BLUEPRINTS, from `/benchconfig` |
| `_docs/tools/blueprints.py`, `genblueprints.py` | the roster and the writer |

```bash
python _docs/tools/genblueprints.py
```

`/benchrelease` hands a captured bench back to nobody. Admin only.

---

## Capturing

Per bench type: **capturable**, and **how long it takes**.

```
press E        told what it costs, and nothing happens
press E again  it starts, and whoever holds it is told by name
stand there    a bar counts down at the bottom of the screen
walk away      it stops, and the progress is gone
```

**Two presses, deliberately.** The first is a warning and does nothing at all.
Starting a fight is not something to do by walking into a prop and holding the
use key out of habit. Phoenix start capturing on the first press; the person
who finds out afterwards is the one who did not want to. The warning expires
after twelve seconds, so one read a minute ago does not become consent now.

**It announces itself.** The holder is told the moment somebody starts, by
name. That is the whole of "you will be KOS" — not a flag on a character, but
the fact that the people who own the thing now know who you are and where you
are standing. A capture nobody can contest is just a timer.

**A default faction holds nothing.** `FACTION.isDefault` marks the faction
nobody joins deliberately — Wastelanders here — and "everyone who has not
picked a side" is not an organisation that can own a workbench. Taking one as a
Wastelander would hand it to every unaffiliated character on the server at
once, which is the opposite of what capturing it meant. So they hold it
personally; everybody else holds it for the people they answer to, which is
what makes losing one matter to somebody other than whoever was standing there.

**Progress is not saved.** A capture is a thing you are doing right now. It
lives on the record in memory and dies with a disconnect, a death, a map change
or a step too far. Only the result — who holds it — is written down.

Watched on a tick rather than a timer, for the reason `30-benches.md` gives
about Phoenix's own workbench timers: a timer would have to be cancelled from
every place a capture can end, and that list is never complete.

**Admins capture like anybody else.** There was a bypass letting them straight
through to the window on any unheld bench — and it made the feature untestable
by the only people who can place one: pressing E as an admin opened the menu and
no capture ever started, which reads as capturing being broken rather than as
being skipped. The C menu's "[ADMIN] Open this bench" is the way in that does
not touch ownership, so the bypass bought nothing and hid the system from the
person building it.

---

## Frames and blueprints

**259 weapons**: 218 ranged that were already items, and **41 melee that were
never itemised at all**. Each gets a frame and a blueprint; the melee ones also
get a weapon item, matched to a real world model.

**Nothing here is a list to maintain.** The roster is *read* from what is
installed — the item files for the ranged weapons, the SWEPs for the melee
ones, and the melee world models off disk. A weapon added tomorrow gets a frame
and a blueprint by running the generator again, and one removed stops having
them.

The melee SWEPs point `WorldModel` at `w_crowbar` and `ViewModel` at a `c_`
hands model, so neither is usable as an icon. The real models live in the
fallout packs under `weapons/world/melee/` and are matched by name, with an
alias table for the dozen that do not lead to their own model — `machetegladius`
is the gladius, `policebaton` is the baton, the gauntlets share the one gauntlet
model that shipped. The laser katana has no model in any installed pack and
borrows the Chinese officer sword: a plain sword shape is a better lie than an
ERROR checkerboard.

### Why frames exist

Without them, crafting a weapon costs generic materials and every weapon is
worth the same pile of steel. With them, making an anti-materiel rifle needs an
anti-materiel rifle's frame, and where that came from is a question with an
answer. It is the difference between crafting as a shop with extra steps and
crafting as a reason to go somewhere.

### Knowledge is on the character

Using a blueprint teaches it and destroys the paper. Keeping the paper as the
licence would mean carrying a folder of schematics to be able to craft, losing
them all to one death, and being unable to sell a duplicate. It lands in
`character:GetData("blueprints")`, so it survives a restart with everything
else on the character and needed nothing added to the database.

`OnRun` returns **false** when learning fails — Helix destroys the item a
function ran on unless the result is false, and a blueprint that taught nothing
must not be consumed for it.

### A blueprint bench has no recipe list of its own

`ix.bench.Recipes(definition, client)` is the one accessor. Every other bench is
a fixed menu; a blueprint bench offers what the person standing at it knows, so
two people at the same bench see different things.

Sorted by weapon id, because an index sent from the client has to mean the same
thing on the server — name order or learn order would differ between the two
the moment a weapon was renamed or a second blueprint learned.

**The job carries its own output**, not just an index. On a blueprint bench the
list belongs to the character, so an index is only meaningful next to the
person who sent it: they can learn another blueprint, log off, or be replaced
at the bench by somebody who knows a different set, and the same index would
then finish as a different weapon. Snapshotting what was queued is also what
lets a job survive a restart.

A blueprint bench must be a **Crafting** bench. The other two modes run with
nobody standing at them, and "what this person knows" has no answer then.

### The defaults are generated, not derived twice

`sh_blueprintdefaults.lua` is written by the same tool that writes the frames,
so the number the server charges and the number the client displays come from
one file. Working the formula out again in Lua would be a second implementation
to keep in step, and the one that drifts quietly is the client — which would
offer crafts the server then refuses.

Only the admin's **overrides** go over the wire. Shipping all 259 recipes to
every client on join would carry information it can read off disk.

### Icons: three models and a coloured border

Two non-melee groups and one melee group, named directly rather than derived:

| | blueprint | frame |
|---|---|---|
| pistols and revolvers | `blueprint.mdl` (1x1) | modkit by size |
| everything else ranged | `schematic.mdl` (2x1) | modkit by size |
| melee | `burntmagazine.mdl` (2x1) | `components/wood.mdl` |

Revolvers count as pistols — they are handguns, and a revolver blueprint that
looked like a rifle's would be the odd one out for no reason anybody could
name.

**Frames are chosen by size, not by type**, because a modkit is a modkit and
how big it is is the only thing the icon can honestly say about it:
`modkit_sml` at 1x1, `modkit_med` at 2x1, `modkit_lrg` at 3x1 or larger. All
pistol frames are 1x1; everything else follows the weapon's own size, so a
minigun's frame does not fit where a pistol's does.

**The difference between two of them is a coloured border**, reusing
`ix.rarity.PaintBorder` — the same border a crafted weapon draws for its
quality, so the two mean the same thing visually. A corner swatch does not read
across a full inventory; an edge does.

Phoenix give every blueprint the same sheet of paper and every component the
same lump; 518 identical icons is an inventory you read one tooltip at a time.
There is no per-weapon receiver prop in any installed pack, so the icon cannot
be the weapon. The border colour comes from the weapon's type — read from the
SWEP's own `SWEP.Type` — with a narrow deterministic shade inside each type, so
two pistol frames are not indistinguishable but still read as both being pistol
frames.

The two-wastelands paper models are deliberately unused. That pack nests its
content at `models/models/...` and the path the game wants is not the one the
file tree reads like — see `30-benches.md`.

### Frame size is a setting

A rifle frame that takes the same two slots as a pistol frame is a bag that
tells you nothing about what is in it, and the right size per weapon is a
balance question rather than a fact — so it is editable in BLUEPRINTS rather
than a number in a generated file that the next run would overwrite.

It writes onto `ix.item.list` directly, because Helix reads width and height
off the item table when it places anything and there is no per-instance size.
Applied on **both** realms: the server places into the grid and the client
draws the icon, and a disagreement about the size is an item that cannot be
picked up where it appears to be. That is also why it saves on change rather
than behind SAVE — it is a property of an item, not of the recipe.

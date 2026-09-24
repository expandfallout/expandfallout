# Mining

Ore nodes placed around the map, hit with a pickaxe until the ore in them runs
out, growing back on a timer. Phoenix's `mining` plugin; their server half is not
in the scrape, so what a hit is *worth* is ours.

The content comes from `phoenix_mining_content`, junctioned into `addons/` —
content-only, so it is within the addon rules in `02-server-setup.md`.

---

## What a node is

**Kilogrammes, not uses.** A node holds an amount of one ore, an ordinary swing
takes `miningKgPerHit` (1.5) off it multiplied by the ore's own hardness, and
every `miningKgPerOre` (5) that comes off pays out. **How much it pays** is
`miningOrePerDrop` (1), or the ore's own `Per drop` if it has one — two dials
rather than one, because how *often* ore comes out and how *much* are
different decisions, and three every ten kilogrammes feels nothing like one
every three. The model
shrinks through Phoenix's five bodygroups as it empties, and the label over it
counts down in `12.5kg`.

**The soft spot is the game.** It is Rust's, and Phoenix's `nutMiningSendGSpot`
is the same idea: an **orange** glow on the rock worth `miningSoftMultiplier`
(3) ordinary hits, which moves the moment you strike it. It is one colour
whatever the ore is — it was the ore's own colour, which made iron's spot
white on grey rock and nearly invisible.

**It sits on the surface, found by a trace.** The first version picked a point
inside the bounding box, and a bounding box is not a rock: the spot floated in
the air beside the node as often as not, and when it did land on the model it
could land *inside* it where nothing can hit it. It now traces from a random
direction back towards the centre with a filter that ignores everything except
that node, so the first thing it can hit is the rock's own surface. It also
moves when the node shrinks a stage, or it would hang where the rock used to
be. Mining without looking still works; mining well is three times faster. It is
a networked *vector* rather than Phoenix's net message, because it is state, not
an event: somebody who walks up after it moved should see where it is now.

**Progress is on the node, not on the person.** Two people working the same rock
are digging the same hole; their swings add up and whoever crosses the threshold
gets the ore. Anything else rewards standing back while somebody else softens it.

**No room, no loss.** If your bag is full, the kilogrammes are already off the
rock, so the progress is put back rather than dropped — come back empty-handed
and the next swing finishes it.

**Emptied nodes go, and the record keeps the clock.** The same decision the cap
stash made: a node waiting to come back has no entity to run a think, so the
wait belongs to the record, and it is `os.time` because `CurTime` restarts at
zero on every map load (gotcha 11).

---

## Placing them — the `fo_mining` toolgun

| | |
|---|---|
| left click | place a node, or apply the panel to one you are pointing at |
| right click | remove it |
| reload | move the soft spot — for testing, and it is the thing you want to watch while tuning |

Per node: **ore**, **kilogrammes in it**, **seconds to come back** (which
overrides `miningRespawn`). The ore dropdown is built from the live list, so it
shows whatever `/MiningConfig` currently says.

Nodes are saved **per map**, with the same `LoadData` / `PostLoadData` / timer
and save-guard pattern the points use. `/MiningNodes` lists them with what is
left in each and how long until the empty ones return — and so does
**`/Points`**, prefixed `ore:3`, because "the thing I want to delete is not
standing there any more" is the problem the points already solved and a mined
out node has no entity to point a tool at. `/PointDelete ore:3` removes one.

Needs the `mining.edit` permission, registered shared so it appears in the rank
editor.

---

## `/MiningConfig` — the ore list

The ores are **data, not a table in a source file**: id, name, the item one ore
gives, hardness, node skin, and the colour its soft spot glows. Editable in
game, saved **globally** rather than per map — "gold is worth 0.75 and uses skin
4" is a decision about the server, not about a map.

- **Nothing is saved until SAVE is pressed.** The window holds a copy and the
  server only ever receives the whole list at once, so a half-finished edit
  cannot reach it.
- **Per drop and Sweet spot x are per ore.** A zero in either means "use the
  config", so the global dials still move everything that has not been given
  a number of its own — a rock that should be all about the sweet spot gets a
  six, one that should reward patience gets a one.
- **Hardness and hits are the same number, both editable.** Nobody tunes a
  rock by thinking "times one point two five" — they think "how many swings
  is this". Editing either rewrites the other, against a 25kg reference node.
- **The item is checked as you type it.** An ore pointing at an item that does
  not exist is a node that swallows every swing and gives nothing, and there is
  no way to notice that in game except by mining one dry.
- **Saving re-reads every node**, so an ore that changed skin or vanished does
  not leave rocks showing the old one until a restart.
- The list can never be empty — a node with no ore to be is a node that cannot
  exist, so an empty save falls back to the seven defaults.

The seven defaults are Phoenix's, with their skins and strengths, pointed at the
`mat_ore*` items this schema already had.

### The ore items

They are back on Phoenix's own model — `zrms_resource.mdl`, one model with five
bodygroups — which was substituted out of the materials roster when the mining
content was not installed. Seven ores across five looks, so two pairs share one;
the tint square in the corner is what tells those apart, which is what the tint
is for. All of them stack to five, like every material.

**Helix has no bodygroup support**, only skins — `libs/sh_itembodygroup.lua`
adds `ITEM.bodygroups = {[0] = 3}` by wrapping the two places that need to know:
`ix_item:SetItem` on the server (bodygroups are networked entity state) and
`ixItemIcon:SetItemTable` on the client, which runs just after the icon's model
is set.

---

## Configuring the rest

Dev terminal → **WORLD** → MINING, with a button that puts the node tool in your
hand and another that opens the ore list:

| Config | Default | What it is |
|---|---|---|
| `miningKgPerHit` | 1.5 | kg an ordinary hit takes, before hardness |
| `miningSoftMultiplier` | 3 | what a soft spot hit is worth, in ordinary hits |
| `miningSoftRadius` | 12 | how close a hit has to land to count |
| `miningKgPerOre` | 5 | kg that must come off before ore drops |
| `miningOrePerDrop` | 1 | how many ore each drop gives, unless the ore says |
| `miningXP` | 2 | experience per ore |
| `miningRespawn` | 600 | seconds an emptied node takes to return |
| `miningStrength` | 1 | a multiplier on every swing — the quickest global dial |
| `miningTool` | `meleearts_blade_pickaxe` | what can mine. **Blank means anything** |

Phoenix hard-code the pickaxe in their damage handler; making it a config means
a second pickaxe, or a drill, needs no code.

---

## Two things that are not Phoenix's

**The sounds.** Theirs are `physics/concrete/concrete_impact_*` — Half-Life 2
paths, and this server has no HL2 content (gotcha 16). The hits use the mining
addon's own `zrms/machine_crush.wav` and the Fallout UI sounds.

**The method names.** `ApplyRecord`, `ApplyShape`, `MineFor`, `OreData` rather
than `Configure`, `Reshape`, `Mine`, `Ore`. See gotcha 17: a scripted entity
method called `Respawn` answers nil in this build however it is written, nobody
found out why, and it cost three rounds of debugging on the plants. The farming
entities are named the same careful way.

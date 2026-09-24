# Plants and seeds

Wasteland flora you press E on for the fruit and some experience, twenty edible
plant items with Phoenix's effects, and the seventeen bags of seeds the farming
system will need when it is written.

---

## Placing them — the point tool

**A plant is a point.** `sh_points.lua` already defines a point as "a thing a
map-maker places one of at a time … an object you walk up to and press E on",
which is exactly what a plant is — so plants are a fourth point type rather
than a system of their own, and they inherit:

- the `fo_point` toolgun, and its Reload-applies-everything behaviour
- per-map persistence with the save guard that stops an empty load overwriting
  the file
- `/Points`, `/PointDelete`, `/DropPoints`
- protection from map cleanups
- `point.edit` permission

Phoenix's `plants` plugin wrote its own version of all of that. The only thing
added to the point system here is the type.

On the tool: **Which plant** (17 kinds), **Seconds to grow back** (300),
**How many it gives** (1), **Experience it gives** (-1, meaning "use the
config"), **Players collide with it** (off). Reload with the tool changes an
existing plant's kind, and the model changes with it.

Experience is per plant *and* server-wide: a plant that says nothing follows
`plantXP`, and one with a number of its own keeps it whatever the config is set
to afterwards — so something rare at the bottom of a cave can be worth more
without making every plant worth more.

> Their `collisions` flag is inverted in their own code —
> `if collisions then COLLISION_GROUP_DEBRIS`, and debris is the group that
> does *not* collide with players. Ours means what it says.

Leave the tool's **Model** box blank: a plant picks its own model from its kind,
and a model typed in there overrides that and stays put when the kind changes.

## Harvesting — `ix_plant`

E gives the item (`How many it gives` of them, or as many as fit), plays a
pickup sound, throws the green particle, awards `plantXP` (10), and sets bodygroup 1
so the fruit is gone and the stalk is left.

**The regrow deadline is `os.time`, it lives on the record, and the wait is
counted by `ix.points.Tick`.** All three of those are the cap stash's lessons,
and the third was learned again here: the first version put the wait in an
`ENT:Think` that re-armed itself with `NextThink`, and the fruit never came
back. Rather than a fourth round of guessing which half of the think scheduling
was not firing, the wait moved to the place this codebase already keeps every
other one — a plain one-second timer over the *records*, the same one refilling
the cap stashes, which cannot be stopped by an entity being asleep, moved or
briefly invalid. `ENT:Ripen` is what it calls.

**The root cause of all of it was the method's name.** `ENT:Respawn()` returned
nil however it was written, so the deadline was `now + nil`, the write threw,
and the engine's use handler swallowed it. With the call *after* the sound and
the XP that read as "it never grows back"; moving it *before* them to protect
the write moved the throw with it, and the harvest went silent and stopped
paying XP as well. One fault, three symptoms, three rounds of looking in the
wrong place. It is `RegrowTime` now — see gotcha 17, which is the same wall the
cap stash hit.

**The deadline is written before anything else.** It used to be the last thing
in `ENT:Use` — after the sound, the particle, the experience and two
notifications — so *any* of those throwing (and `AddXP` can level somebody up,
which is a lot of code) left a plant marked picked with no deadline, and the
tick then put the fruit straight back. The two lines that decide what the plant
*is* now come first, with nothing between them that can fail.

**The harvest sound was silent**, which made a working harvest look like a
broken one: it was Phoenix's `physics/flesh/flesh_squishy_impact_hard1.wav`,
and this server has no Half-Life 2 content at all. See gotcha 16 — every sound
path is checked with `resolve_asset.py` now.

**The tick counts itself.** `fo_point_report` prints `ticks:` and `ripened:`
alongside every plant's picked state, deadline, respawn, yield and XP, because
"it does not grow back" has two causes that look identical from in game — the
tick not running, or the plant not answering it — and one line of output tells
them apart.

**A missing deadline is not a deadline that has passed**, either. `Ripen` used
to treat "no deadline" as "due", which turned any failure to record one into a
plant that regrew on the very next tick, for ever; now it writes one and waits.

`CurTime` restarts at about zero on every map load, so a plant picked four
minutes before a restart would otherwise come back instantly, for ever. Written
on the record as `os.time`, a plant picked before a restart is still picked
after one. The deadline's arithmetic reads its operands into locals first, for
the reason gotcha 12 exists — and it writes to `self.ixRecord` rather than
`self:Data()`, whose `or {}` fallback is a *fresh table every call* and would
have swallowed the write.

The plant **stays and the fruit goes**, which is the opposite of the cap stash
being removed outright. A stash *is* its caps; a picked bush is still a bush and
still tells you where to come back to.

## The 17 kinds

Broc Flower · Xander Root · Jalapeño · Barrel Cactus · Coyote Tobacco · Honey
Mesquite · Prickly Pear · Cave Fungus · Banana Yucca · Banana Yucca Tree · Brain
Fungus · Maize · Nevada Agave · Pinto Root · Sacred Datura · Buffalo Gourd ·
White Horsenettle

Exactly Phoenix's list, with their models. Banana Yucca and Banana Yucca Tree
share an item on purpose — the same fruit on a bush and on a tree.

**Eleven duplicates were removed from `items/food/`.** The bulk food conversion
had already produced a Xander Root, a Broc Flower, a Carrot and eight others —
all of them 10 sustenance, 4 hydration, 1 radiation and nothing else, because
that is what the converter gave everything. The plant versions carry Phoenix's
real numbers and their effects (the Xander Root heals; the Brain Fungus puts you
on the floor), so the plants stayed and the food copies went. Nothing referred
to the deleted ids in code or in saved data — checked before deleting, not
after.

---

## The items — `items/plant/`, base `base_plant`

`ITEM.base = "base_food"`. A base item may have a base of its own and
`ix.item.Register` merges it after the file is included, so eating, feeding
somebody else, sustenance, hydration, radiation and the `/me` line are all the
food base's, unchanged.

**The effects are data here and were code in Phoenix.** Theirs writes a closure
per item — twenty copies of four shapes, each free to drift, and two of theirs
already had (the same hint timer with and without an `IsValid` check, and one
plant's `eatMeText` describing a different plant). Here an item says
`ITEM.heal = {1, 1, 10}` and the base decides what that means, once:

| Field | Theirs | What it does |
|---|---|---|
| `heal = {amount, interval, count}` | `nut.rib:slowHeal` | health back slowly |
| `hallucinate = seconds` | `nut.rib:makeSchizo` | see below |
| `knockout = seconds` | `setRagdolled(true, 15, 15)` | you fall over |
| `ignite = {min, max}` | `Ignite` | the jalapeño, and only the jalapeño |
| `gamble = {...}` | Coyote Tobacco's coin flip | +10 DR for two minutes, or the floor |
| `chemHint = true` | a four-second-late chat line | "could be a chem ingredient" |

**Any plant can be eaten, which food cannot say.** The food base decides between
Eat and Drink by the stats, and nine of these twenty restore neither hunger nor
thirst — under that rule they would have had no button at all. `base_plant`
replaces `Eat.OnCanRun` only; `table.Merge` recurses, so the food base's `OnRun`
is still what runs.

**Hallucinating is a buff, not a URL.** Theirs streams an mp3 from
`files.catbox.moe`; an external host going down would take the effect with it,
and a URL inside an item is a thing nobody can audit. `ix.plants.Hallucinate`
applies a buff called `Hallucinating` (SPD -10, so it names an honest stat), and
`ix.chemfx.chemEffects` — the chem system's own table, rebuilt from live buffs —
carries `{"euphoria", "toytown", "blur"}` for it. The HUD then says what is
happening to you, which theirs does not.

**No plant or seed sets an `ITEM.price`**, and none of them are in any shop -
pricing is a design decision rather than something to port or invent. See the
note in [37-restraints.md](37-restraints.md) for what `ITEM.price` actually
does in this schema.

Two model paths are ours: their Tarberry and Tato are at
`models/fallout/consumables/`, which this server does not have. The same models
exist in `phoenix_dickmosi_stuff`.

### Regenerating

```bash
python _docs/tools/genplants.py
```

20 plants and 17 seeds, from the data table at the top of that file. Edit the
table, not the items.

---

## The seeds — `items/seed/`, base `base_seed`

> **They do something now** — the farming system exists, and a seed is planted
> by using it on a crop plot or dropping it on one. See
> [39-mugging-and-farming.md](39-mugging-and-farming.md). The note below is why
> they were shipped before it.

**Seventeen bags that did nothing at first, on purpose.** Phoenix's seeds belong to
their `farming` plugin — four entities (`nut_farm_planter`, `nut_farm_seed`,
`nut_farm_plant`, `nut_farm_water`), a water economy and a growth clock. That is
a system of its own and a later job.

The seeds are here anyway because they are *data*: which crops exist, what each
grows into, what it is called. Loot tables and vendors need that list settled,
and having it settled means the farming system arrives as a set of entities
rather than as entities *and* thirty-four items nobody has checked.

`ITEM.plantType` is the whole contract — the uniqueID of the plant item a seed
eventually yields. There is deliberately no "Plant" button that says "not yet":
a button that refuses reads as broken rather than as unfinished, and it would be
the first thing anybody tried.

---

## Configuring it

Dev terminal → **WORLD** → PLANTS: how many plants are placed, a button that
puts the point tool in your hand set to plants, and `plantXP`. How many one
gives and how long it takes to grow back are per plant, on the tool.

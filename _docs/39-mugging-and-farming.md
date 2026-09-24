# Mugging and farming

Two systems that finish two older ones: mugging is what the zip tie was always
for, and farming is what the seeds were waiting on.

---

## Mugging — `sh_mugging.lua`, `sv_mugging.lua`

**Mug** appears in the hold-E menu on anybody restrained — zip tie, cuffs or the
addon's elastic restraints, since `ix.restrain.Is` answers for all three. It is
a stared action: look away and it stops.

**The mugger is the one who gets marked.** That is the part people get
backwards. Robbing somebody does not make *them* killable; it makes *you*
killable, by them, for `mugPKTime` seconds — and this schema already had
`ix.pk` for exactly that.

**The victim is told, in blue, and only the victim:**

> **[PK]** You have a PK reason on Vault Dweller for robbing you of 300c.

The mugger is *sent* rather than named server-side, because `GetCharacterName`
is the recognition hook and only exists on the client — composing that sentence
on the server would hand out a name nobody was ever given. A stranger is
described as a stranger.

### What it takes

Phoenix's five bands, by the **victim's** level (their config text says "a
player with level 10-19", so the number is what that person is worth):

| Level | Config | Default |
|---|---|---|
| below 20 | `mugCaps10` | 100 |
| 20+ | `mugCaps20` | 200 |
| 30+ | `mugCaps30` | 300 |
| 40+ | `mugCaps40` | 400 |
| 50+ | `mugCaps50` | 500 |

Then **Charisma comes off the top** — `mugCharismaPercent` (2) per point of the
*victim's* Charisma, so a very charming character keeps a fifth of what a blunt
one loses. That is not Phoenix's; it is the SPECIAL contract ("Charisma lowers
mugging caps") and this is the only system that can honour it.

Whatever is left is capped by what they are actually carrying. Robbing somebody
broke still works and still gives them the PK reason — it just pays nothing.

Also configurable: `mugTime` (5), `mugCooldown` (60, before the mugger can do it
again) and `muggedCooldown` (60, before the victim can be done again).
Cooldowns live on the player rather than the character: they are short, they are
about the person, and none of that is worth a database write.

---

## Farming — `sh_farming.lua`, `sv_farming.lua`, `ix_cropplot`, `ix_crop`

Phoenix's `farming` plugin: a nine-slot planter, seeds, water, crops that grow.

- **The plot is a deployable.** The `Crop Plot` item places one with the same
  ghost the workbenches use. The item is consumed by the *server* when the plot
  actually exists, never by the client — a placement refused for being in a wall
  must not cost you the plot.
- **A seed goes in two ways**: Use it while looking at a plot, or drop it on
  one. Both end up in `ix.farming.Give`, so a seed cannot behave differently
  depending on how it got there. Same for the water canister.
- **Nothing grows without water.** That is Phoenix's rule and the whole game of
  it: `farmWaterDrain` (0.05) per second *per planted crop*, out of
  `farmWaterMax` (100), refilled `farmWaterRefill` (25) per canister.
- **A plot can only be watered when it is dry** — not "when it is not full".
  Topping one up whenever you walk past makes the water a formality; making
  you wait until it runs out is what turns watering into something you come
  back for.
- **E on the plot harvests everything ripe** for `farmYield` (3) each and
  `farmXP` (1) per crop.
- **Seeds and canisters are used up.** No refilling, no getting them back.

### The partial harvest

Phoenix count your free slots first and refuse the *whole* harvest if the yield
will not fit, so a full bag costs you the entire plot until you go and empty it.
Here each crop is tried in turn and the first one that will not fit stops the
harvest — everything already taken stays taken, and what is left is still ripe
and still standing. A crop that yields *nothing* is never removed.

### The bars

The water bar floats above the plot, from the model's own height rather than a
guessed offset, and **every crop gets a growth bar over it** — both drawn by
the PLOT while you look at it or at anything standing in it.

The crops used to draw their own and mostly did not: a crop is parented and
not solid, so a trace never returns one — the plot is what the crosshair finds
— and the fallback of measuring the trace's hit position against each crop was
a twelve-unit window nobody could hit deliberately. The plot knows where its
crops are and can see all nine at once.

### Two things worth knowing

**Removing a plot used to bring it back.** `Entity:Remove` does not remove
anything immediately — the entity goes at the *end of the tick* — so
`ents.FindByClass` a line later still returned it and `IsValid` was still true.
Picking a plot up therefore removed it and then saved it, and it was standing
there again after the next restart. The plot is marked `ixRemoved` before it
goes, the save skips anything so marked, and the save itself is deferred a tick.
Either alone would do; both together mean a third way of removing one cannot
reintroduce it.

**Plots do not survive a restart, and that is `farmPersist` (off).** Phoenix's
planters are ordinary props and are gone with the map, and so are these: a plot
is a thing you put down for an evening. They used to persist — my decision, not
a requested one — which is why the setting exists rather than the code simply
not saving. With it **off**, `ix.farming.Load` clears the file and spawns
nothing, so the plots from the last session are gone the first time the server
comes up after the change.

Turned **on**, the whole save comes back: positions, water, and every crop at
the growth it had reached, per map. Same pattern as the points — `LoadData`, a
`PostLoadData` and a timer as belt and braces, and a save guard so a load that
never ran cannot write an empty table over the file. Changes save immediately;
growth saves once a minute and on shutdown, so a crash costs at most a minute of
ripening.

**Touch is not enough on its own.** Two frozen physics props that come to rest
against each other do not reliably produce a `StartTouch` — they collide and
stop — so a seed placed neatly on the soil can sit there untouched. The one
second farming tick sweeps a 48-unit radius around every plot for dropped items
as well. `StartTouch` is the fast path; the sweep is the one that always works.

**The method names are deliberately odd** — `PlantSeed`, `AddWater`, `Advance`,
`HarvestFor` rather than `Plant`, `Water`, `Tick`, `Harvest`. See gotcha 17: a
scripted entity method called `Respawn` answers nil in this build however it is
written, nobody found out why, and it cost three rounds of debugging on the
plants. Nothing here was worth finding a second one with.

### Crop models

`ix.plants.types` already carries a world model for each of the seventeen wild
plants, and a growing crop is the same thing standing in a box — so that table
is the source, and `ix.farming.models` only names the four crops that never grow
wild. Two of Phoenix's are not installed here (their carrot and tarberry live
under `models/fallout/consumables/`), so those use the models the items use.

### Picking one back up

`/FarmRemove` while looking at it — yours, or anybody who may edit map
furniture. Whatever is growing is lost, and the notice says how many.

---

## Configuring it

Dev terminal → **RESTRAINTS** for mugging (it is what restraints are for), and
→ **WORLD** → FARMING for the plots, next to the plants.

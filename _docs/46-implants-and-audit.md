# 46 — Implants, survival tuning and the audit

Three things that landed together. Phoenix are the reference for the first and
the third.

---

## Implants

Permanent SPECIAL, **put in by somebody else**. The item's Use traces at whoever
you are looking at and there is no path through it that implants the holder —
so every implant in the wasteland went in because another character stood still
for five seconds and did it. That is the whole reason implants are interesting
rather than a stat upgrade you buy.

| | |
|---|---|
| Strength, Perception, Endurance, Charisma, Intelligence, Agility, Luck | +5 to that attribute |
| FEV Experimental | +5 Endurance, +40 health |
| C.I.T | +5 Endurance, +40 health, and an access code |

**They survive death.** An implant is inside you; dying does not take it out.
Only a **permanent kill** does (`OnPlayerPK`) and the **extractor**, which is
another person again. The bonuses are re-applied on spawn rather than remembered
on the player, because buffs live on the player and a player who has just
respawned is a fresh one — which is also what makes them survive.

### The numbers are not in the item files

`ix.implants.list` holds the name, the description and the bonuses; an item
declares `ITEM.implant` and nothing else — **not even `ITEM.base`**, because
Helix takes the base from the FOLDER (`items/implant/*` gets `base_implant`), so
writing one replaces the right base with whatever was typed:

```
[Helix] Item 'implant_agility' has a non-existent base! (implant)
```

The item's **name and description are read from the library too**, so an implant
renamed or rebalanced in the editor says so on the tooltip in somebody's hands.
And no description contains a number: "Grants +5 Strength" was a second copy of
`buffs` written in English, so an implant edited to +3 still promised five — and
said it twice, since the real bonuses are listed underneath. That is what makes every implant
editable in `/liveedit` under **IMPLANTS** — an item carrying its own `+5` would
need a schema edit and a restart to become a `+3`.

The bonuses are **`ix.buff` stat codes**, the same language chems speak, so
everything that already reads a buff reads an implant without knowing what one
is.

### The C.I.T implant

C.I.T only, in both directions: anybody else who tries to fit one is burned for
25 and loses the implant, and anybody else who extracts one **kills the
patient** eight seconds later. Both halves are Phoenix's. The implanting rule is
in the item (it happens with a needle in somebody's hand); the extraction rule
is in `sv_implant.lua`, because a thing that kills the patient is not a decision
an item file should be making on its own.

Fitting one writes an eight-character access code onto the character, and
extraction revokes it.

### Testing them

```
/implantself            list the ids
/implantself luck       put one in yourself
/implantselfremove luck take it back out
```

Admin-only, and a deliberate hole in the "somebody else has to do it" rule —
without it, testing what a Luck implant does means finding a second person.

### The extractor

`equipment_implantextractor` is a **tool, not a consumable**. Used on somebody,
it asks the server what is inside them and offers a button per implant; taking
one out is another five seconds of standing still, and **the implant comes out
as an item** so it can go into somebody else. Extraction is surgery, not
destruction.

| | |
|---|---|
| `implantMax` | how many one character may carry (3) |
| `implantTime` | seconds of standing still, both ways (5) |
| `implantRange` | how close you must be (96) |

---

## Food, water and radiation in the live editor

A **SURVIVAL** section with three subjects. Hunger, thirst and rads are the same
shape — a bar that moves on its own and a ladder of tiers that take SPECIAL off
you — so they are three subjects of one kind rather than three sections.

- **the rates** are `ix.config` (drain standing, walking, running, and the tick
  they share), edited through the same `ConfigField` the SPECIAL section uses
- **the tiers** are tables in `sh_hunger.lua` and `sh_radiation.lua`, edited
  through `Read`/`Write` fields that reach into them — so "how bad is starving"
  is a thing an admin can answer, one attribute at a time

Radiation tiers also carry a **flat cut to maximum health**, which is the thing
rads take that hunger does not.

**Every row names its band** — "Hungry (20-39): STR" — because a penalty that
applies between 20 and 39 is a different thing from one that applies at 20, and
somebody who edits *Hungry* and then stands there at 45 wondering why nothing
changed has not made a mistake; they were told nothing. The penalties are read
when they are needed, so an edit to the band you are in shows immediately and an
edit to any other shows when you reach it.

Nothing is pushed on apply: both ladders are **read when they are needed**, so
an edited tier is in effect the moment it is written. `ix.special.Apply` runs
anyway, because speed is the one thing that is *set* on a player rather than
read.

---

## The audit

```
/audit <steamid>        a SteamID64 or a STEAM_0:… one
/audit <name>           anybody online, by character or Steam name
```

Every character on that account — loaded or not, online or not — with level,
caps, experience, faction, race, when it was made, when it was last seen, how
many implants it has, and whether it is banned. Every field is editable **in
place**: a field commits on enter, the server answers with the whole list again,
and the window redraws. There is no save button, because a save button on a
window that can change six things about forty characters is a save button
somebody forgets.

Permission is **`audit`**, its own entry rather than "superadmin", so a server
can hand it to a head admin without handing over everything else.

### Offline characters are rows

`ix.char.Restore` reads `client:SteamID64()` on its first line, so there is no
supported way to load somebody else's character into `ix.char.loaded`. Building
one by hand would mean owning a copy of Helix's character construction, its
inventory restore and its save, to write one number. So the audit has two paths
and says which is which:

| | |
|---|---|
| loaded | the real character object, the real setters, `character:Save()` |
| a row | one `UPDATE`, and the `data` JSON blob read and written whole |

The **loaded copy always wins** when reading, too: a character somebody is
playing has caps in memory that are not in the row yet — and that includes the
**implant count**, which lives in the `data` blob. A character PK'd a minute ago
still had one according to the row, because the row is only as fresh as the last
save.

### A row the player cannot see is still a row

A character whose faction is **not one this schema has** never loads: the
faction character var carries `FilterValues`, so Helix's character query is
`WHERE faction IN (…the real ones)` and the row is skipped. The player's menu
shows nothing; the table still holds the character and everything it was
carrying — usually a leftover from before a faction was renamed, or another
schema's `citizen`.

The audit **shows it and says so**, marked `UNLOADABLE`, with a line explaining
why and a **DELETE** button that removes the character, its inventories and
every item in them. Hiding it would leave an orphan nobody can find holding an
inventory of items for ever, and this is the one screen whose job is to show
what the database actually contains. Giving it a real faction below brings it
back instead.

Deleting is refused while the character is loaded — taking the row out from
under somebody standing in the world with it is more than this needs to do.
Helix's own delete is copied rather than called, since its receiver requires the
character to be loaded *and* to belong to whoever sent the message, which an
orphan is neither.

The list is filtered to `Schema.folder`. `ix_characters` is shared by every
schema on a database and **Helix deletes a character by moving it out of the
schema rather than removing the row**, so without that filter the audit lists
other gamemodes' characters and, more confusingly, ones the player deleted.

### Their inventory, next to yours

**INVENTORY** and **STASH** open the character's storage as a real `ixInventory`
panel with the auditor's own beside it — so moving an item is Helix's own
transfer with Helix's own rules, and nothing here reimplements what moving an
item means.

For an offline character the inventory is restored straight from
`ix_inventories` by character id, and the stash id comes out of the `data` blob.
Somebody's bag can be opened, emptied and refilled while they are asleep.

**Moving items needed an exemption.** `Inventory:Add` refuses a transfer when
the item belongs to the same Steam account but a different character — the rule
that stops somebody shuttling gear between their own characters. Auditing your
own account trips it on every item and auditing anybody else's trips it on none,
so the symptom is a refusal that looks random until you notice whose account it
was. The audit sets `bAllowMultiCharacterInteraction` on the instances it opens,
remembers which, and takes it back off when the window closes.

The auditor is **added as a receiver** — an inventory only networks to people it
expects, and the owner is usually not even here — and **removed again when the
window closes**, or they would keep receiving every change to a stash on the
other side of the map for the rest of the session.

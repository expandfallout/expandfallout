# Hold-E interactions, restraints, breaching and collars

Four systems that all reach the player in front of you: the menu you get by
pressing E on somebody, the zip ties and cuffs that put them at your mercy, the
charge that gets you through the door they are hiding behind, and the collar
that keeps them where you put them.

Phoenix reach all of these through one menu, `nut.playerInteract`, which is not
in the scrape (it is a server/schema file). The registry here is that shape
rebuilt on Helix's own parts.

---

## The interaction menu — `libs/sh_interact.lua`

**Hold E on somebody and a list of text appears where they are.** You keep
walking, you keep aiming, the crosshair is the pointer — look at an entry and
click it. Let go of E and it closes, having done nothing.

**The list hangs in the world, in front of the person** — a little in front of their chest, facing you, so it is over the person it belongs to rather than off in a corner of them. Forward means *towards the viewer*, not the target's own forward, or walking up behind somebody would put their menu inside their back.

It used to hang beside their head, and before that The first version pinned it
to the *screen* at wherever their head was when it opened — and that is not
clickable at all, because the crosshair is welded to the centre of the screen
too, so a list welded to the screen can never be reached by it. It "locked on
screen and did not move", which is exactly what it had been told to do. Turning
your head is the only thing that moves the crosshair relative to the world, so
the entries have to be *in* the world.

It is **drawn on the HUD, not built as a panel**. The first version used
`ixEntityMenu`, Helix's own, which is what a dropped item opens: a full-screen
VGUI panel that calls `MakePopup` and takes the mouse, so the world greys out,
the camera stops and you stand still until you have chosen. That is right for
looting a box and wrong here, because everything in this menu is something you
do to a *person* who is under no obligation to wait.

The anchor is **screen space**, taken once from the target's head as the list
opens. Following them every frame means the entry you are reaching for moves
away as you turn towards it.

Clicking is read in `CreateMove`, which also **removes** IN_ATTACK — holding E
and clicking would otherwise fire whatever is in your hands at the person you
are choosing a menu entry on.

### Registering an action

```lua
ix.interact.Add("ziptieRelease", {
    name = "Untie",              -- or function(target) for text that changes
    order = 21,                  -- lower is higher up the list
    canSee = function(target) end,   -- CLIENT: is the entry drawn
    callback = function(target) end, -- CLIENT, optional: run INSTEAD of sending
    OnCanRun = function(client, target) end, -- SERVER: the real permission
    OnRun = function(client, target) end     -- SERVER: the action
})
```

Two differences from Phoenix's, both deliberate:

- **One net message, not one per verb.** Theirs gives every action its own net
  string and its own receiver; each receiver has to redo the "are they near
  enough, alive, and playing a character" checks, and one that forgets is a
  client that can untie anybody anywhere. `ix.interact.Run` does those once for
  every action before the action's own `OnCanRun`.
- **An order.** `ix.menu.Open` takes `[text] = callback` and walks it with
  `pairs`, so five actions come out in a different order every time you open
  the menu. `ix.interact.Open` builds the same panel by hand, sorted.

`GetPlayerEntityMenu` — Helix's own hook for this — is still collected and
those entries are appended, so a plugin that uses the official route works.

### What is registered

| Order | Entry | File |
|---|---|---|
| 10 | Introduce Yourself | `sh_recognizeinteract.lua` |
| 20 | Zip Tie / Cuffs | `sh_restrain.lua` |
| 21 | Untie / Uncuff | `sh_restrain.lua` |
| 22 | Search Inventory | `sh_restrain.lua` |
| 23 | Check Caps | `sh_restrain.lua` |
| 24–27 | Drag, Uncuff, Gag, Blindfold | `sh_cuffs.lua` (the addon's) |
| 30 | Collar: `mm:ss` | `sh_slavery.lua` |
| 31 | Diffuse Collar | `sh_slavery.lua` |

**Recognition only goes one way.** "Introduce Yourself" writes *your* character
id into *their* list — you tell them who you are. There is deliberately no
"recognise them": being able to learn a name without being told one is the
whole system undone. The ranged versions (whisper, talk, yell) are still on
Helix's `ShowSpare1` bind. The person you introduced yourself to gets a
notification and nothing is said in chat — the two people involved both know
what happened, and everybody else in the room does not need a line about a
handshake.

---

## Zip ties and handcuffs — `sh_restrain.lua`, `sv_restrain.lua`

Helix's `Player:SetRestricted` already strips and remembers the weapons (with
their item and their clip), blocks `PlayerUse` and every item interaction, and
hands everything back on release. The restraint state is theirs; what is added
is the *kind*, who did it, and the walking speed.

|  | Zip tie | Cuffs |
|---|---|---|
| uniqueID | `zipties` | `cuffs` |
| model | `models/items/crossbowrounds.mdl` | `models/mosi/fallout4/props/junk/handcuffs.mdl` |
| to apply | `ziptieTime` (5s) | `cuffTime` (8s) |
| to remove | `ziptieReleaseTime` (5s) | `cuffReleaseTime` (5s) |
| who may remove | anybody | only somebody holding cuffs |
| consumed on use | yes | no |

Both are applied the same two ways — the item's own **Use** while looking at
somebody, or the menu entry — and both go through `ix.restrain.Begin`, so there
is one copy of the rules. It is a `DoStaredAction`: look away and it cancels.
Everything is re-checked when the bar finishes, because five seconds is long
enough to have lost the tie, died, or been beaten to it.

### Elastic Restraints — the `cuffs` addon

The third restraint is **not this schema's**. `addons/cuffs` is my_hat_stinks'
Cuffs — the same licensed addon Phoenix use, which is why their menu calls
`Cuffs_DragPlayer` and `Cuffs_FreePlayer` — and it owns the whole restraint:
applying it, the struggle that breaks out of it, the gag, the blindfold and the
rope you drag somebody by. Nothing of it is ported or edited.

What is on our side of that line lives in `sh_cuffs.lua`:

- **The item** — `items/weapons/sh_restraints.lua`, `ITEM.class =
  "weapon_cuff_elastic"`, in its own `tool` weapon category so carrying it does
  not cost you a knife.
- **Four menu entries** — Drag, Uncuff, Gag, Blindfold, exactly Phoenix's set.
  They run on the **server** and call the addon's own accessors directly
  (`SetKidnapper`, `SetFriendBreaking`, `SetIsGagged`, `SetIsBlind`), firing its
  hooks with the same arguments. They started as client callbacks sending the
  addon's net messages, which is tidier and does not work: every one of those
  receivers ends with a 100-unit trace that has to land on the target, and by
  the time you click a menu entry you are looking at the *entry*, which hangs
  beside their head. `ix.interact.Run` does the checking instead.
- **The addon's key prompts are gone.** Its `PlayerBindPress` listener bound E
  to "release" — fighting the menu for the same key — and its HUD prompt
  advertised four keys that are all menu entries now. Both are replaced *by
  name* (`hook.Add` over "Cuffs CuffedInteract" and
  "Cuffs CuffedInteractPrompt"), so the rest of the licensed addon is untouched:
  `+attack`, `+attack2` and `+reload` still reach its original handler, and
  tying somebody to a hook — the one thing with no menu entry — still works.
  The release **progress bar** is kept, redrawn in our palette, because
  releasing takes time and nothing else shows how far along it is.
- **Uncuff starts a release, it does not finish one.** The addon's `BreakThink`
  runs it down and cancels if you look away; the notification says so.
- **The config** — the addon's numbers are SWEP *fields*, which nobody can
  reach in game, so `ix.cuffs.Apply` writes the configured values onto the
  stored weapon table **and every live one** (a stored-table-only write would
  leave anybody already carrying a pair on the old numbers). Defaults are the
  addon's own.
- **`CuffsCanHandcuff`** — the one hook the addon asks us: no cuffing somebody
  who is already zip-tied, none while your own hands are tied.

`ix.restrain.Kind` answers `"handcuffed"` for anybody the addon has, so Search
Inventory, Check Caps and the tooltip all work on them; that kind is marked
`external` so this schema never offers to apply or remove it.

**A restraint does not survive death, disconnect or a character swap.** Death
and disconnect go through `ix.restrain.Clear`, which does *not* restore
weapons — `SetRestricted(false)` would `Give` them to a corpse. Somebody cut
free goes through `ix.restrain.Release`, which does.

### Searching

Opens the target's own inventory as a Helix storage window, gated by
`restrainSearchTime` and closed by walking away, dying, being freed or leaving.

**Caps are not in it.** Searching is not mugging. That is enforced in two
places, and only the second one counts: `cl_restrain.lua` hides the money row,
and `sv_restrain.lua` wraps `net.Receivers["ixstoragemoneytake"]` and
`["ixstoragemoneygive"]` to refuse while the open storage is a search — because
hiding a row in a panel is not a permission, and a hand-sent net message
empties the pockets either way. "Check Caps" tells you the number instead.

---

## Nothing here sets a price

**No item in this batch has an `ITEM.price`, and nothing was added to any
shop.** Prices are a design decision, not a port. For reference only, Phoenix
priced their zip tie at 50c and their Doorbuster Charge at 600c; their cuffs
are a separate addon and their collar has no price at all.

`ITEM.price` in this schema is only the number the shop configurer pre-fills
when *you* add an item to a faction's shop (`ix.shop.NewEntry`, which falls
back to 100 when an item has none). An item having a price does not put it in
a shop, and nothing puts anything in a shop but you.

---

## Breaching charges — `sh_breach.lua`, `sv_breach.lua`, `ix_breachcharge`

Phoenix's Doorbuster. A `Doorbuster Charge` item sticks to whatever you
are looking at within 96 units, beeps for `breachTime` seconds at an
accelerating rate, and blows every door within `breachRadius` open for
`breachDoorRestore` seconds.

- **A teleport loses its lock and its owner.** `ix.doors.Breach` is what a
  breach means in this schema, and until now nothing called it.
- **An ordinary owned door does not change hands.** A blown door swings open;
  it does not sell itself to whoever blew it.
- **Prop teleports count as doors** for this, via `ix.doors.Link` — the crates
  and lockers people build bases out of are not doors by `IsDoor`.

**It hurts.** `breachDamage` (80) within `breachDamageRadius` (220), through
`util.BlastDamage` so it falls off with distance and respects walls — being on
the far side of the door you are blowing is the protection it ought to be. The
planter is the attacker, so it lands in the logs and the kill feed as theirs.
The first version blew the door off its hinges and left everybody stood next to
it untouched.

The countdown is a networked float rather than each end guessing from its own
`CurTime`, so a charge looks the same to everybody watching it.

**The blacklist is per-map data**, not a table in the source: Phoenix's is four
brush model indices, and a brush index is a different door on another map.
`fo_breach_block` (dev.terminal permission) toggles the model you are looking
at, and it is saved with the rest of the world data.

---

## Slave collars — `sh_slavery.lua`, `sv_slavery.lua`

The item that was in `items/armor/sh_armor_misc_slavecollar.lua` was a
mechanical conversion of Phoenix's and would have thrown the moment anybody put
one on — it still called `char:getPlayer()`, `item:getOwner()`, `self:remove()`
and `nut.config.get`, and read `ix.item.inventories[self.invID]`, which is the
bare world table. It has been rewritten against this system.

**Handing somebody an armed collar is enslaving them.** There is no "put collar
on" verb: you Arm it (which records you as its owner), you give it to them, and
it locks itself on during the transfer. That is Phoenix's design and it is why
the interesting code is an `OnItemTransferred` hook.

| Config | Default | What it is |
|---|---|---|
| `slaveCollarMaxTime` | 1200 | seconds a collar runs before it falls off |
| `slaveCollarExplodeTime` | 10 | fuse once triggered |
| `slaveCollarDamage` | 50 | dealt to the wearer alone |
| `slaveCollarDisarmIntelligence` | 15 | to defuse one |
| `slaveCollarDisarmTime` | 10 | seconds it takes to try |

- **Running out frees you.** That is theirs: at zero the collar comes off and is
  destroyed. The explosion is the *other* thing that can happen.
- **Failing a defuse starts the fuse.** Nothing in the scrape says what failing
  does; if it cost nothing then everybody would try every time and the
  Intelligence requirement would be a delay rather than a decision.
- **It always kills.** The configured damage is dealt first — so the damage
  hooks, the armour and the kill feed all see it, attributed to the collar's
  owner when they are online — and then anybody still standing is killed
  outright. Fifty points against Power Armour is a scratch, and a collar going
  off is not a wound.
- **Running out is announced** to the wearer three ways: a notification, two
  sounds and a chat line that is still there afterwards. It is the one moment a
  slave is counting towards.
- **Triggering is not in the hold-E menu.** It is the SlaveBoy 2000 — an item
  that opens a screen listing everybody whose collar you armed, with the time
  left on each and a button to release or trigger it from anywhere on the map.
  That is Phoenix's design and it is the better one: triggering a collar is the
  one thing you do to a slave that should *not* need you stood in front of
  them, or walking away from your captor makes you safe. Trigger asks for
  confirmation; the item is never consumed. The slave vendor and mine that
  theirs also sells people to are still a later job.

Two things are not Phoenix's, and both are the same complaint about their
clock. Theirs writes the remaining seconds back to the item **every second**
(a database write and a network message per collar per second); this keeps a
deadline and subtracts. And the deadline is `os.time`, not `CurTime`, because a
collar is meant to outlive a map change — gotcha 11.

The wearer carries `enslaved`, `collarUntil`, `collarOwner` and `collarFuse` as
netvars, so everybody near them can read the collar. Item data is networked to
whoever *holds* the item, which is exactly the wrong person for a thing around
somebody's neck.

---

## Configuring it

Dev terminal → **RESTRAINTS**: every number above, on one screen, because they
are one situation. A five second tie against a five second untie is a
stalemate; a ten second defuse against a ten second fuse is a coin toss. They
are all in Helix's own config menu too.

## The SlaveBoy's tracker, and the leash

**LOCATE** on a row of the SlaveBoy window marks where that person is for
`slaveLocateTime` seconds (30), once per `slaveLocateCooldown` (30): the squad
marker's shape in the collar's colour — a point, their name, the distance and
the seconds left — that only the owner sees, and when they are off screen a
mark along the bottom of the view at their bearing, so it still says which way
to walk. `libs/cl_slavery.lua` draws it; the server sends `ixSlaveLocate`.

**The leash.** A collar within `slaveProximity` units (4,000; 0 turns it off)
of its owner is quiet. Past it, the collar triggers on its own — exactly as if
the owner had — and both are told; at eighty per cent of the range the wearer
gets one warning first. Only while the owner is online and on that character:
a leash to somebody who is not here is a collar nobody can answer for, and a
slave whose owner logs off should not die of it. Logged as `collarProximity`.
Both settings are in the dev config.

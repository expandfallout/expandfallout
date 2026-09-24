# 27 - Ammunition and faction shops

## Ammunition

**34 items, covering every ammo type the 217 weapons fire.** Generated:

```bash
python _docs/tools/genammo.py
```

`_docs/tools/ammo.py` is the roster, `items/base/sh_ammo.lua` the base. One box
is spent in one go and puts `ITEM.rounds` into the player's pool for
`ITEM.ammo`, which every weapon chambered for it draws from — one box of 5.56
serves the nine weapons that use it.

### The weapons are the authority

`ITEM.ammo` has to match `SWEP.Primary.Ammo` **exactly, including its
capitalisation**, which is the weapons' own and is not consistent: `12Gauge`,
`45Auto`, `FragGrenade`, but `10mm` and `grenade`. Get it wrong and the rounds
go into a pool nothing can reach — the item is consumed, the counter does not
move, and **nothing errors anywhere**. That is close to unfindable in game, so
`genammo.py` reads every weapon in `addons/falloutrp_weapons`, refuses to write
a type none of them fires, and reports any type no item sells (a weapon that
cannot be reloaded).

The first run refused all 25 non-trivial types for exactly this reason.

### Helix already ships a `base_ammo`

`gamemode/items/base/sh_ammo.lua`, with the same file name and therefore the
same uniqueID. `ix.item.Register` **reuses the table** for a uniqueID it already
knows, so the schema's base is layered on top of theirs rather than replacing
it — and defining a `Load` key left their `use` in place beside it, both
labelled "Load" with the same icon. Two identical entries in the item menu, one
of which handed out `ammoAmount` (their field, default 30) instead of `rounds`.

Sharing the key (`ITEM.functions.use`) overwrites the function instead of adding
a second. Staying on their base is worth it anyway: their `OnRegistered` calls
`ix.ammo.Register(self.ammo)`, which is what makes the ammosave plugin persist
these 34 types across a session.

### Shared pools

Grenades and mines share pools because the weapons do: `FragGrenade` is what
frag, plasma *and* pulse grenades fire, and `FragMine` covers five different
mines. One item per pool is not a simplification — it is what the weapons were
built against.

Every model is checked against disk by the generator. `.38` and `.357` share a
box, and so do 25mm and 40mm grenades, so the base paints the round count on the
icon: without it two stacks are indistinguishable in an inventory.

---

## Faction shops

Phoenix's `factionshop`, replacing Helix's Business tab — which sells
`ITEM.business` items to anybody with the caps and has no idea what a faction
is.

| | |
|---|---|
| `schema/libs/sh_shop.lua` | what an entry is; `CanBuy`, `GetCategories`, restock maths |
| `schema/libs/sv_shop.lua` | storage, restocking, buying, configuring |
| `schema/derma/cl_shop.lua` | the Shop tab |
| `schema/derma/cl_shopconfig.lua` | the configurer, `/shopconfig` |

An **entry** is one thing a faction sells: an item, a price, a category, the
lowest class rank that may buy it, and its own stock (`stock`, `maxStock`,
`restockAmount`, `restockTime`, `lastRestock`). Everything is per faction — two
factions selling 5.56 have two entries, two prices and two stocks.

### Rank, not a list of classes

Phoenix attach a set of permitted classes to each entry. On a roster of 222
classes that is 222 checkboxes per item, and it has to be revisited every time a
class is added. `CLASS.rank` already orders every class 1–4 and "officers and
above" is the rule people actually describe, so an entry names a **minimum
rank** — and a new class is covered the moment it is written.

That is the thing the shop is for: an enlisted trooper buys ammunition, the
rifles are an officer's signature.

### What a row shows

Name, price, and the whole of the stock position:

```
Combat Rifle
3 of 10 in stock                              1200c
                                          +5 in 12m
```

**The restock was on the server and was never sent.** "Out of stock" answers
half the question somebody standing at an empty shelf is asking; the other half
is when it will not be empty. The sync now carries a **seconds remaining**
figure per entry — not `lastRestock`, which is `os.time()` and would make the
countdown depend on the client's clock agreeing with the server's; a machine an
hour out would have shown an hour of nonsense. The client counts down from the
moment the message arrived, so the number moves rather than sitting still
between syncs.

A countdown that runs out with no sync behind it says `+5 due` rather than
`+5 in 0s`: the restock tick only syncs when something actually changed, so a
full shelf's clock legitimately expires with nothing following it.

### Stock is on the entry

Phoenix keep a separate table of stock pools that entries reference by id, so
several items can draw from one supply. Nothing anybody asked for needs that,
and it costs an id to manage, a second editor to manage it in, and a garbage
collector for the pools that end up pointing at nothing. One entry, one stock —
which is also why the configurer is one window with three columns instead of
their five separate frames.

### Restocking survives a restart

`lastRestock` is `os.time()`, not `CurTime()`, and restocks are counted in whole
elapsed periods. Come back after a day and a daily shop owes exactly one
restock — not none, which is what a `CurTime` timer reset would give, and not a
day's worth of ticks. The clock advances whether or not anything was added: a
full shop has still *had* that restock, and leaving the clock behind would make
it restock the instant somebody bought something.

### The EVERYONE shop

`ix.shop.GLOBAL` is `"*"` — a faction uniqueID is a file name with `sh_` and
`.lua` taken off, so it can never be that, which makes it a key that cannot
collide with a real faction however many get added. A readable word like
"global" could.

`ix.shop.GetFor(faction)` is the global entries with the faction's own layered
on top, and **the faction wins on a conflict**: both selling 5.56 means the
faction has deliberately priced it, and letting the global entry override that
would make the faction's own configuration silently do nothing.

It appears pinned above the faction list in the configurer rather than sorted
into it, because it is not a faction competing for a place in the alphabet — it
is the thing that applies to all of them. It has no ladder of its own, so it
offers all four rungs under their generic names; a rank set there is compared
against whatever rank the buyer holds in *their* faction.

### Faction rank names

The rank dropdown shows **the faction's own rungs**, from
`ix.class.GetRankName`. "Enlisted / NCO / Officer / Lead" is the shape of every
ladder and the name of almost none of them — the Kings have a Sergeant-at-Arms,
the White Glove Society a Maitre d', the Deathclaws a Mother and no rung 2 at
all. Offering all four to every faction asked somebody to translate in their
head, and setting a rank a faction has no class for is silent: the row simply
never appears for anybody.

`ix.class.GetRanks` returns only the rungs a faction actually has classes for,
so what cannot be reached cannot be chosen. The shop tab uses the same names, so
a Kings member is told they need to be a **Lieutenant** rather than an
"Officer" — a rung their faction does not have and they could not look up.

### Unlimited stock

`entry.infinite` is a flag, not a magic count. Both `-1` and `0` overload a
number with a meaning, and the one that reads most naturally — 0 for unlimited —
is the exact value that already means *none left*, so an unlimited shop would be
indistinguishable from one that had just sold out. When it is set, buying does
not decrement, restocking is skipped, and the stock fields grey out rather than
disappearing.

### Copying between shops

`COPY TO...` on an entry, `COPY ALL` on a shop. Setting up the fifth faction to
sell the same ammunition at the same prices is the bulk of the work here, and
doing it by hand is where the mistakes are — a price typed differently in two
places is a difference nobody notices until somebody compares.

**A copy is a snapshot, not a link.** The target gets its own entry with its own
stock; two factions sharing one supply would be a different thing entirely.
Anything the target already sells is **left alone** rather than overwritten — a
bulk copy usually means "give them the rest of what we sell", and silently
resetting prices and stock they had already set would be a destructive answer to
that. The rank is clamped to something the target faction actually has, because
copying a rank-4 entry into a faction whose ladder stops at 1 prices it out of
reach of every member for ever, silently.

Copying into EVERYONE is offered too — it is the shortest way to say "actually,
anybody can buy this".

### Categories are derived, not configured

A category is the set of entries that name it. That makes **"a tab does not
exist if there is nothing in it" true by construction** — removing the last
entry removes the tab, and there is no list of names to garbage collect
afterwards (Phoenix have two collectors for exactly this). Creating a category
is typing it into the entry.

It filters by rank as well: a category holding nothing you may buy would be a
tab that opens on an empty list, which reads as a broken shop rather than a
locked one.

### Notes

- **Rows you cannot buy are shown, greyed, with the reason on them** — "Requires
  Officer or above". Hiding them answers "what is there to work towards" with
  nothing at all.
- A player is sent **only their own faction's** entries. What the NCR charges is
  the NCR's business, and sending 45 shops to display one is work nobody needs.
  Admins get everything through `ixShopConfigAll`.
- `ix.shop.Get` is **overridden on the client** to return the one list it holds,
  so `CanBuy` and `GetCategories` are the same shared code on both realms rather
  than two drifting copies.
- **Buy order is add, then charge.** `inventory:Add` can still fail after
  `FindEmptySlot` said there was room — another item can land in that slot in
  between. Taking payment first is how a player pays for nothing.
- `inventory:Add` is synchronous and returns `x, y, inventoryID` — *not* a
  boolean, and it takes no callback. Passing one lands in the `noReplication`
  parameter and silently suppresses the networking.
- **`/shopconfig` opens on the data, not on a "please open" message.** The
  first version sent `ixShopConfigOpen` to the client — a netstring whose only
  receiver is on the *server*, where it answers the panel asking for a refresh.
  Nothing on the client listened, so the command sent a message into the void.
- The save is guarded behind the load, the way `sv_loot.lua` is: writing an
  empty table because a read failed turns a transient failure into every shop on
  the server being erased.

### Commands

```
/shopconfig                      the configurer (admin)
/shoplist                        what your faction sells, in chat
```

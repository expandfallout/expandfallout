# The black market

Phoenix's `plugins/blackmarket`: a terminal you press E on, four tabs — BUY,
SELL, MY LISTINGS and, for staff, LOGS — and listings that lived on a **web
service** (`<their marketplace web service>`, fetched over HTTP a page at a
time), which is why only their window and validation are in the scrape. This
keeps the window, the rules and the numbers, and keeps the listings on the
server.

| | |
|---|---|
| `schema/libs/sh_blackmarket.lua` | settings, the fee, what may be listed, validation, logs |
| `schema/libs/sv_blackmarket.lua` | the listings (`ix.data`, key `blackmarket`), selling, buying, unlisting, claiming, pages |
| `schema/libs/cl_blackmarket.lua` | the messages |
| `schema/derma/cl_blackmarket.lua` | the window |
| `schema/entities/entities/ix_blackmarket.lua` | the terminal |

## The rules, which are Phoenix's

- **A listing** is one kind of item, N units of it at a price per unit, for 1
  to `marketMaxDays` days, optionally anonymous, with a note of up to 100
  characters. The units are **taken out of the bag** when listed and each
  unit's own item data (rarity, modulators, durability) is kept on the listing,
  so a buyer gets what the seller had, not a fresh copy.
- **The fee** is `marketTax` per cent of every sale plus `marketDayTax` per
  cent for every day past the first — the longer it is up, the more the market
  takes. It is charged when a unit *sells*, out of the seller's proceeds; the
  buyer pays the list price. What the seller keeps per unit and in total is
  shown before they list.
- **Limits:** `marketMinPrice`, `marketMaxPrice`, `marketSlots` listings with
  units left per character. No negative prices, no zero quantities, no
  fractions, no bags (`isBag`) and nothing flagged `noMarket`. Equipped items
  cannot be listed.
- **Buying:** any number of units at once, paid up front, delivered into the
  bag; what does not fit is refunded and stays up. Your own listings are on the
  board with everybody's, marked YOURS, and cannot be bought.
- **The money** accrues on the listing (`earned`) and the seller **claims** it
  at a terminal — Phoenix's way, and why somebody offline still gets paid. A
  seller who is online is told when something sells.
- **Expiry:** an expired listing sells nothing and waits for its owner to
  unlist it and take the units back; nothing is ever deleted for them.
- **Unlisting** returns as many units as fit in the bag.

The window closes if you walk more than 256 units from the terminal, and
every request is refused at that distance on the server too.

## The window

BUY: filters on the left (name, category, min/max price, order, rarity),
ten listings a page on the right with the item's icon, name in its rarity
colour, seller (or *Anonymous*), units left, expiry, note and price, BUY asking
how many. SELL: the bag on the left, one row per kind of item with how many;
the listing on the right — quantity, price, duration (each choice shows its
total tax), anonymous, note — with *you keep X a unit* and *you get Y if it all
sells* recomputed as you type, and LIST IT validated on the client before it is
sent and again on the server. MY LISTINGS: every listing of yours with status,
sold count, tax, UNLIST (how many) and CLAIM (the caps waiting). LOGS: the
last 500 market events, for `market.logs`.

## Settings

| | |
|---|---|
| `marketTax` | per cent of every sale the market keeps (10) |
| `marketDayTax` | extra per cent per day past the first (2) |
| `marketSlots` | listings with units left per character (10) |
| `marketMinPrice` / `marketMaxPrice` | bounds on a unit's price (2 / 1,000,000) |
| `marketMaxDays` | longest a listing runs (7) |

All in the dev config. Permission `market.logs` (Staff). Logs: `marketList`,
`marketBuy`, `marketUnlist`, `marketClaim`.

## The terminal

`ix_blackmarket` — Phoenix's ship's-computer console with the wall monitor
rendered above it, spawned by staff from the entities tab; `gmod_tool
permaprop` keeps it across restarts like any other prop.

## Two things fixed after the first test

- **The window did not update after an unlist.** Every action is followed by
  a page request (`ixMarketRefresh` makes the window reload), and the request
  shared the actions' throttle, so it was dropped every time. Asks have their
  own.
- **The monitor's screens were pink.** The wall monitor's third material,
  `vcontrolpanelsscreen01`, is in neither folder its model names and in no
  mounted pack. The monitor is a clientside model of ours now, with that one
  sub-material replaced by a plain dark green screen (`!ixMarketScreen`).
  **Then they were pitch white:** the tint was `$color`, which the model
  renderer overwrites with the entity's render colour every frame. It is
  `$color2` now — gotcha 30.

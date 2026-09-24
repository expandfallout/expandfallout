# The G.E.C.K. and Crafting — mostly unusable

## What the GECK is

"Guardian of Eden Creation Kit" — an **in-game content editor** delivered as an item. Admins open it and
author loot tables, containers, crafting recipes, custom perks and 3D ambient sounds through a Derma UI,
without touching Lua. Six plugins, **~9,470 LOC**:

| Plugin | LOC | Editor for |
|---|---|---|
| `geck` | 3,603 | core menu, condition builder, item selector, loot table + container editors |
| `geck_looting` | 3,023 | loot containers, `nut_looter` entity, fake-inventory tetris looting UI |
| `geck_crafting` | 1,386 | recipes, `nut_geck_crafter` entity, workbench GUI |
| `geck_perks` | 685 | custom perks |
| `geck_sounds` | 616 | 3D ambient sounds |
| `geck_webserver` | 158 | the HTTP transport |

## The blocker: all GECK data lives on a server we don't have

`geck_webserver/sh_plugin.lua` hardcodes an external endpoint:

```lua
WebServer.Address = "<phoenix-geck-host>"
WebServer.Port    = "2001"
-- HTTP POST http://<addr>:<port>/api/<collection>/get
-- HTTP GET  http://<addr>:<port>/api/<collection>
```

I checked: **there are no local loot table, recipe, or container data files anywhere in the scrape** —
only the editor UIs. Collections are fetched at runtime from Phoenix's own infrastructure. That IP also
appears as one of the scraped server folders, confirming it's their box.

**Consequences:**

1. Every GECK plugin is **dead code** for us — the editors would load, but every list would be empty.
2. **All loot tables and crafting recipes are gone.** Not "need porting" — *absent*. Loot drops, container
   contents, and every recipe have to be designed from scratch regardless of framework.
3. We should not point anything at that address. It isn't ours, and calling a third party's API from our
   server is unreliable and not our call to make.

**A design flaw worth not repeating:** the *client* calls the webserver directly
(`net.Receive("nutGeck:SendItem")` then `WebServer:GetData`). Every player's game talks to the backend.
That exposes the endpoint to anyone running the server and trusts clients with data-layer access. If we
build an equivalent, the server fetches and networks down to clients — never the reverse.

## What to do instead

A GECK-equivalent is genuinely a good idea — letting admins author loot and recipes without writing Lua —
but ours should persist to the **local Helix database** (`ix.data`, or a schema table in `sv.db`) rather
than an external service. Same UX, no external dependency, no data leak.

## Non-GECK crafting/gathering — these DO work, self-contained

| Plugin | LOC | Notes |
|---|---|---|
| `workbench` | 2,711 | placeable workbenches, configurable **slow craft** (timed queues) |
| `smithing` | 1,168 | iron bars → plates at an anvil → grind to PA component shells at a grindstone → craft shells into unassembled PA parts (blueprint-gated) → assemble at a workbench. A real 4-stage production chain |
| `mining` | 461 | ore deposits feeding the `ore*` items |
| `farming` | 681 | crop plots (`sh_farming_plot` deployable) |
| `plants` | 824 | harvestable/edible world plants |
| `fishing` | 1,499 | cast, timing minigame, catch; fish are **named by rarity** |
| `drugs_advanced` | 3,005 | SS13-inspired chemistry with beakers and custom chem synthesis |
| `drugs_simple` | 1,402 | straightforward chems + addiction |
| `tradeup` | 925 | trade N weapons of one rarity for a random one of the next tier up |

The smithing chain and the fishing minigame are fully self-contained and portable — good candidates for
early ports, since they don't touch the missing infrastructure.

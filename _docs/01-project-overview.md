# 01 — Project overview

## The framework decision

The server runs **Helix** (`gamemodes/helix`), and our schema is
`gamemodes/falloutrp`. This was a deliberate choice: Helix is more actively
maintained and better optimised than NutScript, with proper networked character
vars, a saner inventory, and `ix.plugin` hook caching instead of NutScript's
per-call hook walk.

The scrapes in `some_source_code/` are **NutScript**. They are reference
material, never a source to copy from.

| NutScript (reference) | Helix (target) |
|---|---|
| `nut.*` | `ix.*` |
| `SCHEMA` | `Schema` |
| `client:getChar()` | `client:GetCharacter()` |
| `char:getName()` | `character:GetName()` |
| camelCase methods | PascalCase |
| `.desc` | `.description` |

Full translation table: [reference/00_README.md](reference/00_README.md).

## Source material

| Path | What it is |
|---|---|
| `some_source_code/latest_dev_scape/` | **Best copy.** Phoenix "Divide Rebirth" dev server, v0.3.0 (May 2026) |
| `some_source_code/lastest_client_scrape/`, `old5_*` | Same server, earlier |
| `some_source_code/old1_client_scrape/<scraped-server>_27064` | The **live** Phoenix server — differs from dev, useful for comparison |
| `some_source_code/old1_client_scrape/<scraped-server>_27062` | An unrelated SCP-RP/DarkRP server. Ignore. |
| `some_source_code/random_fallout_schema/` | Small unrelated NutScript Fallout schema |
| `some_source_code/incursion-source-HAS_BACKDOORS/` | **Empty**, 0 files |
| `phoenixsourceaddons/` | 78 extracted workshop addons — the content source |

**Scale:** ~147k LOC schema (2,057 files, 94 plugins) + ~128k LOC addons.

### The critical limitation of the scrapes

They were made with **glua-steal**, which only captures what a server sends to
clients. That means:

- **Zero `sv_*.lua` files** — 1,770 `sh_`, 186 `cl_`, **0 `sv_`**
- Server logic *inside* `if (SERVER)` blocks of **shared** files survived
- Standalone server-only files are **gone and unrecoverable**

This is why the projectile entities had to be rewritten from scratch (their
`init.lua` is server-only) while the melee system ported cleanly (Melee Arts 2
puts everything in `shared.lua`).

When something seems missing, check whether it would have been server-only.

## Directory layout

```
project/
├── _docs/                       these docs
│   └── reference/               mined Phoenix data
├── garrysmod/
│   ├── gamemodes/
│   │   ├── helix/               the framework (don't modify)
│   │   └── falloutrp/           OUR SCHEMA
│   │       └── schema/
│   │           ├── sh_schema.lua      includes
│   │           ├── sh_hooks.lua       TranslateActivity, DoAnimationEvent
│   │           ├── sv_hooks.lua       proportions, key rebind
│   │           ├── cl_hooks.lua       raise keybind
│   │           ├── factions/          currently 2 placeholders
│   │           └── libs/
│   │               ├── sh_anims.lua       NV animation data (689 lines)
│   │               └── cl_bodyparts.lua   body rendering
│   ├── addons/                  see 02-server-setup.md
│   └── cfg/server.cfg
└── startserver.bat
```

## What exists vs what doesn't

**Built and working:** weapon base + 176 ranged weapons, 87 melee weapons,
bullet tracers, 5 projectile types, New Vegas player animations, body
rendering, compat shims, server config.

**Not built:** everything in `08-open-items.md` — most notably item stacking
(which gates all economy work), races, armour, and the whole schema layer.
The two factions in `schema/factions/` are placeholders.

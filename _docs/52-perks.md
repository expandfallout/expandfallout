# Perks — what Phoenix have, before any are built

Read from the scrape (`plugins/perks`): `sh_plugin.lua` (160 lines),
`libs/sh_perks.lua` (17), `derma/cl_perks.lua` (414) and seventeen perk files.
The server file (`sv_plugin.lua`) is not in the scrape.

## The shape

A perk is a file that registers a table:

```lua
local PERK = {
    name = "Natural Leader",
    desc = "Your leadership strengthens your squad, granting them damage resistance.",
    model = "models/props_c17/BriefCase001a.mdl",   -- the icon in the tab
    lostOnPK = true, lostOnRespec = true,
    tiers = {
        [1] = {desc = "Your squad gains 1 DR.", level = 25, cost = 4,
               attributes = {Charisma = 15}},
        [2] = {desc = "...an additional 1 DR.", level = 50, cost = 4,
               attributes = {Charisma = 25}},
    }
}
nut.perk:registerPerk("natural_leader", PERK)
```

- **Bought with skill points**, tier by tier: each tier has a level
  requirement, a cost in skill points and optionally SPECIAL minimums.
  `char:canClaim(perkID)` checks all three plus `noBuy`; `claimPerk` /
  `removePerk` are server-side. A character's perks are `char:getData("perks")`
  as `{[id] = tier}`.
- **Effects hang off hooks** in the perk's own file — Natural Leader listens
  to their damage-scale hook and reads the *squad leader's* perk tier;
  Concentrate Fire adds a squad ping bind; Meltdown, Bullet Storm, Cowboy,
  Grim Reaper's Sprint and the rest are the New Vegas perks by name.
- **Lost on a permanent kill** (`lostOnPK`) and on a respec.
- Admin commands: `/giveperk`, `/removeperk`, `/hasperk`.
- The tab (their `cl_perks.lua`) is a grid of perk cards with the model as an
  icon, the tiers listed, and a buy button per tier.

## The seventeen

broadshoulders, bulletstorm, chemist, concentrate_fire, cowboy, frequentaddict,
grimhealer, grimreapersprint, heavyhitter, lasercommander, lockpicking,
meleewarrior, meltdown, natural_leader, radman, rubberbones, tinkertim.

## What this schema already has for it

Levels and skill points (`22-leveling.md`), SPECIAL (`17-special.md`), squads
with `ix.squad.Get` / `ix.squad.Rank` (`48-squads.md`), the PK hook
(`36-pk.md`), the buff library for timed stats (`25-chems.md`) and the damage
hooks in `sv_armor.lua` / `sv_rarity.lua` where most perk effects would sit.

# PvP, Territory and Faction Politics

This is the actual core loop of the server — everything else feeds it.

## Raids & Wars (`raid`, 1,495 LOC + `wars`)

`nut.raids.types` defines **three conflict types**, all sharing one state machine
(`nut.raids.current` — only one conflict server-wide at a time):

| Type | Admin approval | Player-callable | Notes |
|---|---|---|---|
| `raid` | no | yes (`canStartRaid`) | the everyday PvP trigger, has cooldowns |
| `war` | **yes** | no | faction-vs-faction, needs war points placed on both sides |
| `conquest` | **yes** | no | largest scale |

Each type supplies `startSound` / `endSound` / `preEndSound` (randomised from a pool),
plus `canCallFunction`, `startFunction`, `endFunction`, `onRequestFunction`.

**War overtime is a nice bit of design:** when a war timer expires, `endFunction` checks whether any
capture point still has `captureAmount > 0`. If so it refuses to end, plays a war-beat track, announces
overtime, and installs a `Think` hook that ends the war the moment all points go neutral. Prevents a war
being won by clock-stalling.

`endSound` for war branches on `wonWar` — victory stinger vs. defeat stinger.

`nut.raids.cooldowns` is per-faction. Configs live under category **Raids & Wars** (2 configs).

## Ambush (`ambush`, 108 LOC)

The lightweight PvP valve — lets factions fight *without* declaring a raid.

- `Ambush Cooldown` 300s, `Ambush Duration` 120s
- `/ambush` command, no admin approval
- Broadcasts one of 7 flavour lines to everyone ("Distant gunfire can be heard . . .")
- Gated per-faction by `FACTION.canAmbush` (24 of 33 factions can; the creature/monster/raid-immune
  factions cannot)

## Capture Points (`capturepoints`, 445 LOC)

`nut.capture:getPoint(id)`, `removePoint`, points have `captureAmount`. Faction eligibility comes from
`FACTION.canCapture` (core factions: BoS, House, Legion, NCR, ZSD-7) and `FACTION.canCaptureArea`
(customs claiming a base). Flags rendered from `FACTION.flagModel` + `FACTION.flagSkin`.
6 configs under **Capture Points**.

## Player Killing / permadeath (`playerkilling`, 215 LOC)

Admin-toggled PK state (`char:setPKActive(true)`) via `/pk` and `/pkoff`, both routed through a
confirmation dialog (`client:nutSendRequest("Bool", ...)`) and logged to **Discord** with the actor and
target SteamIDs.

Penalties are **tiered around level 50** — the same soft cap as the XP curve:

| | Below 50 | Above 50 |
|---|---|---|
| Levels lost | 5 | 2 |
| Caps lost | 500 | 1000 |

On PK the character also loses perks marked `lostOnPK` and all implants, and must change their name.

## Other territory/social systems

| Plugin | LOC | What it does |
|---|---|---|
| `guilds` | 1,662 | player-created guilds for wastelanders — claim a base, recruit. **16 configs**, the most of any system |
| `factionmanagement` | 1,374 | NCO / Officer / Lead ranks; promote, demote, rename, kick, invite; networks an MOTD |
| `areas` | 1,269 | trigger-based area system, drives `ambient` sounds and teleport zones |
| `squads` | 253 | Fallout 76-style squads |
| `factionstorage` | 641 | faction-shared storage with logs |
| `factionshop` | 2,076 | F1-menu faction store with purchase logs |
| `factionradio` / `radio` | 147 / 1,909 | per-faction radio; `FACTION.radio` sets colour, voice sounds, volume/pitch ranges, censor flag |
| `slavery` | 712 | slave collars (uses the `neck` armor slot), Legion slave mines |
| `crusifix` | 170 | Legion crucifixion prop for torturing prisoners |
| `ziptying` | 341 | restrain, search and mug players |
| `fearrp` | 41 | bindable fear/resist |
| `bountyboard` | 175 | faction donation tracking board |

## Faction karma feedback loop

`FACTION.karma = { kill = {good, bad}, passive = {good, bad} }`, ticking every `karmaTimer` (60s).
Reading the extracted table in `04_factions_data.md`, the intent is clear:

- **BoS** — kill `{1,5}` / passive `{5,1}`: killing one costs you karma, being one earns it
- **Chimera** — kill `{5,1}` / passive `{1,5}`: an "evil" faction; killing them is *rewarded*
- **Creatures / Deathclaws / Feral / Monsters / Robots** — `{0,0}`: killing wildlife is karma-neutral

So karma is a designed alignment web across factions, not just a per-player counter. Worth keeping.

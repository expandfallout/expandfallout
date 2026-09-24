# 20 - Armour

685 armour items across 14 slots, ported from Phoenix's Armor V2. The library
is `schema/libs/sh_armor.lua`, the server half is `sv_armor.lua`, and the item
contract is `schema/items/base/sh_armor.lua`.

`fo_armor_report` in console prints what loaded, the count per slot, and how
many models resolved.

---

## The slots

Fourteen, in `ix.armor.slots`. One item each.

| Pool | Slots |
|---|---|
| Head | `hat`, `mask`, `eyes`, `helmet`, `f4_helm` |
| Body | `body`, `backpack`, `bodyAccessory`, `f4_torso`, `f4_larm`, `f4_lleg`, `f4_rarm`, `f4_rleg` |
| Neither | `neck` — the slave collar |

`f4_*` are the Fallout 4 style plates, worn **over** a body armour rather than
instead of one.

Resistance is summed per pool and clamped to `armorMaxResistance` (default
**90**). Phoenix clamped to 100, which is literal immunity, while their own base
item documented the per-item max as 90 — the clamp and the contract disagreed
and the clamp was the one that ran. Set it to 100 for their exact behaviour.

`ScalePlayerDamage` applies it, because it is the only hook that says *where*
you were hit. Fall damage is excluded there and handled in `EntityTakeDamage`
instead; applying the reduction in both would square it.

Power Armour (`ITEM.isPA`) does two things to a head hit. It resists it with the
**body** pool, and it caps the headshot multiplier at `powerArmorHeadshotMult`
(default 1.75, Phoenix's "Power Armor Max Headshot Mult").

The cap needs applying explicitly and is **order-dependent**. The base
gamemode's own `GM:ScalePlayerDamage` runs *after* this hook - `hook.Add`
listeners first, then the gamemode method - and does `ScaleDamage(2)` on any
headshot. So swapping the resistance pool alone still let a full x2 land on a
sealed suit; pre-scaling by `cap / 2` here makes the net multiplier equal the cap
once the gamemode has had its turn. Worth knowing if anything ever overrides
`ScalePlayerDamage`; at present nothing does.

---

## Where equipped state lives

On the item — `item:SetData("equip", true)`, the same flag weapons use.

Phoenix stored `char:getData("equippedArmor:<slot>")` as a uniqueID string,
which cannot tell two instances of the same armour apart and so loses
per-instance data such as a suit's fusion core charge. Using `equip` also means
`sv_death.lua` already preserves armour through death, with no extra code.

**Rendering is networked separately.** `character:SetData` is registered
`isLocal = true` in Helix, so it reaches the owning client and nobody else —
useless for drawing, since everyone must see what everyone else is wearing. The
server derives a render set from the inventory and broadcasts it per slot as
`ixArmor_<slot>` on the player, alongside `ixHeadDR`, `ixBodyDR` and
`WearingPA`. The item data stays authoritative; the networked copy is always a
consequence of it.

---

## How armour draws

Not a player model swap. The character is composed from bone-merged meshes on
an animation-only skeleton (`cl_bodyparts.lua`), so an armour is one more mesh
in that list plus a statement about what it replaces:

- anything in the `body` slot hides the race's body mesh — its model *is* a
  clothed body, so leaving the bare one underneath would z-fight
- `ITEM.takesBody` hides the head, hair or beard
- `ITEM.bodyGroups` selects a variant on the mesh (visor up/down, and similar)

A missing female model falls back to the male one. Wrong-shaped armour reads
better than a character who is suddenly naked from the waist up.

The equipped set is part of the body **signature**, or equipping would not
trigger a rebuild — the player model never changes here, so a change in what is
*worn* is invisible unless it is named.

---

## The naming that was unified

Phoenix expressed one concept three ways: `specialBonus` keys were
`STR`/`PER`/`END`/…, `attributes` were `Strength`/`Perception`/…, and the
attribute registry keyed off lowercase filenames. Two of the three silently
returned nothing when read, which is why some of their armour bonuses did
nothing at all.

Here there is one convention — the lowercase keys in `ix.special.order` — and
the converter rewrote the short codes on the way in. `ix.armor.specialMap`
exists only to *read* their data, never to write it.

Speed and jump boosts are applied inside `ix.special.Apply`, not where the
armour is equipped. That function sets speed absolutely and re-runs on every
spawn and attribute change, so a boost applied anywhere else would be silently
wiped the next time a point was spent. **One place decides how fast a player
moves.**

---

## Content

The 685 definitions draw on 17 workshop packs. Ten were junctioned (all zero
Lua, ~8 GB, see `09-content-map.md`). Three carry Lua and were **not**
junctioned — `02-server-setup.md` records that junctioning
`fallout_snpcs_remastered` for a single material once dragged in ~150 VJ Base
NPCs and a wall of errors. Their assets were copied instead, into
`addons/falloutrp_armor_content/`: 125 models, 92 materials, 184 textures,
found by parsing each MDL for the materials it names rather than guessing from
paths. `cpthazama/cloak` — the stealth shader — was copied the same way.

`phoenix_hud_content` (radiation icons) and `phoenix_player_content`
(`phoenix/shared/invis`) are junctioned; both are zero-Lua.

Coverage after that: **683 of 685** worn models resolve, confirmed in-game by
`fo_armor_report`. Four drop models are substituted at load.

A missing **drop** model is substituted at load with a placeholder, so the
inventory never shows an ERROR prop — installing a pack later restores the real
one with no edit. A missing **worn** model is deliberately *not* substituted: a
wrong drop model is cosmetic, but a wrong worn model would be a lie about what
the player is protected by.

---

## Power Armour and fusion cores

A suit that is not `noCore` holds a `core` charge, 0-100, **on the item
instance** - so the charge belongs to that specific suit. This is the payoff for
storing equipped state on the item rather than on the character as a uniqueID
string, which is what Phoenix did and which cannot tell two suits apart.

**The body slot only.** Power Armour helmets are flagged `isPA` too - that is
what seals them against headshots - so anything searching every slot finds the
helmet as well and gives the player two cores to keep charged, one of which is a
hat. `GetPoweredArmor`, the `Replace Core` action, the inventory bar, the
description's core line and the server-side check all test the **slot**, not
`noCore`. That matters: most PA helmets ship `noCore = true` and would be
excluded anyway, but ten in the source data do not - BoS T-45, Vault-Tec, Shi
T-49 among them - and those advertised a core charge they can never hold. The
data is left as the source had it; the slot test is what decides.

**A PA helmet needs the suit on.** Written against `bodyType ~= "body"` so the
`f4_*` Power Armour plates are covered by the same rule. Taking the suit off
also removes its helmet and plates - without that the rule is bypassed in three
clicks: suit on, helmet on, suit off.

Drain is `coreDrainRate` per second **while moving**, on a one-second timer
rather than a think; standing still costs nothing. The default is **0.01**,
identical to Phoenix's `Core Drain Rate` (same default, same 0.01-1.00 range) -
which is slow on purpose: a full core is about 2.8 hours of continuous
movement. Raise the config if you want it to bite sooner; 1.00 empties a core in
100 seconds.

**A dead core takes your run away.** `noCoreCharge` pins run speed to walk
speed, so sprinting in an unpowered suit does nothing - you are dragging several
hundred pounds of metal by hand. Enforced inside `ix.special.Apply` rather than
where the core runs out, because that function sets speed absolutely and re-runs
on every spawn, attribute change and armour refresh; setting it anywhere else
held until the next one of those and then silently handed the sprint back.

**Power Armour cancels stamina drain** (`AdjustStaminaOffset`). The suit carries
its own weight. Only drain is cancelled, not regeneration, so a player who
climbs into a suit already winded still recovers.

**The inventory overlay** is ported from their `paintOver`: a corner square for
equipped state (green worn, red stored - Phoenix draw both, Helix's outfit base
only the green), and a core charge bar along the bottom whose colour runs green
to red through HSV as it falls, inside a black outline showing full width. At
zero the bar is replaced by a yellow lightning bolt, so a dead suit reads as
"needs a core" rather than as an empty bar. It updates live, because `core` is
item data and item data is networked to its owner.

`Replace Core` on the suit consumes anything in the inventory flagged
`isFusionCore` (keyed off the flag, not a uniqueID, so variant cores work). It
refuses a suit that is already full rather than silently eating the core, and
removes the core *before* granting charge.

`ITEM.playerHeight` is a multiplier - 35 suits set 1.1 or 1.2 - applied in
`sv_hooks.lua` on top of the race scale. Only the **model** is scaled; the
collision hull and view offset stay at the race's values, or a suit would catch
on door frames it visually fits through.

---

## Stealth

**Capability and state are different things**, and the distinction is easy to
lose in the port. A stealth suit calls `GiveStealth` on equip, which grants the
*ability*; going invisible is a separate toggle. Equipping a courser suit does
not make you vanish on the spot.

    bind x toggleStealth

The concommand is named exactly as Phoenix's so existing binds carry over. The
server re-checks everything, honours each item's own `requestStealth` veto
("you need your hands free"), and rate-limits a held bind.

The visual is theirs exactly - a **material swap**, not an alpha fade:

| Condition | Material |
|---|---|
| Moving faster than `stealthShimmerVelocity` | `cpthazama/cloak` (a Refract shader - you read as a ripple) |
| Still | `phoenix/shared/invis` |
| Holding a weapon outside `validStealthWeapons`, or in a vehicle | none - fully visible |

Applied per frame in `cl_bodyparts.lua`, not through the rebuild path: stealth
changes with velocity and what you hold, neither of which changes the *set* of
parts, so routing it through the body signature would rebuild every frame you
moved.

Capability is recomputed on every `Refresh`, so dropping a suit while cloaked
withdraws it immediately.

---

## Radiation

The HUD row index is **fixed, not a running counter**: Phoenix hard-code hunger,
thirst and radiation to rows 0, 1 and 2, and only the first two sit inside their
`hasHunger` check - so on a race without hunger the rad bar stays in the third
slot with empty space above it. A counter that incremented per drawn row put the
bar at the top of the group instead. Same numbers, wrong place.

`character:GetRadiation()`, 0-100, stored as character data. Six tiers, ported
exactly:

| Rads | Name | Effect |
|---|---|---|
| 0 | None | — |
| 20 | Minor Radiation Sickness | END −1 |
| 40 | Advanced Radiation Sickness | END −2 |
| 60 | Critical Radiation Sickness | END −3, AGL −1 |
| 80 | Severe Radiation Poisoning | max HP −5, END −4, AGL −2 |
| 100 | Fatal Radiation Poisoning | max HP −10, END −5, AGL −3 |

`AddRadiation` is ported line for line, including the parts that look odd and
are deliberate: a rad **cloud** irradiates something otherwise immune and
bypasses resistance entirely; `math.ceil` after resistance means anything
surviving is at least 1 rad, so even 90% resistance only *slows* exposure; and
the damage test uses the **unclamped** sum, so once you are at 100 every further
point costs you 10% of max health.

`applyRadiationDebuffs` was **not** in the scrape - it lived in `sv_plugin.lua`
- and is reconstructed. Max health is recomputed from the race's base rather
than subtracted from the current maximum, or crossing 80 rads twice would
compound.

The SPECIAL penalties are applied in `ix.special.Get`, the single function every
consumer already goes through - damage, stamina, run speed and the F1 tab. They
are floored at zero, since −3 Agility would otherwise feed a negative term into
run speed.

**HUD.** The bar is Phoenix's geometry exactly (icon `scrH * 0.025`, row start
`scrH * 0.765`, bar `scrW * 0.05`, rotating rad icon), the `+N RADS/SEC` counter
fades over three seconds on gain, and the screen grain is their alpha curve -
`35 * (radiation / 100)`, drawn from `HUDPaint` independently of HUD style,
because the grain is feedback about your body rather than part of the interface.

`CharSetRads` and `CharAddRads` are admin commands. **There is no radiation
source yet** - Phoenix's came from the `areas` plugin's trigger volumes and from
consumables, neither ported - so without these the system is unreachable.

---

## Active modifiers, top left

Phoenix draw this from their `buffs` plugin, not the HUD — `x, y = 10, 10`,
`UI_Regular`, `color_primary`, 20px line spacing, `TYPE +N` / `TYPE -N`, and a
modifier of zero is not drawn. All of that is matched.

**What feeds it differs.** Theirs is a real buff system: chems and faction buffs
pushed over the network into an `ACTIVEBUFFS` table. That does not exist here,
so rather than ship an empty display it reads the modifiers that are real —
armour `specialBonus` and radiation sickness, netted per attribute, plus `SPD`
and `JMP` from armour. +1 Endurance of armour against −1 of sickness therefore
shows nothing, which is both the truth and what their `value == 0` skip does.

Short codes (`STR`, `PER`, `END`, …) are used for display only - here and in
item descriptions, which read `+3 END` rather than `Endurance: +3` so the two
never disagree about the same number. `ix.armor.specialCodes` is the single map;
the unified lowercase keys still govern every read and write. A buff system later registers a function in
`ix.fallout.hud.buffSources` rather than replacing any of this.

Cached at 4 Hz, because the SPECIAL source walks the inventory and this draws
every frame. Drawn outside the HUD-style branch, like the grain — these are
facts about your body, not interface furniture, so they show even with the HUD
set to none.

---

## Testing it: armour bots

The developer terminal has a **TEST BOTS** section - first in the category list
- with DR presets across the top (0/25/50/75/90%) and every armour below,
**ordered by how much it stops** rather than alphabetically, each showing its
resistance, which pool it feeds and whether it is power armour. The search box
applies, so it answers both "give me roughly 50%" and "what does this specific
suit do".

A preset spawns the closest non-power-armour body piece to that number; 0% is a
bare bot, the control you compare against. Power armour is excluded from presets
because it changes headshots, stamina and speed as well as resistance, so a
"50% DR" preset that picked one would not be measuring what it says.

Armour rows in the normal item list keep a **BOT** shortcut, and the footer has
**BARE BOT** and **CLEAR BOTS**. Bots appear where you are looking, facing you,
frozen so they stay there.

**They respawn where you put them.** Helix respawns players from
`GM:PlayerDeathThink`, which needs a `deathTime` netvar and a client actually
running death-think - neither reliable for a bot, so a dead test bot simply
stayed dead. The respawn is explicit (`dummyRespawnTime`, default 3s) and
restores the position recorded when the bot was placed, not where it happened to
die.

**A bot is a real player, and that is the point.** It goes through every real
path - `PlayerLoadout`, the composed body in `cl_bodyparts.lua`,
`ix.armor.Equip`, `ScalePlayerDamage` - so what you shoot is exactly what a
player in the same suit would be. An earlier attempt used a scripted entity
carrying its own copy of the armour rules; that could only ever tell you how
*that entity* resisted damage, which is not the question being asked.

This works because **Helix already makes bots playable**: `GM:PlayerInitialSpawn`
gives any bot a real character, a random faction, a model and a non-saving
inventory. Without a character a player is invulnerable
(`PlayerShouldTakeDamage` returns `GetCharacter() != nil`) and spawns no-draw,
locked and not solid.

Two ordering details that are easy to get wrong:

- **The bot exists before its character does.** Our `hook.Add` listener runs
  before `GM:PlayerInitialSpawn` - Helix's hook order ends with `hook.ixCall`,
  which runs `hook.Add` listeners and only then the gamemode method - so setup
  is deferred rather than done inline.
- **`inventory:Add` is asynchronous.** The item instance does not exist until
  the database write returns, so equipping is deferred too; doing it
  immediately finds nothing to equip.

`RunConsoleCommand("bot")` returns no handle, so requests are queued and claimed
by the next bot to appear - which is also why a full server is checked *before*
asking, rather than leaving a queued request for the next real player to claim.

Armour goes into the bot's real inventory and is equipped through
`ix.armor.Equip`, so every rule applies. A Power Armour helmet needs its suit,
so `ix.armor.FindMatchingSuit` supplies one - matched on the longest shared
uniqueID prefix, `armor_bos_t45_helmet` finding `armor_bos_t45_armor`.

Bot slots come out of `-maxplayers` in `startserver.bat` (currently 5).

---

## Not built yet

- **Rad sources.** No trigger volumes, no radaway/rad-x consumables. The
  commands above are the only way to gain or shed rads.
- **`radman` perk** and the `RAD-RES` buff both stack into
  `GetRadiationResistance` and are guarded, because perks and buffs do not
  exist. Armour is currently the only contributor.
- **`takesRadiation` per race.** Ghouls and robots are immune in Phoenix; races
  here carry no such flag, so it reads `race.takesRadiation` when present and
  defaults to taking rads.
- **Stealth description distance.** `stealthDescriptionDistance` is registered
  and has no consumer - it needs the description/inspection UI.
- **PA chem whitelist.** `paAllowedChems` is not enforced; there are no chems.
- **The buff system itself.** `nut.buffs` (chems, faction buffs, `RAD-RES`,
  `DR`/`HP`/`DMG` types) is not ported. The top-left display is built and
  reads real modifiers; a buff plugin registers into `buffSources`.

---

## A Stealth Boy cloaks you; a suit only lets you

This is what "stealth boys don't work" was. The Stealth Boy grants a `STEALTH`
buff, `ix.armor.CanStealth` then answers true — and **nothing anywhere turned
stealth on**. The only route was the `toggleStealth` concommand, which has no
default key, so unless the player had already bound it, using a Stealth Boy did
nothing observable at all.

A Stealth Boy is not a permission slip, it is a device you switch on. So
`ix.armor.SyncStealth` runs from `ix.buff.Refresh` — after every add, remove and
expiry — and the field comes up when the chem is used and drops when it runs
out, with no second timer that could disagree with the buff's own.

It remembers *why* you are cloaked (`client.ixStealthFromBuff`). Somebody who
cloaked with a suit and then took a Stealth Boy is not uncloaked when the chem
wears off: they were already hidden and nothing about their suit changed.

A suit is the other thing — it lets you cloak when you choose. `/stealth` is
that switch with a name the chatbox can complete; `toggleStealth` is kept under
Phoenix's own name so binds carried over from their server still work. Both ask
the suits' `requestStealth` veto first, which is where "you need your hands
free" lives.

### The material outlives the body

Cloaking applied the stealth material to the bone-merged parts *and* to the
player entity — the latter added when creature races started rendering their own
carrier mesh. The Think hook that applied it iterated `rendered`, the table of
built bodies, and that is what left a character **permanently invisible with no
shimmer**: cloak, then do anything that drops the body (die, respawn, change
race, go dormant) and `ClearBody` removes the entry, so the loop never visits
that player again and the material it last set is never taken off.

The loop is now driven by the player list, and it compares against what *it* last
set rather than reading `GetMaterial()` back — a freshly spawned player can
report the old value for a frame, which was enough to skip the clear.
`GetStealthMaterial` returns `""` for anybody not cloaked, so every frame is
self-healing.

`ixStealth` is also a networked bool that survives dying, so death now clears it,
and a spawn-time check unsticks anyone already wrong.

### `GetMaterial()` cannot be read back from a ClientsideModel

**This was the real one**, and it survived four fixes because every diagnostic
was reading the same lie.

`Entity:SetMaterial` on a `ClientsideModel` applies the override properly — the
mesh really does draw with it. `Entity:GetMaterial` does **not** read that back:
it returns the networked material field, which only the server writes, and for a
clientside entity nothing ever does. It answers `""` for ever.

The bone-merged body parts are clientside models, and the loop that applied the
stealth material guarded on `part:GetMaterial() ~= material`:

| | comparison | result |
|---|---|---|
| cloaking | `"" ~= "phoenix/shared/invis"` | true — applied |
| uncloaking | `"" ~= ""` | **false — never cleared** |

Cloaking worked, uncloaking silently did nothing, and the player stayed
invisible with every other piece of state correctly reporting they were not
cloaked. The `fo_stealth` output that finally caught it said exactly that:

```
[server] stealthState=1  IsStealthed=false
[client] stealthState=1  IsStealthed=false  wants=''
[client] player material=''  parts=2
[client] part materials: '' ''
```

Both realms agreed, the materials read as empty, and the character was
invisible. `fo_unstealth_client` fixed it only because it called `SetMaterial`
unconditionally.

What we set is now tracked in a Lua field on the entity (`ixStealthMaterial`) —
ours, written where the material is written, and absent on a freshly built part
so a body rebuilt while cloaked gets the material on the next pass. The
diagnostics print that field rather than `GetMaterial()`.

The lesson generalises past this bug: **a getter is not necessarily the inverse
of its setter.** Three of the four failed fixes were correct code built on the
assumption that it is.

### `SetNW2Bool(name, false)` does not network

**This was the bug all along**, through three attempted fixes. Stealth state was
`SetNW2Bool("ixStealth", ...)` read back with a `false` fallback. Writing an NW2
var with the *same value as its default* does not network a change — it removes
the var — and that removal does not reliably reach clients that already hold a
value.

So turning stealth **on** networked fine, and turning it **off** changed the
server and left every client still believing the field was up. Everything
downstream then behaved perfectly on wrong input: the client kept painting the
cloak material because its copy still said true, and the server-side reconcile
skipped the player because its own copy already said false. Both halves agreed
with themselves and not with each other — which is exactly the failure that
reading one realm cannot show, and why the earlier fixes to the *client* loop and
to the *server* events both changed nothing.

It is now `SetNW2Int("ixStealthState", 1)` for off and `2` for on. Neither is the
default, so both always network. 0 means "never set" and reads as off. Every
read goes through `ix.armor.IsStealthed(client)` — the nine call sites each spelt
out the NW2 read and its fallback, which is nine chances to get the fallback
wrong.

### Ending a chem's field early spends the chem

The HUD kept showing `STEALTH +1  33s` on a character who was plainly not
cloaked — because the buff really was still there. Breaking the field (drawing a
weapon, dying, `/stealth`) turned the field off and left the Stealth Boy running.

The visible half was the HUD. The other half was worse and only a matter of
time: `CanStealth` reads that buff, so a broken field would have come **back**
the next time anything called `ix.buff.Refresh` — `SyncStealth` would see a live
buff and no cloak and switch it on again. Drawing a weapon would have un-cloaked
you only until the next chem was taken or wore off.

`SetStealth` now clears the STEALTH buff when the field goes down and
`ixStealthFromBuff` says a chem was paying for it. A suit's field is not spent by
being switched off, and has no buff to clear.

Two details: the buff is cleared **after** the networked var is written, because
`ix.buff.Clear` runs a refresh that re-enters `SyncStealth` and that has to see
the field already down; and the death and reconcile paths no longer clear
`ixStealthFromBuff` themselves, since doing so hid the flag from the one function
that acts on it.

### The field is derived, not latched

`ixStealth` is a bool on the player, and every fix up to this point was "turn it
off at the right moment" — buff expiry, armour refresh, death, spawn. Each of
those is a moment that can be missed, and missing **one** leaves a character
cloaked for ever with nothing that will ever ask again. That is what "still
invisible after the Stealth Boy wore off" was, twice.

So the question is asked continuously instead: once a second, anybody cloaked is
checked against `ix.armor.CanStealth` — the buff and the equipped armour, the two
things that actually pay for a field — and if nothing is paying, it goes off.
Whatever event was missed, this catches it within a second, and it cannot itself
be missed because it is not driven by an event.

`SyncStealth` still does the turning **on** from `ix.buff.Refresh`, because a
Stealth Boy should cloak you the instant you use it rather than up to a second
later. Only the off is unconditional.

**`fo_stealth` and `fo_stealth_client`** print what each realm believes: cloaked,
whether a chem put it there, the buff value, whether anything is paying, and
which material is on the player. This bug was diagnosed wrong twice from reading
the code, because the failure is a *disagreement* between two realms and reading
one of them cannot show it.

### A Stealth Boy is not yours to switch

While the chem's buff is up, `/stealth` and the `toggleStealth` bind both
refuse. Two things driving one switch disagree the moment the timings cross —
and turning it off manually would be free invisibility later, since the next
`ix.buff.Refresh` would put it straight back on. That is one Stealth Boy spent
on several cloaks.

The visual itself was never the problem: both materials are installed
(`phoenix/shared/invis` in `phoenix_player_content`, `cpthazama/cloak` in
`falloutrp_armor_content`) and the material swap in `cl_bodyparts.lua` works.

## Power armour has to be learned

Phoenix's rule, to the letter. A suit flagged `isPA` cannot be put on until the
character has read a **Power Armor Training Manual**
(`items/sh_book_patraining.lua`, Phoenix's `sh_book_patraining` — read once,
consumed, `paTraining` written on the character). `ix.armor.Equip` refuses
with `armorNeedsTraining` otherwise.

**A permanent kill takes it with the life.** `ix.pk.Collect` clears
`paTraining` and calls `ix.armor.StripPowerArmor`, which unequips every powered
piece the character has on, so they respawn out of the suit and read the book
again or stay out of it.

**Salvaged frames are the exception.** `ITEM.isSalvagedPA` — Phoenix's own
flag, carried on the three Legion salvaged pieces — marks a frame somebody has
stripped the fusion systems out of; it is worn like heavy armour and needs no
training. The live editor's ARMOUR section has it as *Salvaged power armour*
so any suit can be made one without touching a file.

## Backpacks

Phoenix's backpacks were two things at once — armour for the `backpack` slot,
drawn on the back, and a storage that lived in a server file the scrape does
not have. After wearing one here they are two things **separately**:

- **The twelve coloured packs are cosmetic.** `items/armor/sh_armor_*_backpack_*.lua`:
  armour, drawn on the back, holding nothing. The first version gave each a
  bag; that is gone, and any pack already made under it carries a stale `id`
  in its data that nothing reads.
- **The Small, Medium and Large backpacks are bags.** `items/bags/sh_backpack_*.lua`,
  on Helix's own `base_bags` — the folder name picks the base — and all three
  on `models/galang/fallout/clutter/classicbackpacklarge.mdl` (the
  contributor content pack also has a `classicbackpackmedium` and
  `classicbackpacksmall`, unused). They take **1x1, 2x2 and 2x3** of the
  inventory and hold a container whose size is the dev config's **Backpacks**
  block (4x2, 5x3 and 6x4 by default). They open on a **click** of the icon
  (`libs/cl_backpack.lua` wraps the icon's mouse release: a left click that
  did not become a drag opens the window, a second one closes it) or with
  *Open* on the right-click menu, and can be **renamed** — see
  [32-rarity.md](32-rarity.md#naming-one).

`ix.backpack.Bag(ITEM, "small")` at the bottom of each bag item adds what
Helix's bag does not have: the size read from the configs (re-registered on
`InitializedSchema`, once the saved configs are in), the description saying the
current size, growing an existing pack to a raised config when it is next sent
to its owner (never shrinking — a bag with things in it that shrinks loses
them), the Rename entry, the window, and **crates**.

**Into crates.** Helix refuses a bag inside any storage (`nestedBags`, "you
cannot put an inventory inside of a storage inventory") because every container
this schema makes carries `vars.isBag = true`, the flag Helix's own containers
plugin sets. A bag's own inventory carries the flag too, but as its item's id —
a *string* — and that is the one case that stays refused: a pack inside a pack.
A crate, stash, faction storage, bench or bin takes a pack like anything else
(`ix.backpack.IsContainer`). The bag's `CanTransfer` says so, and a
`CanTransferItem` hook says it for Helix's gamemode rule; because a hook that
answers skips the gamemode function *and* the schema's other listeners, the
check that matters is made there: the mover must be somebody both inventories
are shown to, and a storage's receivers are the people the server let open it.

**The window.** Helix parents a bag's window to the menu's tile canvas, and
this schema's menu pads that canvas down to the main grid's exact size to
centre it — so the window was laid out below the visible edge and clipped,
which was "clicking the backpack doesn't pop up the storage". `ix.backpack.Open`
(`cl_backpack.lua`) makes it a **popup of its own** instead, the way Helix's
storage window is - on top of the menu, beside the main grid in screen space,
packs stacking below each other, on the left when the right of the screen is
too narrow, and gone when the menu goes. The first fix put it on the menu page
as a child, which was still not drawn; a popup is - and the popup was not
drawn either, and that one was the real cause all along: while the main grid
exists, Helix's `SetInventory` marks every other inventory window "painted
manually" for Helix's own menu to paint, and this schema's menu paints no
such thing (gotcha 32). `SetPaintedManually(false)` straight after
`SetInventory`. And a popup of its own takes turns with the menu — whichever
was clicked last is on top, so the first click back on the menu to drag an
item over buried the pack — so it is a **child of the menu** now (of the
storage view in a storage), drawn after it and moving with it; both cover the
whole screen, so its screen-space placement still holds. Helix's `openBags`
option opened every pack the moment the menu did, through the pack's own View;
it is off and hidden now, and a pack opens on a click or from its menu.
**Dropping onto a pack** puts the item inside on any square of the icon, and
none of Helix's own chain is used to decide it, because all three parts of that
chain answer only on the top-left square. `vgui.GetHoveredPanel` picks the
combine target during the drag; `IsAllEmpty` gets first refusal and reads the
panel's slot table; and the drop cell is computed as
`(x - 4 - (gridW - 1) * 32) / iconSize`, where the 32 is half an icon size this
schema does not use, so the cell is already wrong by up to a square. (The
client's inventory is no help either: it is told each item once, at its
top-left square, so `GetItemAt` calls every other square an item covers
empty — the server fills them all, the client does not.) `cl_backpack.lua`
wraps `ixInventory:ReceiveDrop` and takes the drop first: the square under the
**cursor**, the item whose footprint covers it (`ix.backpack.Covering`), and
the combine sent straight to the server, which is all Helix's path does at the
end of it. The item log names the pack —
"moved from <character> to the Small Backpack (item 213) of <character>" —
where it used to name the character twice, because a pack's storage belongs to
the character carrying it (`ix.backpack.ItemOf`). `ix.backpack.Open`
still prints one line to the client console every time — the item, the inventory id, whether that inventory is
loaded on the client, whether the menu and a storage are open — and the two
ways it can bail say so in a notice instead of silently.

The earlier *Backpack, Small / Medium / Large* armour items are gone. Any of them
still in a database are **renamed** to the bag ids once, on the first load after
the change (`libs/sv_backpack.lua`, remembered in `ix.data` as
`backpackMigrated`), and keep their contents: a pack carries its inventory's id
in its data and the bag base reads the same field.

## The Stealth Boy Mk II

`items/armor/sh_armor_stealthboy_mk2.lua`: the chem's field, worn. It takes
the body-accessory slot, draws nothing on the body, carries `hasStealth` like
the courser suit, and `GiveStealth` / `SetStealth` on equip and unequip — so
while it is on, the stealth key works exactly as it does in a stealth suit.

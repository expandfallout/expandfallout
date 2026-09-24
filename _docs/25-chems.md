# 25 - Chems, buffs and addiction

Three systems, in dependency order: **buffs** are timed stat modifiers,
**addiction** is a durable fact that produces buffs, and **aid items** are what
grants both.

Nothing in the buff library knows what a chem is, and nothing in the chem items
knows how a stat is applied. That split is what lets a chem be written as five
lines of data.

---

## Buffs — `libs/sh_buff.lua`, `sv_buff.lua`, `cl_buff.lua`

A buff is a named amount of a named stat, for a length of time. Phoenix's
`nut.buffs` is the model — their whole chem roster is written against thirteen
stat names and these are the thirteen.

| Stat | Read by |
|---|---|
| `SPD` | `ix.special.Apply` — run speed |
| `HP` | `characterMeta:ApplyBodyState` — maximum health |
| `DR` | the `ScalePlayerDamage` hook in `sv_armor.lua` |
| `DMG` | an `EntityTakeDamage` hook, on the **attacker** |
| `RADRES` | `ix.armor.GetRadResistance` |
| `STEALTH` | `ix.armor.CanStealth` |
| `STR PER END CHR INT AGL LCK` | `ix.special.Get` |

**Every one of those is a consumer that already existed.** A buff joins the
chain a system already has rather than opening a second one — the alternative
is two places deciding how fast a player moves, and which wins depending on
which ran last.

`STEALTH` is the odd one: its *value* is meaningless, any positive amount means
"you can cloak". It is a buff purely so that it expires by itself rather than
needing a second piece of timing machinery.

### Runtime only, deliberately

Buffs live on the player and die with the session and with death. A chem you
took twenty minutes before a restart should not still be running, and
reconnecting to reset a two-minute timer is not an exploit worth the storage.

Withdrawal penalties are the exception and they are *still* not stored as
buffs: `ix.addiction` holds the addiction on the **character** and rebuilds its
penalties on spawn. One durable fact, one derived consequence.

### The whole list is networked, not a delta

Phoenix send add, remove, remove-timed and clear as four messages and replay
them client-side. That is four chances to drift — a missed message leaves a
buff on the HUD that expired minutes ago. A full list is a few dozen bytes and
cannot drift.

Remaining time is sent as **seconds left**, not as an end time: `CurTime` is not
the same number on both machines.

### Two things poke, four do not

`SPD` and `HP` need `ix.buff.Refresh` because speed is *set* and max health is a
property. `DR`, `DMG`, `RADRES` and SPECIAL are read at the moment they are
used, so a buff is in effect the instant it is in the table.

`Refresh` does not write max health itself — `ApplyBodyState` owns it and
computes race base + radiation tier + `HP` buff together.

---

## Addiction — `libs/sh_addiction.lua`, `sv_addiction.lua`

Taking a chem rolls against its `addictionChance`. An addiction has a
**severity** of 0–3 that climbs the longer you go without a dose.

**What climbs it is time since the last dose**, not time since the addiction.
Taking the chem resets it to zero. That is the whole shape of the thing: an
addiction costs nothing while you feed it and everything when you cannot.

Severity is **calculated** from `os.time()` of the last dose rather than counted
up, so time that passed while the server was off still counts — log out in
withdrawal and you come back worse, not frozen. `os.time` rather than `CurTime`
because `CurTime` restarts with the map.

### Endurance resists it

`chance × (1 - min(END, 10) × 0.05)`. Ten Endurance halves the chance; it never
reaches zero. Gives the attribute a second job beyond stamina, and makes the
same chem a different decision for different characters. **Not Phoenix's** —
theirs is a flat roll.

### Effects are cumulative, and rebuilt rather than adjusted

Severity 3 carries the entries for 1 and 2 as well, so three identical −15 Speed
steps read as −15 / −30 / −45 — which is exactly how Phoenix write Jet.

Every change clears this character's withdrawal buffs by id and applies the
whole set again. Phoenix add and remove individual buffs as severity moves, and
their `onClearAddiction` has to unwind exactly what was applied — three
branches, each removing a different total, and any mismatch leaves a permanent
penalty nothing can find. Rebuilding cannot drift.

Removal is **by id**, not `ix.buff.Clear`: a player can be high on Jet and
withdrawing from Psycho at the same time, and curing one must not cancel the
other.

### Two kinds

`timedClear` addictions burn out once you have gone a step past the top. The
rest sit at maximum severity until cured with Fixer or Addictol. Phoenix carry
the same flag; Buffout is their example of the first, Jet of the second.

---

## Aid items — `items/base/sh_aid.lua`

The field contract is Phoenix's, so their roster converts mechanically:
`aidID`, `effectSound`, `addictionName`, `addictionChance`, `injectFlavour`.

**Written as data, not functions.** Their items each carry `effectFunctions`
with a SERVER and CLIENT half, and every one is a few lines calling
`nut.buffs:add`. Here a chem declares what it grants:

```lua
ITEM.buffs = {
    {stat = "SPD", value = 30, duration = 60}
}
```

which the description builder, the report and the item itself can all read. A
function can only be read by running it — which is why their descriptions are
hand-written strings sitting next to the numbers they describe.
`effectFunctions.OnConsume` still exists for anything a table cannot express.

`aidID` is the identity of the **effect**, not the item: Mentats and Berry
Mentats share one, so you cannot stack them. Nil means it can be taken on top of
itself, which is right for a stimpak.

### Who can take one — `RACE.canUseChems` and `ITEM.mechanical`

A race with `canUseChems = false` is refused **every aid item except those
marked `ITEM.mechanical`**, which is how a robot takes a repair kit and nothing
else:

```lua
local race = ix.races and ix.races.Get(character:GetRace())

if (race and race.canUseChems == false and not self.mechanical) then
    return false, "your kind has no use for chemistry"
end
```

Two kits carry the flag — Repair Kit and Robot Repair Kit — and both are
generated, so the flag lives in `_docs/tools/chems.py` (`mechanical=True`) and
not in the item file. `canUseChems` is edited in `/liveedit` under RACES; absent
means **true**, so nothing changes for a race nobody has touched.

Both fields are editable live: see [44-live-editor.md](44-live-editor.md), which
also covers editing a chem's **buffs** — the SPECIAL bonuses, DR, SPD, RADRES,
DMG, HP and STEALTH, with a duration shared by all of them.

### Which chems — the race's lists

Phoenix gated on a whitelist and a blacklist (`getRaceChemWhitelist`,
`getRaceChemBlacklist`) and the aid base has read `RACE.chemWhitelist` and
`RACE.chemBlacklist` since it was written; the live editor's RACES section now
has both as **Chems it can take** and **Chems it cannot take**, a grid of
ticks over every aid item. Tick any on the first and the race can take *only*
what is ticked; **nothing ticked means no list** (an empty list is not "takes
nothing" — `canUseChems` is for that). The second refuses what it names
whatever the first says. Repair kits (`ITEM.mechanical`) ignore the whitelist,
because a spanner is not a chem; they do obey the blacklist.

### Gates

- **Race** — `ix.races.GetChemWhitelist` / `GetChemBlacklist`. No race defines
  either yet, so both are inert; adding `chemWhitelist = {...}` to a race is the
  whole change.
- **Power armour** — a sealed suit is the point of power armour and a needle
  does not go through one. `ix.armor.paAllowedChems` is a **whitelist**: a chem
  added later does not work in a suit until somebody decides it does. A
  blacklist fails silently and in the player's favour, which is the wrong way
  round for a restriction.
- **Already running** — a second dose of the same `aidID` refuses.

### Inject

Five-second stared action on another player, same shape as the food base's
Feed. Re-checked on completion: five seconds is long enough for the item to have
been dropped, or for the target to have put a suit of power armour on.

### The dose comes before the roll

Feeding an existing addiction resets its clock and clears its withdrawal; only
then does an unaddicted character roll to gain one. In the other order a
character who just got hooked would immediately have it "fed", and one already
hooked would roll again for something they have.

---

## The roster

**64 items, 38 distinct models, 28 addictions.** Every model and every sound was
checked against the files on disk before shipping — a missing model is an error
ring, a missing sound is silence.

Models come from `af_content_pack_6` (`roadkill/fallout/clutter/aid/`) and
`phoenix_dickmosi_stuff` (`mosi/fnv/props/health/` and
`mosi/fallout4/props/aid/`), both mounted. Sounds are Phoenix's own
`phoenix/itm/npc_human_using_*`.

| Group | Items |
|---|---|
| healing | Stimpak, Super Stimpak, Auto-Inject Stimpak, Auto-Inject Super Stimpak, Diluted Stimpak, Stimpak Diffuser, Healing Powder, Bitter Drink, Blood Pack, First Aid Kit, Doctor's Bag, Bio Gel, Sludgepak, Hydra, Snakebite Tourniquet, Antivenom, Alien Epoxy, Repair Kit, Robot Repair Kit |
| radiation | Rad-X, Rad-X (Brotherhood), Rad Shield, RadAway, Diluted RadAway, Anti-Resin |
| speed | Jet, Ultrajet, Jet Fuel, Rocket, Turbo, Buffjet |
| combat | Psycho, Psycho-Jet, Psychobuff, Psychotats, Slasher, Overdrive, Fury, Berserk, Med-X, Auto-Inject Med-X |
| mind and stat | Mentats, Berry / Grape / Orange / Party Time Mentats, Bufftats, Calmex, Buffout, Steady, Rebound, Day Tripper, Daddy-O, Cateye, X-Cell, Ant Nectar, Cloud Kiss, Mysterious Serum |
| tribal and improvised | Coyote Tobacco Chew, Datura Hide, Turpentine |
| cures and utility | Fixer, Addictol, Stealth Boy |

### Variants share models, and are told apart by a marker

Twenty-five of the sixty-four share a model with something else — Psycho,
Psycho-Jet, Psychobuff, Psychotats, Overdrive, Fury and Berserk are all the same
syringe. Each carries a `tint`, drawn as a small coloured square in the corner
of the inventory icon, where the armour base already puts its equipped dot.

**The generator refuses to write a roster where two chems share both a model and
a marker.** It caught two real collisions the first time it ran — Jet against
Ultrajet, and Healing Powder against Bitter Drink — which would have shipped as
identical icons.

### Generated

`items/aid/*.lua` and `libs/sh_addictionlist.lua` are **generated** from a
roster table. Forty near-identical files hand-written is forty chances for a
typo in a model path, and the generator verifies every model and sound exists
before it writes anything.

```bash
python _docs/tools/genchems.py
```

The roster is `_docs/tools/chems.py`. Edit there and regenerate; the item files
say so at the top, because the obvious thing to do with a generated file is edit
it.

Withdrawal is registered **centrally**, not on the items: five kinds of Mentats
share one addiction and Jet and Ultrajet share another, so putting it on the
item would mean five copies and five chances to disagree.

---

## Commands

```
fo_buffs                         what is currently acting on you
fo_addictions                    what you are hooked on, and how badly
/charcureaddictions <player>     cure everything (admin)
```

Configs: `addictionEnabled`, `addictionSpeed`, `buffHUD`.

---

## Notes

- The HUD registers into `ix.fallout.hud.buffSources`, the extension point
  `cl_hud.lua` was already written for. A second painter in that corner would
  have had to guess where the first stopped.
- `cl_buff.lua` sits in **two** load-order traps: `libs/` loads before
  `fallout_ui/`, and within `libs/` it sorts before `sh_addiction`. Both are
  handled — the table is created defensively and the HUD registration is
  deferred to a zero timer. See `16-ui.md`.
- `ApplyRadiationDebuffs` was renamed `ApplyBodyState` when chems arrived,
  because it stopped being about radiation.
- Negative modifiers now draw **red** on the HUD. Armour's trade-offs are ones
  you chose and can see on the item; a withdrawal penalty is something
  happening to you, and it reading the same as a bonus is the difference
  between noticing it and not.
- **Not yet built:** their chem-crafting benches (`drugs_advanced`).

---

## Screen effects — `libs/cl_chemfx.lua`

Two sources, one renderer: withdrawal effects come from the addiction's
severity, a chem's come from its `aidID` while the buff is running. Both land in
one table and one `RenderScreenspaceEffects` pass, so being high on one thing
while withdrawing from another composes rather than fighting.

Phoenix's four, at their settings — `DrawSobel(0.5)`, `DrawSharpen(0.8, 0.8)`,
`DrawMotionBlur(0.4, 0.8, 0.01)`, `DrawToyTown(2, ScrH()/2)` — plus six new
colour grades: `grey`, `rage`, `clarity`, `nightvision`, `euphoria` and
`nausea`. Their entire roster only ever reaches for Sobel and Blur, on Jet, and
a wasteland of drugs that all look the same going down is a missed opportunity.

Effects are keyed **by source**, so two addictions both asking for `sobel` is one
Sobel that lasts until both have gone. The set is rebuilt twice a second from
what is currently true rather than added to and removed from — buffs expire on
their own, so an event-driven version would leave a chem's effect running until
the next sync.

Withdrawal effects are declared **per addiction**: withdrawal from Cateye should
hurt your eyes and withdrawal from Psycho should not. An addiction that says
nothing gets Phoenix's default — nothing, then desaturation, then blur.

`useEffect` picks the flash and noise going in: `inject`, `swallow` or `inhale`.
Sent from the server rather than played by the item's client half, because the
person being dosed is not always the person holding the item.

---

## Healing over time — `libs/sv_healing.lua`

A stimpak runs for a few seconds and **stops the moment you are hit**. That is
what makes healing something you break contact to do, rather than a free reset
mid-firefight. Whatever is left when it is interrupted is lost.

One heal at a time; a second replaces the first rather than stacking, or two
stimpaks would heal twice as fast for the same total and the interruption would
mean nothing.

`healTime` of 0 is instant, which is right for the things that are not stimpaks
— a blood pack goes in all at once. `PlayerHurt` rather than `EntityTakeDamage`,
because only damage that actually landed should interrupt: a shot the armour
absorbed entirely did not.

---

## Jumping — `libs/sh_jump.lua`

Helix charges stamina for sprinting and nothing else, so jumping was free and
bunny-hopping beat running. A jump now costs `100 / 4.5` stamina, and:

> once you cannot afford a jump, you cannot jump again until stamina is full.

Without that second half a player waits for one jump's worth to regenerate and
hops forever, slower. With it, running out is a real interruption.

**The half is deliberate.** At exactly four jumps the fourth empties the bar
precisely and whether it is allowed depends on floating point; at four and a
half the fifth is unambiguously refused with 11 stamina still showing, which
reads as "not enough" rather than as a bug.

Shared, because movement is predicted — the client has to reach the same
decision or the player's own jumps stutter and snap back. `SetupMove` is the
only place a jump can be stopped before the player has left the ground, and only
the tick the key **goes down** counts, or holding space would empty the bar in a
third of a second.

Power armour is exempt, as it is for sprint drain.

**Endurance buys more of them.** `ix.jump.Cost` scales `jumpStaminaCost` by the
effective stamina pool (`100 / ix.special.GetMaxStamina`), the same way
`AdjustStaminaOffset` scales the drain — the bar is hardcoded 0-100, so a bigger
pool has to make each jump cost less of it. Without that, Endurance made the bar
last twice as long at a sprint and left the jump count exactly where it was.

The cost is edited in `/liveedit` under SPECIAL → Endurance, as **jumps from a
full bar** rather than as a stamina figure.

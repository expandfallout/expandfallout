# 32 - Weapon crafting quality

Every weapon that comes off a bench is rolled for a tier. The tier is a damage
multiplier and a coloured border.

| tier | damage | colour |
|---|---|---|
| Common | 1.0x | white |
| Uncommon | 1.1x | lime |
| Rare | 1.2x | lapis |
| Superior | 1.3x | eggplant |
| Legendary | 1.4x | orange |
| Master Craft | 1.5x | rainbow (animated) |
| Pearlescent | 2.0x | neon cyan |

| | |
|---|---|
| `libs/sh_rarity.lua` | tiers, the curve, the border |
| `libs/sv_rarity.lua` | rolling on craft, and the damage hook |
| `libs/cl_rarity.lua` | borders and descriptions on all 259 weapons |
| `derma/cl_rarityodds.lua` | the QUALITY tab |
| dev menu -> RARITY | the curve, and a 10,000-roll sample beside it |

---

## The curve

Anchored at **50 Luck**, where the numbers were specified:

> Superior 20%, Legendary 5%, Master Craft 1%, Pearlescent 0.1%, Rare the
> rest, and no Common or Uncommon at all.

Everything below is derived from three rules rather than a table of
breakpoints, because a table has to be kept consistent with itself and this
cannot be inconsistent:

1. the four top tiers scale linearly with Luck to those percentages
2. Common fades out by 25 Luck, Uncommon by 50
3. Rare takes whatever is left

| Luck | Common | Uncommon | Rare | Superior | Legendary | Master | Pearl |
|---|---|---|---|---|---|---|---|
| 0 | 60% | 30% | 10% | — | — | — | — |
| 10 | 46.1% | 30.7% | 17.9% | 4% | 1% | 0.2% | 0.02% |
| 25 | — | 37.3% | 49.7% | 10% | 2.5% | 0.5% | 0.05% |
| 40 | — | 14.8% | 64.3% | 16% | 4% | 0.8% | 0.08% |
| **50** | — | — | **73.9%** | **20%** | **5%** | **1%** | **0.1%** |

It lands exactly on the specification at 50 because Common and Uncommon have
both reached zero and Rare is the only thing left holding the remainder.

**50 Luck is not the skill point cap.** `maxAttributes` stays at 25 — that is
what a character can *buy*. 50 is what they reach wearing and taking the right
things, since `ix.special.Get` adds buff modifiers without clamping to the
buyable ceiling. Raising `maxAttributes` to 50 would have been the wrong fix:
it would have moved stamina, damage and run speed with it, and made the top of
the curve free.

---

## Details worth knowing

**No rarity is not Common.** `ix.rarity.Get` returns nil for a weapon that was
never rolled — one spawned by an admin, or found as loot. It draws no border
and claims no multiplier. Only crafted weapons carry a quality.

**Rolled when it is made, not when it is used.** The tier lives in item data
next to the stack count, so it survives being dropped, traded, stored and
restarted — and cannot be re-rolled by putting the weapon down and picking it
up again.

**Weapons are rolled one at a time.** `ix.bench.Produce` stamps the same data
on everything it makes, which is right for the experience owed and wrong for
quality: two rifles out of one job are two separate objects and deserve two
separate rolls.

**`EntityTakeDamage`, not `ScalePlayerDamage`.** The latter only fires for
players, so a Legendary rifle would do its extra damage to people and nothing
extra to a deathclaw. The multiplier is read off the *item* via
`weapon.ixItem`, so a weapon dropped and picked up by somebody else keeps its
quality.

## What a weapon says

```
Rare R-700

A awesome sniper rifle.

Base DMG: 90 [108 - Rarity]
RPM: 40

* Head: 3x [3.6x - Rarity]
* Body: 1.5x [1.8x - Rarity]
* Legs: 1x [1.2x - Rarity]
```

**Base damage is the weapon's own**, before rarity and before SPECIAL. The
final number depends on who is holding it — a rifle is worth more to somebody
with the Perception for it — and a description that changed depending on who
opened it would be lying to one of them.

**The tooltip is coloured by tier**, not the base yellow. `SetImportant` paints
the name row `ix.config.Get("color")` for every item; the `PopulateItemTooltip`
hook repaints it, because a Legendary rifle should be recognisable before the
text is read. It uses the tier's flat colour rather than `GetColor` — a tooltip
row paints once when built, so Master Craft would freeze on whatever hue it was
born with rather than cycling.

**The name is set in two places and they are not redundant.** The `GetName`
wrap covers everywhere a name is printed — chat, notifications, the inventory
label. The tooltip hook covers the tooltip, because that is also where the
colour changes and a colour is not part of a name; it re-checks the prefix
rather than assuming, so it is correct whether or not the wrap took.

**The crosshair readout shows the rarity damage**, via the
`GetWeaponDisplayDamage` hook `cl_damageview.lua` was written with. It returns
the new *base*, not a bonus: the readout computes the SPECIAL bonus as
`damage * (multiplier - 1)` after calling it, so handing over the
rarity-adjusted damage is what makes buffs apply to the weapon this actually is
rather than the one it would have been unrolled.

---

## Naming one

`libs/sh_rename.lua`. Phoenix let a Master Craft or Pearlescent gun be named,
and a bag; so does this. **Rename** on the right-click menu opens a box; the
name is stored as item data (`customName`, thirty-two characters, control
characters stripped, blank takes it off) so it travels with the item through
drops, trades, bags and the market, and shows everywhere the item's name is
printed — label, tooltip, chat, pickup notice, the bag's window title. The
maker's own name is kept in the description underneath ("Its makers called it a
R-700"), because "Lucky" tells you nothing about what it fires.

**The tier stays in front.** `cl_rarity.lua` wraps `GetName` to put the tier
first and this wraps it again, in whichever order the two `InitializedPlugins`
hooks run: the plain name is *replaced inside* whatever the other wrap
produced, so "Pearlescent R-700" named Lucky is "Pearlescent Lucky" either way
round. Weapons get the entry by injection on `InitializedPlugins` like the
brand does (Helix copies a base into each item, so adding to `base_weapons`
after the fact reaches nothing); bags get it from `ix.backpack.Bag`.

Who may: whoever holds it — the item has to be in an inventory the asker owns,
a bag of theirs included (`item:GetOwner()`), and be a Master Craft or
Pearlescent weapon or a backpack. `CanRenameItem` is a hook for anything else
that wants a say. The server receiver is throttled and logs `itemRename`.

## Hitgroups

Eleven named profiles rather than three numbers per weapon — a sniper rifle and
a marksman rifle want the same shape, and naming it means changing that shape
once. A weapon with no override follows its `SWEP.Type`, so all 259 are covered
without a line each.

A profile is this schema's word for a **calibre**, so it also carries the
chance that a killing blow takes the limb off — see
[47-chat-tickets-and-gore.md](47-chat-tickets-and-gore.md). That is why
`revolver` exists as a profile of its own: Phoenix grade one at ×3 on a head
and a certain dismemberment, next to a pistol's ×1.5 and one-in-four, and both
were mapped onto `pistol` here. Defensible while the only difference was a
damage number; not once a hand cannon is meant to take a head off.

```bash
/weaponhitgroup ls_r700 sniper     # override
/weaponhitgroup ls_r700            # back to its type's default
/weaponhitgrouplist                # the profiles, and every override
```

The description and the damage read the **same** function, so they cannot
disagree. The head is applied as `head / 2`, because the base gamemode's own
`ScalePlayerDamage` runs after every `hook.Add` listener and doubles headshots
— `sv_armor.lua` had to work that out for power armour and this is the second
thing to need it.

---

**The description is injected, not written into 259 files.** The weapons
inherit Helix's own `base_weapons`, which lives in the framework — editing it
would mean carrying a patched Helix file for ever, and editing the generated
items would mean the generator overwriting all of it on its next run. So
`PaintOver` and `GetDescription` are *wrapped* on each weapon's item table once
on `InitializedPlugins`. Wrapping rather than replacing, because several
weapons already define their own.

`itemTable.PaintOver` is called by Helix as `(panel, itemTable, w, h)` — panel
first, table second. Getting that order wrong draws nothing and errors nowhere.

**The dev menu shows the maths and a sample side by side.** A curve that is
right and a roll that is wrong look identical from either one alone; together,
a disagreement is obvious. It runs entirely on the client, because the roll is
shared code with no server state behind it.

**The QUALITY tab reads live Luck**, not the design's numbers, so a chem or a
hat that moves Luck moves the table while the menu is open. Luck is the one
attribute whose effect is otherwise invisible — a player deciding whether a +5
Luck hat is worth wearing to a crafting session cannot answer that without
seeing the curve move.

Anything non-zero draws at least two pixels of bar. Pearlescent at 0.1% is a
third of a pixel, and a bar that rounds to nothing is indistinguishable from a
bar that is not there — which is exactly the tier somebody is squinting at the
table to find.

# Identification cards

Phoenix's `idreligioncards` plugin, item for item. A card, chip, coin, book or
token that says where somebody belongs; **worn**, its icon hangs over their
head for anybody in sight. One citizenship and one religion may be worn at a
time.

| | |
|---|---|
| `schema/items/base/sh_idcard.lua` | the base: equip / unequip, the green corner, the description |
| `schema/items/idcard/sh_*.lua` | the thirteen cards |
| `schema/libs/sh_idcard.lua` | the one-of-each rule, the worn set on the player, the icons |

## The thirteen

| item | card | kind | icon |
|---|---|---|---|
| `bos` | BoS Civilian Tag | citizenship | `phoenix/faction_icons/bos.png` |
| `cit` | C.I.T Visitor Chip | citizenship | `institute.png` |
| `enclave` | American Citizenship ID Card | citizenship | `enclave.png` |
| `house` | Casino V.I.P Chip | citizenship | `house.png` |
| `legion` | Legion Loyalist Coin | citizenship | `legion.png` |
| `mef` | MEF Citizenship Charm | citizenship | `mef.png` |
| `ncr` | NCR ID Card | citizenship | `ncr.png` |
| `shi` | Shi Social Credit Identification | citizenship | `shi.png` |
| `vaulttec` | Vault-Tec Citizenship | citizenship | `vaulttec.png` |
| `coa` | Children of Atom Token | religion | `phoenix/religions/children_of_atom.png` |
| `cultofmars` | Cult of Mars Cultist Token | religion | `cult_of_mars.png` |
| `mormon` | The Mormon Church Bible | religion | `mormon_church.png` |
| `unity` | Children of The Cathedral Token | religion | `children_of_the_cathedral.png` |

Names, descriptions, models, icons and `caps` are Phoenix's (the BoS tag's
description said "Enclave" over there; it says Brotherhood here). Every model
and every icon was checked against the mounted content packs. `ITEM.caps` is
their "gives caps to the owning faction" and is kept as data for the day
faction treasuries exist; nothing reads it yet.

## Wearing one

`Equip` on the item asks `ix.idcard.Equip`, which refuses a second card of
the same `cardType` with a reason rather than swapping it in. A worn card has
`equipped` in its data; the **worn set is rebuilt from the inventory** by
`ix.idcard.Refresh` — never edited in place — and written onto the player as
the net var `idCards`. Dropping, giving away or losing a card therefore takes
it off through the same path as unequipping it, and a character loading gets
exactly what they had.

## Over their head

`sh_idcard.lua`'s client half draws the worn icons above the head of anybody
in sight — within 1,200 units, on screen, with nothing solid between you and
them — citizenship before religion, 44px at 1080p shrinking a little with
distance. Phoenix drew theirs in their character-info overlay at 64px; the
placement is the same idea, above where the name would be.

Materials are `.png` loaded through `Material(path, "smooth")` and cached per
item; one that fails to load is skipped rather than drawn as a pink square.

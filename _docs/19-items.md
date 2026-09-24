# Items, the developer terminal, and death

`schema/items/weapons/`, `schema/entities/entities/ix_devvendor.lua`,
`schema/libs/sv_devmenu.lua`, `schema/derma/cl_devmenu.lua`,
`schema/libs/sv_death.lua`.

---

## Every weapon is an item

218 items in `schema/items/weapons/`. That folder name is not cosmetic:
`ix.item.LoadFromDir` loads `<dir>/<folder>/*.lua` with base `base_<folder>`,
so putting them in `weapons/` is what gives them `base_weapons` — and with it
equipping, the weapon slot, ammo storage and drop-on-remove.

**117 are ported from Phoenix's own items**, mined out of the scrapes. Those
carry their real inventory models and slot categories rather than a guess.
**101 are written** for weapons Phoenix never itemised.

### The size convention came from their data, not from taste

Derived by cross-referencing every ported item against its SWEP's `Type`:

| `SWEP.Type` | Size | `weaponCategory` |
|---|---|---|
| Pistol, Revolver | 2x2 | `secondary` |
| Other (equipment) | 2x1 | `equipment2` |
| everything else | 3x2 | `primary` |

Ported items are normalised to it. Phoenix's own data disagrees with itself —
the same 9mm pistol is 1x1 in one scrape generation and 2x2 in another — so
"trust the source" is not actually available; the convention is what the bulk
of their data says.

### Deduplicating ten scrape generations

The same item appears across ten scrapes under different filenames.
`sh_weapon_9mm_pistol.lua` (1x1) and `sh_weapon_9mmpistol.lua` (2x2) are the
same gun from two versions of their schema, and merging by filename gave 53
weapons two to four items each.

So: **one item per weapon class**, taken from the most complete scrape (the
149-file one), plus genuine variants kept separately. Only `_rusty` is a real
variant — everything else was duplication.

Verified after generating: every item's `class` resolves to a real SWEP, every
`model` resolves in mounted content, every item has a size, and every weapon has
exactly one item (bar the intentional Rusty 9mm).

---

## Developer terminal

`ix_devvendor` — Q-menu spawnable under **Fallout RP**, admin only.

Deliberately **not** a configured `ix_vendor`. Helix's vendor exists to make
trade a mechanic: prices, stock, buy/sell modes, money. None of that helps when
what you want is "put one of every gun in my inventory". Bolting a dev mode onto
it would mean threading *free, infinite, admin-only* through its trading, stock
and networking — and every one of those is somewhere to accidentally hand
players free items.

The menu is built from `ix.item.list`, not a stock list, so it never goes stale:
a weapon itemised tomorrow appears tomorrow with no edit. A vendor's stock is a
list somebody maintains, and a hand-maintained list of 218 weapons is wrong
within a week.

Categories down the left from each item's own `ITEM.category`, search on the
right, `GIVE` and `x5` per row. The `uniqueID` is printed under each name,
because that is what commands, loot tables and vendor stock refer to and it is
frequently not what the item is called.

### The permission check that matters is the net handler

`ENT:Use` checks admin, and that check is worth nothing on its own — a client
can send `ixFODevGive` directly, from anywhere, without ever touching the
entity. Anything relying only on `Use` would be an item spawner for every
player.

So `sv_devmenu.lua` re-checks from scratch on every request: is the sender an
admin, is the uniqueID a registered item, do they have an inventory, will it
fit. Gives are logged at `FLAG_DANGER`, because an admin handing themselves gear
belongs in the record.

---

## Death

**Helix does not drop your inventory.** Nothing in core spills items onto the
floor or into the ragdoll, and `permakill` — which bans the character outright —
defaults to off.

Its weapon base does two things on death, and only one of them is wanted here:

```lua
hook.Add("PlayerDeath", "ixStripClip", function(client)
    client.carryWeapons = {}
    ...
        k:SetData("ammo", nil)      -- the magazine
        k:SetData("equip", nil)     -- and the equipped state
```

**Keep equipped, lose the magazine.**

`equip` survives, so `ITEM:OnLoadout` re-gives the weapon on respawn — you come
back holding what you died with instead of re-equipping four things every time.

`ammo` is still cleared, so what you come back with is **empty**: `OnLoadout`
ends with `weapon:SetClip1(self:GetData("ammo", 0))`, and with the data gone
that is a clip of zero. Dying costs the loaded rounds, not the gun.

`carryWeapons` is still cleared regardless — those are references to weapon
**entities**, and `GM:PlayerLoadout` strips every weapon on respawn, so keeping
them past death means keeping references to removed entities. `OnLoadout`
repopulates it as it re-gives each weapon, which is why clearing it does not
undo the re-equip.

`sv_death.lua` re-registers the hook **under Helix's own identifier**, which
replaces it rather than adding a second listener. Adding one would not work: the
original clears `equip` first, leaving nothing to preserve.

### Only inventory items come back

A weapon spawned from the Q menu and picked up is **not** an item — it has no
inventory entry, so nothing can carry an `equip` flag for it. `GM:PlayerLoadout`
strips every weapon on respawn and the only things given back are `ix_hands`,
any `faction.weapons` / `class.weapons` (neither faction defines these), and
`OnLoadout` on each **inventory** item.

So Q-menu weapons already do not survive death, and the death hook only iterates
`inventory:Iter()` so it cannot mark one. This needed no code — but it is stated
in `sv_death.lua` because that file is where someone would look to change it,
and the guarantee lives somewhere else.

### Armour test bots

The developer terminal also spawns test **bots**: a **BOT** button on every
armour row, plus **BARE BOT** and **CLEAR BOTS** in the footer. They are real
players wearing real armour, so they answer "what does this gun get through"
using the live rules. See `20-armour.md`.

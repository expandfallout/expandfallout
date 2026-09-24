--[[
	What death costs you.

	Helix already does the important half: it does NOT drop your inventory. A
	character keeps every item through death, nothing in core spills them onto
	the floor or into the ragdoll, and `permakill` - which bans the character
	outright - defaults to off.

	What its weapon base does on death is unequip everything and empty the
	magazines:

	    hook.Add("PlayerDeath", "ixStripClip", function(client)
	        client.carryWeapons = {}
	        ...
	            k:SetData("ammo", nil)      -- the magazine
	            k:SetData("equip", nil)     -- and the equipped state

	Half of that is wanted here and half is not.

	KEEP EQUIPPED, LOSE THE MAGAZINE.

	`equip` survives, so `ITEM:OnLoadout` re-gives the weapon on respawn - you
	come back holding what you died with rather than having to open the
	inventory and re-equip four things every time.

	`ammo` is still cleared, so what you come back with is EMPTY: `OnLoadout`
	ends with `weapon:SetClip1(self:GetData("ammo", 0))`, and with the data gone
	that is a clip of zero. Dying costs you the loaded rounds, not the gun.

	This re-registers the hook under Helix's OWN identifier, which replaces it
	rather than adding a second listener. Adding one would not work: the
	original clears `equip` first, leaving nothing to preserve.
]]

--[[
	ONLY INVENTORY ITEMS COME BACK.

	Worth stating because this file is where someone would look to change it,
	and the guarantee is not enforced here - it falls out of `GM:PlayerLoadout`,
	which on every respawn does:

	    client:StripWeapons()
	    client:StripAmmo()
	    ...
	    client:Give("ix_hands")
	    faction.weapons / class.weapons, if the faction or class defines any
	    -> PostPlayerLoadout: OnLoadout on each INVENTORY item

	So a weapon spawned from the Q menu and picked up is not an item, has no
	inventory entry, and therefore has nothing to carry an `equip` flag. It is
	stripped on respawn and never given back. The loop below only ever touches
	`inventory:Iter()`, so it cannot mark one either.

	Neither of this schema's factions defines `weapons`, so at present the
	complete list of what you respawn with is `ix_hands` plus your equipped
	inventory items. If a faction is ever given a `weapons` table, that becomes
	a third source - and it will hand those out on every spawn, not just the
	first.
]]

if (not SERVER) then return end

hook.Add("PlayerDeath", "ixStripClip", function(client)
	--[[
		Still cleared. These are references to weapon ENTITIES, and
		`GM:PlayerLoadout` strips every weapon on respawn - so holding them past
		death means holding references to removed entities.

		`OnLoadout` repopulates this as it re-gives each equipped weapon, which
		is why clearing it does not undo the re-equip.
	]]
	client.carryWeapons = {}

	local character = client:GetCharacter()

	if (not character) then return end

	local inventory = character:GetInventory()

	if (not inventory) then return end

	for item in ix.inventory.Each(inventory) do
		if (item.isWeapon and item:GetData("equip")) then
			item:SetData("ammo", nil)
		end
	end
end)

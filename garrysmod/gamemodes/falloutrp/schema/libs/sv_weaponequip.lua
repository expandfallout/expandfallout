--[[
	"[Helix] Cannot give weapon - ls_ak47 does not exist!"

	It does exist. The message is wrong, and Helix says so themselves, in a
	comment three lines above the code that prints it:

	    -- @todo add docs for player:Give() failing if player already has
	    -- weapon - which means if a player is given a weapon here due to the
	    -- faction weapons table, the weapon's :Give call in the weapon base
	    -- will fail since the player will already have it by then.

	`ITEM:OnLoadout` calls `client:Give(self.class)` and prints that line
	whenever the result is not valid. `Player:Give` returns nothing when the
	player ALREADY HOLDS that weapon, so the message means "you have it twice
	over", which is the opposite of what it says.

	IT IS NOT ONLY NOISE. The success path is where `weapon.ixItem = self` is
	set, so an item that takes the failing branch is an equipped weapon the
	server cannot trace back to its item - and `ix.rarity.HeldItem`, the damage
	readout and everything else that asks "which item is this weapon" answer
	nothing for it.

	AND THE COUNT WAS THE SHAPE OF THE GUN.

	Five failures, every time, for one rifle. `GM:PostPlayerLoadout` calls
	`OnLoadout` once per `Inventory:Iter()` yield, and `Iter` walks the slot
	GRID - so a six-square weapon is yielded six times. The first `Give`
	succeeded and the other five were the same item asking again. See gotcha 14
	in `07-gotchas.md`; every loop in this file goes through
	`ix.inventory.Each` now.

	AND IT FED ITSELF. Helix's equip check asks whether
	`client.carryWeapons[category]` is taken, and that table is only written on
	the SUCCESS path of `OnLoadout` - the path the failure skips. So a weapon
	that failed to be given left its category empty, the check saw a free slot,
	and a second item of the same class could be equipped on top of it. Which
	failed to be given.

	THREE THINGS HERE, in the order they run:

	    the loadout        duplicates of a class are unmarked before Helix
	                       walks the inventory, keeping the one that has
	                       actually been fired
	    equipping          `CanPlayerEquipItem` refuses a second item of a
	                       class that is already equipped, so no new ones
	    the loadout again  an item whose weapon is already in hand binds to it
	                       rather than asking for a second, which fills
	                       `carryWeapons` either way and breaks the loop
]]

if (not SERVER) then return end

--------------------------------------------------------------------------------
-- Only one of a class can be equipped
--------------------------------------------------------------------------------

--[[
	Run from `PlayerLoadout`, which is a hook.Add listener and therefore runs
	BEFORE `GM:PlayerLoadout` - so the duplicates are gone before Helix walks
	the inventory handing weapons out.

	It returns nothing, deliberately. A `hook.Add` listener that returns a
	value stops the gamemode method from running at all, and the gamemode
	method here is the entire loadout. See gotcha 9.
]]
hook.Add("PlayerLoadout", "ixWeaponEquip", function(client)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return end

	--- `[class] = every item of it that thinks it is equipped`.
	local claims = {}

	for item in ix.inventory.Each(inventory) do
		--[[
			`class` is the field the weapon base uses for the SWEP name, so it
			is also the test for "is this a weapon". Armour and outfits carry
			an `equip` flag too and are none of this function's business.
		]]
		if (not item.class or not item:GetData("equip")) then continue end

		claims[item.class] = claims[item.class] or {}
		claims[item.class][#claims[item.class] + 1] = item
	end

	for class, items in pairs(claims) do
		if (#items < 2) then continue end

		--[[
			WHICH ONE SURVIVES IS NOT LEFT TO THE HASH ORDER.

			The first version kept whichever `Iter()` happened to yield first,
			which is a different item on every load - so the weapon somebody
			had been carrying was unequipped roughly half the time and a
			different one of the pair took its place. That reads exactly like
			"my gun keeps unequipping itself", and it was.

			The one with ammo written on it is the one that has actually been
			fired, so it is the one somebody thinks of as theirs. Failing that,
			the oldest - lowest id - which at least is the same one every time.
		]]
		table.sort(items, function(a, b)
			local ammoA = a:GetData("ammo")
			local ammoB = b:GetData("ammo")

			if ((ammoA ~= nil) ~= (ammoB ~= nil)) then return ammoA ~= nil end

			return a.id < b.id
		end)

		for index = 2, #items do
			items[index]:SetData("equip", nil)
		end

		--[[
			MsgC, NOT `ErrorNoHalt`.

			This is housekeeping, not a fault - and the first version shouted
			it through the error channel, so it turned up in the crash watch
			under "lua errors" looking like the thing that had gone wrong.
		]]
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] %s had %d '%s' marked equipped; kept item %d and "
			.. "unequipped the rest, because only one of a class can be "
			.. "held\n", character:GetName(), #items, class, items[1].id))

		if (IsValid(client)) then
			client:ChatPrint(string.format("[Gear] You had %d %s equipped at "
				.. "once, which is not possible. One has been kept.", #items,
				items[1]:GetName()))
		end

		ix.log.Add(client, "weaponUnequipDuplicate", class, #items - 1)
	end
end)

ix.log.AddType("weaponUnequipDuplicate", function(client, class, count)
	return string.format("%s had %d duplicate '%s' marked equipped; cleared.",
		client:Name(), count, class)
end, FLAG_WARNING)

--------------------------------------------------------------------------------
-- Stopping it happening again
--------------------------------------------------------------------------------

--[[
	Refuse to equip a weapon whose class is already equipped.

	THIS IS WHERE THE DUPLICATES CAME FROM. Helix's own equip check asks
	`client.carryWeapons[self.weaponCategory]`, and that table is only written
	on the SUCCESS path of `OnLoadout` - the path that the "Cannot give weapon"
	failure above skipped. So a weapon that failed to be given left its
	category empty, the check saw a free slot, and a second item of the same
	class could be equipped on top of it. Which failed to be given. Which left
	the category empty.

	The binding fix breaks that loop by filling `carryWeapons` either way. This
	closes it from the other end, on a question that cannot go stale: is there
	another item of this exact class already flagged?
]]
local function AlreadyEquipped(item, client)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false end

	for other in ix.inventory.Each(inventory) do
		if (other == item or other.class ~= item.class) then continue end
		if (other:GetData("equip")) then return true end
	end

	return false
end

--[[
	`CanPlayerEquipItem` IS HELIX'S OWN QUESTION, asked from the weapon base's
	`OnCanRun`:

	    return !IsValid(item.entity) and IsValid(client)
	        and item:GetData("equip") != true
	        and hook.Run("CanPlayerEquipItem", client, item) != false

	So there is nothing to wrap here at all - the first version patched every
	weapon item's `functions.Equip.OnCanRun` by hand before noticing the hook
	three lines below the thing it was patching.
]]
hook.Add("CanPlayerEquipItem", "ixWeaponEquip", function(client, item)
	if (not item or not item.class) then return end
	if (not AlreadyEquipped(item, client)) then return end

	client:Notify("You already have one of those equipped.")

	return false
end)

--------------------------------------------------------------------------------
-- Binding to a weapon that is already held
--------------------------------------------------------------------------------

--[[
	Wrapped ON EACH ITEM, not on the base.

	`ix.item.Register` merges a copy of the base into every item that uses it -
	`ITEM = table.Merge(table.Copy(baseTable), ITEM)` - so each weapon carries
	its own copy of `OnLoadout` and patching `ix.item.base["base_weapons"]`
	afterwards changes nothing that already exists.

	`InitializedPlugins` because that is after every item in the schema and
	every plugin has been registered, and the guard flag is what stops a
	`lua_refresh` wrapping the wrapper.
]]
local function Wrap()
	local wrapped = 0

	for _, item in pairs(ix.item.list) do
		if (not item.class or not item.OnLoadout) then continue end
		if (item.ixLoadoutWrapped) then continue end

		item.ixLoadoutWrapped = true
		wrapped = wrapped + 1

		local original = item.OnLoadout

		function item:OnLoadout()
			local client = self.player

			if (not IsValid(client) or not self:GetData("equip")) then
				return original(self)
			end

			local weapon = client:GetWeapon(self.class)

			--- Not held yet: Helix's own path, unchanged.
			if (not IsValid(weapon)) then return original(self) end

			--[[
				Held already. This is the success half of Helix's `OnLoadout`
				with the `Give` taken out - the same four lines, so an item
				that arrives this way is bound exactly as one that arrives the
				other way, rather than being an equipped weapon nothing can
				trace.
			]]
			client.carryWeapons = client.carryWeapons or {}
			client.carryWeapons[self.weaponCategory] = weapon

			weapon.ixItem = self
			weapon:SetClip1(self:GetData("ammo", 0))

			if (self.OnEquipWeapon) then
				self:OnEquipWeapon(client, weapon)
			end
		end
	end

	return wrapped
end

hook.Add("InitializedPlugins", "ixWeaponEquip", function()
	local wrapped = Wrap()

	if (wrapped > 0) then
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] %d weapon item(s) will bind to a weapon they are "
			.. "already holding rather than reporting it missing\n", wrapped))
	end
end)

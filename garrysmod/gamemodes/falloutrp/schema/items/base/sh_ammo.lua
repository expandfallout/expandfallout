--[[
	Ammunition.

	A box of rounds you load into your reserve, not into a gun. `GiveAmmo` puts
	them in the player's ammo pool for that type, and any weapon chambered for
	it draws from the same pool - which is how one box of 5.56 serves the nine
	weapons that use it.

	THE AMMO TYPE IS THE WEAPON'S, NOT OURS. `ITEM.ammo` has to match a
	`SWEP.Primary.Ammo` string exactly or the rounds go into a pool nothing can
	reach, and there is no error for that: the item is consumed, the counter
	does not move, and it looks like the item is broken. The roster in
	`_docs/tools/ammo.py` is generated FROM the weapons for that reason, and
	the generator refuses to write a type no weapon fires.

	PARTIAL BOXES. Loading is all or nothing here, the way Phoenix have it -
	the item is one box and it is spent in one go. `ITEM.rounds` is what it is
	worth.
]]

--[[
	LAYERED OVER HELIX'S OWN `base_ammo`, not replacing it - same file name,
	same uniqueID, and `ix.item.Register` reuses the table. Every field below
	overwrites theirs; the two that are NOT overwritten are deliberate:

	    OnRegistered   registers the ammo type with the ammosave plugin, so a
	                   character keeps their rounds across a session
	    useSound       theirs, unused here - `loadSound` is what plays

	Their `ammoAmount` is left alone and unread. `rounds` is this file's name
	for the same idea and the generated items set it.
]]

ITEM.name = "Ammunition"
ITEM.description = "A box of rounds."
ITEM.model = "models/items/boxsrounds.mdl"
ITEM.category = "Ammunition"

ITEM.width = 1
ITEM.height = 1

--- Marks it for the faction shop and anything else that sorts by kind.
ITEM.isAmmo = true

--- The `SWEP.Primary.Ammo` string these rounds go into.
ITEM.ammo = "pistol"

--- How many the box is worth.
ITEM.rounds = 24

--[[
	Phoenix's own pickup sound, three variants.

	Not the loot library's: that one is chosen by item category and this is a
	specific, recognisable noise people already associate with ammunition.
]]
ITEM.loadSound = "phoenix/ui/nv/itm_ammunition_up_0%d.mp3"

function ITEM:GetDescription()
	return string.format("%s\n%d rounds of %s.",
		self.description, self.rounds, self.ammo)
end

--[[
	`use`, WHICH IS HELIX'S OWN KEY, and that is the whole point.

	Helix already ships `gamemode/items/base/sh_ammo.lua` - an ammo base with
	the same file name, so the same uniqueID, `base_ammo`. `ix.item.Register`
	REUSES the table for a uniqueID it already knows, so this file does not
	replace theirs, it is layered on top of it. Defining a `Load` key here left
	their `use` in place beside it, both labelled "Load" with the same green
	plus, and the inventory menu drew the item's context menu with two
	identical entries - one of which handed out `ammoAmount` (their field,
	default 30) rather than `rounds`.

	Sharing the key overwrites the function instead of adding a second, and
	staying on their base is worth doing for its own sake: their
	`ITEM:OnRegistered` calls `ix.ammo.Register(self.ammo)`, which is what makes
	the ammosave plugin persist these 34 types across a session.
]]
ITEM.functions.use = {
	name = "Load",
	icon = "icon16/add.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		client:GiveAmmo(item.rounds, item.ammo)
		client:EmitSound(string.format(item.loadSound, math.random(3)), 110)

		--[[
			Announced so anything counting supply can hear it - the faction
			shop's restock accounting and any future ammo-crafting both want to
			know, and neither should have to patch this function to find out.
		]]
		hook.Run("PlayerLoadedAmmo", client, item, item.rounds, item.ammo)

		return true
	end,

	--[[
		Not from the world. An item lying on the ground has no owner to give
		rounds to; `item.player` is nil and `GiveAmmo` would error. Picking it
		up first is the same gesture every other usable item asks for.
	]]
	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}

--[[
	The count in the corner of the icon.

	Boxes of different calibres share models - .38 and .357 are the same box,
	so are 25mm and 40mm grenades - so without a number on it the icon is not
	enough to tell two stacks apart in an inventory.
]]
if (CLIENT) then
	function ITEM:PaintOver(item, width, height)
		draw.SimpleText(item.rounds, "DermaDefault", width - 3, height - 1,
			color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
	end
end

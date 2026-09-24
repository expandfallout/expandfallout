--[[
	Weapon blueprints.

	A blueprint is READ ONCE and then it is yours. Using one teaches the
	character that weapon and destroys the paper; from then on any blueprint
	bench will build it, given the frame and the materials.

	KNOWLEDGE IS ON THE CHARACTER, NOT IN THE INVENTORY. Keeping the paper as
	the licence would mean carrying a folder of schematics to be able to craft,
	losing them all to one death, and being unable to teach anybody anything.
	Learning it is a one-way door, which is what makes finding one matter and
	what makes a duplicate worth selling rather than worth keeping.

	`character:GetData("blueprints")` is where it lands - see
	`libs/sh_blueprint.lua` - so it survives a restart with everything else on
	the character and needs no table of its own in the database.
]]

ITEM.name = "Blueprint"
ITEM.description = "Plans for building something."
ITEM.model = "models/mosi/fallout4/props/junk/blueprint.mdl"
ITEM.category = "Blueprints"

ITEM.width = 2
ITEM.height = 1

--- Which weapon it teaches. Set by every generated blueprint.
ITEM.weapon = nil

--[[
	ONE OF A KIND. A blueprint is a specific document rather than a quantity of
	paper, and stacking them would let five of the same plan share a slot -
	which reads as five copies of something you can only ever use once. See
	`sh_material.lua` for the general form of that argument.
]]
ITEM.isStackable = false

--- The corner marker; blueprints share a handful of models between them.
ITEM.tint = nil

function ITEM:GetDescription()
	local weapon = self.weapon and ix.item.list[self.weapon]
	local text = self.description

	if (weapon) then
		text = string.format("%s\nTeaches: %s.", text, weapon.name)
	end

	--[[
		Said on the item rather than only on the failed use, because the whole
		question somebody has when they find a second one is whether it is
		worth carrying.
	]]
	if (CLIENT and self.weapon and ix.blueprint
	and ix.blueprint.Knows(LocalPlayer(), self.weapon)) then
		text = text .. "\nYou already know this."
	end

	return text
end

ITEM.functions.Learn = {
	name = "Learn",
	icon = "icon16/book_open.png",

	OnCanRun = function(item)
		if (IsValid(item.entity)) then return false end
		if (not item.weapon) then return false end

		--[[
			Hidden once known rather than shown and refused. A greyed option
			you can never use is a question the item should have answered.
		]]
		return not ix.blueprint.Knows(item.player or LocalPlayer(),
			item.weapon)
	end,

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		local learned, reason = ix.blueprint.Learn(client, item.weapon)

		if (not learned) then
			client:Notify(reason)

			--[[
				FALSE KEEPS THE ITEM. Helix destroys the item a function ran on
				unless the result is false, and a blueprint that failed to
				teach anything must not be consumed for it.
			]]
			return false
		end

		local weapon = ix.item.list[item.weapon]

		client:Notify(string.format("Learned: %s.",
			weapon and weapon.name or item.weapon))

		client:EmitSound("items/ammo_pickup.wav", 60, 130, 0.4)

		return true
	end
}

if (CLIENT) then
	function ITEM:PaintOver(item, width, height)
		--[[
			A COLOURED BORDER, not a corner square.

			Hundreds of frames share a handful of models, so the colour is the
			only thing telling two of them apart - and an edge reads across a
			full inventory where an 11-pixel corner swatch does not. It reuses
			`ix.rarity.PaintBorder`, which is the same border a crafted weapon
			draws for its quality, so the two mean the same thing visually.
		]]
		ix.rarity.PaintBorder(item.tint, width, height, 2)

		--[[
			A tick on one you already know, so a bag of loot can be sorted
			without opening every one of them.
		]]
		if (item.weapon and ix.blueprint
		and ix.blueprint.Knows(LocalPlayer(), item.weapon)) then
			draw.SimpleText("*", "DermaDefaultBold", 4, 2,
				Color(140, 210, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1,
				color_black)
		end
	end
end

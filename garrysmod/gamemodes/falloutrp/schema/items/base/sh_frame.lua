--[[
	Weapon frames.

	The receiver, the chassis, the bit with the serial number on it - whatever
	a given weapon's irreplaceable part is. One frame exists per weapon, and a
	blueprint for that weapon always costs its own frame.

	THAT IS THE WHOLE POINT OF THEM. Without frames, crafting a weapon costs
	generic materials and every weapon is worth the same pile of steel; with
	them, making an anti-materiel rifle needs an anti-materiel rifle's frame,
	and where that came from is a question with an answer - loot, a shop, a
	faction, or the wreck of somebody else's. It is the difference between
	crafting as a shop with extra steps and crafting as a reason to go
	somewhere.

	They stack, because a frame is a part rather than a specific object - two
	identical receivers in a bag is the truth. See `sh_material.lua` for the
	other half of that argument.
]]

ITEM.name = "Frame"
ITEM.description = "A weapon frame."
ITEM.model = "models/mosi/fallout4/props/junk/components/gears.mdl"
ITEM.category = "Frames"

ITEM.width = 2
ITEM.height = 1

--- Marks it for the shop, the loot tables and anything sorting by kind.
ITEM.isMaterial = true
ITEM.isFrame = true

ITEM.isStackable = true
ITEM.maxQuantity = 5

--- Which weapon this is the frame for. Set by every generated frame.
ITEM.weapon = nil

--[[
	The corner marker, and the count.

	Frames all share one model - there is no per-weapon receiver prop in any of
	these packs - so without something distinguishing them an inventory of
	frames is an inventory of identical grey lumps. The tint is the same answer
	as the chems and the materials.
]]
ITEM.tint = nil

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

		local quantity = ix.stack.Get(item)

		if (quantity > 1) then
			draw.SimpleText(quantity, "DermaDefaultBold", 4, 2, color_white,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
		end
	end
end

--[[
	Materials, components and the rest of what you carry to build with.

	Phoenix keep all of this in one `junk` folder - crafting components, quest
	items, snow globes and schematics together - and one base with the stacking
	on it. This is the same base written against Helix, which has no quantity
	of its own; `libs/sh_stack.lua` is where that lives and why.

	    isStackable   whether two of them merge at all
	    maxQuantity   how many fit in one, five unless it says otherwise

	NOT EVERYTHING STACKS. A bar of steel is a quantity of a substance and five
	of them in one slot is the truth; an Enclave access pad is one specific
	object, and two of them sharing a slot would be a lie about what is in the
	room. The roster says which is which, item by item.
]]

ITEM.name = "Material"
ITEM.description = "Something useful, eventually."
ITEM.model = "models/mosi/fallout4/props/junk/components/steel.mdl"
ITEM.category = "Materials"

ITEM.width = 1
ITEM.height = 1

--- Marks it for the shop, the loot tables and anything else sorting by kind.
ITEM.isMaterial = true

ITEM.isStackable = true
ITEM.maxQuantity = 5

--[[
	A colour for the corner marker, where one is set.

	Thirty-one component models cover eighty-odd materials, so several share a
	model - the ores all look alike, and a bronze bar uses the copper model.
	The same answer as the chems: a small square of the item's own colour, so
	two things that look identical in an inventory are still told apart at a
	glance. See `sh_aid.lua`.
]]
ITEM.tint = nil

function ITEM:GetDescription()
	local quantity = ix.stack.Get(self)

	if (quantity > 1) then
		return string.format("%s\n%d of them.", self.description, quantity)
	end

	if (not self.isStackable) then
		return self.description .. "\nOne of a kind - these do not stack."
	end

	return self.description
end

--[[
	Dragging one onto another merges them.

	`combine` is Helix's own mechanism and it is called on the item being
	dragged ONTO, with the id of the one being dragged - so `item` here is the
	destination and `data[1]` is the source. Nothing else in this schema uses
	it, which is why it is safe to define it for the whole base.
]]
ITEM.functions.combine = {
	OnCanRun = function(item, data)
		if (IsValid(item.entity)) then return false end

		local source = ix.item.instances[data[1]]

		return ix.stack.CanMerge(item, source) > 0
	end,

	OnRun = function(item, data)
		local source = ix.item.instances[data[1]]
		local moved = ix.stack.Merge(item, source)

		if (moved > 0 and IsValid(item.player)) then
			item.player:EmitSound("physics/metal/metal_solid_impact_bullet"
				.. math.random(1, 4) .. ".wav", 60, 120, 0.4)
		end

		--[[
			ALWAYS FALSE. Returning true tells Helix to destroy the item this
			ran on, and the item this ran on is the one that just GAINED the
			stack. `ix.stack.Merge` has already removed the source if it was
			emptied.
		]]
		return false
	end
}

ITEM.functions.Split = {
	name = "Split",
	icon = "icon16/arrow_divide.png",

	OnCanRun = function(item)
		return not IsValid(item.entity) and item.isStackable
			and ix.stack.Get(item) > 1
	end,

	OnRun = function(item)
		return false
	end,

	--[[
		The number is asked for on the CLIENT and sent as a command, because
		`OnRun` has no way to prompt - it runs on the server with no way back
		to the person who clicked. Helix's own multi-option functions have the
		same shape.
	]]
	OnClick = function(item)
		local half = math.max(math.floor(ix.stack.Get(item) / 2), 1)

		Derma_StringRequest("Split", string.format(
			"How many to take out of the %d?", ix.stack.Get(item)),
			tostring(half), function(text)
				local quantity = math.floor(tonumber(text) or 0)

				if (quantity < 1) then return end

				net.Start("ixStackSplit")
					net.WriteUInt(item:GetID(), 32)
					net.WriteUInt(math.min(quantity, 999), 10)
				net.SendToServer()
			end)

		return false
	end
}

--[[
	The count in the corner, and the colour marker if the item has one.

	Drawn only when there is more than one: a lone item with a "1" on it is
	noise, and the great majority of what is carried is lone.
]]
if (CLIENT) then
	function ITEM:PaintOver(item, width, height)
		if (item.tint) then
			surface.SetDrawColor(item.tint)
			surface.DrawRect(width - 15, 4, 11, 11)

			surface.SetDrawColor(0, 0, 0, 220)
			surface.DrawOutlinedRect(width - 15, 4, 11, 11, 1)
		end

		--[[
			TOP LEFT, opposite the tint square. The two are the only things
			drawn over an icon and putting them in the same corner would mean
			reading a number through a colour swatch; bottom right is where
			Helix draws its own equipped and broken markers.
		]]
		local quantity = ix.stack.Get(item)

		if (quantity > 1) then
			draw.SimpleText(quantity, "DermaDefaultBold", 4, 2, color_white,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
		end
	end
end

if (SERVER) then
	util.AddNetworkString("ixStackSplit")

	net.Receive("ixStackSplit", function(length, client)
		local itemID = net.ReadUInt(32)
		local quantity = net.ReadUInt(10)

		--[[
			Rate limited, because a split writes a row and networks a slot.
		]]
		if ((client.ixNextSplit or 0) > RealTime()) then return end

		client.ixNextSplit = RealTime() + 0.3

		local item = ix.item.instances[itemID]
		local character = client:GetCharacter()

		if (not item or not character) then return end
		if (IsValid(item.entity)) then return end

		--[[
			THEIRS, AND THEIRS ONLY. `item.invID` naming the character's own
			inventory is what makes this not a way to reach into a container
			somebody else is standing at.
		]]
		if (item.invID ~= character:GetInventory():GetID()) then return end
		if (not item.isStackable) then return end

		ix.stack.Split(item, quantity, function(ok, reason)
			if (not ok and IsValid(client)) then
				client:Notify(reason == "noFit"
					and "No room to split that." or "You cannot split that.")
			end
		end)
	end)
end

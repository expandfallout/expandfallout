--[[
	Human Flesh.

	Cut off a body along with its head - `ix.corpse.TakeHead` is the only thing
	that makes one. It used to fall out of a severed arm, which made meat a
	by-product of shooting somebody in the elbow rather than something anybody
	chose to do.

	IN `items/food/` BECAUSE IT IS FOOD. That gives it `base_food` and with it
	the eating behaviour, the sustenance handling and the radiation - so
	cannibalism is not a system, it is a meal with an unusual name on it.

	The rads are the point. Ten sustenance for ten rads is a bad trade for
	anybody with a can of Cram, and a good one for somebody who has been in the
	wasteland for two days - which is exactly when a corpse starts looking like
	an option.
]]

ITEM.name = "Human Flesh"
ITEM.description = "A piece of flesh, cut from somebody."
ITEM.model = "models/vj_base/gibs/human/gib6.mdl"
ITEM.category = "Food"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.radiation = 10

ITEM.eatMeText = "eats a piece of human flesh."

--[[
	Worth nothing at a vendor, for the reason the head gives: a price would
	make this a farm, and somebody would work out that shooting people in the
	leg pays.
]]
ITEM.price = 0

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2)
		.. ".mp3"
end

--[[
	ANY CHARACTER MAY HANDLE ONE - the same exemption the head carries.

	Helix stamps the first character to touch an item as its owner and refuses
	to let another character on the same ACCOUNT pick it up (`itemOwned`, in
	`ITEM:Transfer` and again in `Inventory:Add`). That rule stops somebody
	moving their own gear between their own characters; a piece of somebody
	else is meant to change hands.
]]
ITEM.bAllowMultiCharacterInteraction = true

--[[
	NAMED THE WAY THE HEAD IS, and for the same reason.

	Read off the INSTANCE: `GetData` is shared and works wherever the item is
	known, so the inventory, the tooltip and the thing lying on the ground all
	say the same name without being told separately.

	    label   "NCR - Trooper Flesh"   cut off an anonymous body
	    owner   "Vault Dweller's Flesh"     cut off a permanently killed one

	A possessive only reads right on a person: "NCR - Trooper's Flesh" sounds
	like somebody called Trooper.
]]
function ITEM:GetName()
	local label = self:GetData("label", "")

	if (label ~= "") then return label .. " Flesh" end

	local owner = self:GetData("owner", "")

	if (owner == "") then return self.name end

	return owner .. "'s Flesh"
end

function ITEM:GetDescription()
	local base = ix.item.base.base_food

	if (not base or not base.GetDescription) then return self.description end

	local label = self:GetData("label", "")
	local owner = label ~= "" and ("a " .. label)
		or self:GetData("owner", "")

	if (owner == "") then return base.GetDescription(self) end

	--[[
		THE BASE BUILDS THE STAT LINES, so this asks it rather than writing
		"+10 Sustenance" a second time - an item that promised its own numbers
		would go on promising them after somebody edited the real ones.

		It is asked through a STAND-IN rather than by swapping `description` on
		the item and putting it back: every instance of an item shares one
		table, so writing to it - even for one call - is writing to everybody's
		flesh at once. The stand-in has its own `description` and falls through
		to this item for the four numbers the base reads, and nothing is
		changed by looking at a piece of meat.
	]]
	local stand = setmetatable({
		description = string.format("A piece of flesh cut from %s.", owner)
	}, {__index = self})

	return base.GetDescription(stand)
end

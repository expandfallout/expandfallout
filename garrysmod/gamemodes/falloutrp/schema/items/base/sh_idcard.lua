--[[
	Identification: citizenship cards and religious tokens.

	Phoenix's `idreligioncards` plugin, item for item: a card, chip, coin or
	book that says where somebody belongs, and when it is EQUIPPED its icon
	hangs over their head for everybody to see. One citizenship and one
	religion may be worn at a time.

	`ix.idcard` (libs/sh_idcard.lua) keeps the worn set on the player as the
	net var `idCards`, rebuilt from the inventory whenever it changes and
	when a character loads - so a card stays worn across sessions, and a
	card that leaves the inventory by any door stops being worn.

	`caps` is Phoenix's "gives caps to the owning faction" and is kept as
	data for the day faction treasuries exist; nothing reads it yet.
]]

ITEM.name = "ID Card"
ITEM.description = "Something that says where you belong. Worn, it shows "
	.. "over your head."
ITEM.model = "models/mosi/fallout4/props/junk/keycard.mdl"
ITEM.category = "Identification"
ITEM.width = 1
ITEM.height = 1

ITEM.isIDCard = true
ITEM.cardType = "id"
ITEM.faction = nil
ITEM.idIcon = "phoenix/faction_icons/default1.png"
ITEM.caps = 0

--- What a card says about itself.
function ITEM:GetDescription()
	local text = self.description

	if (self.cardType == "religion") then
		return text .. "\n\nA religious token. One may be worn at a time."
	end

	local faction = self.faction and ix.faction.indices[self.faction]

	return text .. "\n\n" .. (faction and faction.name or "Unknown")
		.. " citizenship. One may be worn at a time."
end

if (CLIENT) then
	--- A green corner on a worn one, the way a worn armour piece is marked.
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equipped", false)) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end

--- Leaving the inventory by any door takes it off.
ITEM:Hook("drop", function(item)
	if (item:GetData("equipped", false)) then
		item:SetData("equipped", false)

		if (ix.idcard) then ix.idcard.Refresh(item.player) end
	end
end)

function ITEM:OnRemoved()
	if (SERVER and ix.idcard and IsValid(self.player)) then
		ix.idcard.Refresh(self.player)
	end
end

ITEM.functions.Unequip = {
	name = "Unequip",
	icon = "icon16/cross.png",

	OnRun = function(item)
		item:SetData("equipped", false)

		if (ix.idcard) then ix.idcard.Refresh(item.player) end

		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and item:GetData("equipped", false) == true
	end
}

ITEM.functions.Equip = {
	name = "Equip",
	icon = "icon16/tick.png",

	OnRun = function(item)
		local ok, why = ix.idcard.Equip(item.player, item)

		if (not ok and why) then item.player:Notify(why) end

		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and not item:GetData("equipped", false)
	end
}

--[[
	The slave collar.

	REWRITTEN, not converted. The version that was here came through the bulk
	armour conversion and was Phoenix's file with the method names swapped, so
	it still called `char:getPlayer()`, `item:getOwner()`, `self:remove()` and
	`nut.config.get` - none of which exist here - and read
	`ix.item.inventories[self.invID]`, which is the bare world table. It would
	have thrown the moment anybody put one on. See `sh_slavery.lua` for what the
	behaviour is now and why.

	WHAT THIS FILE IS: the collar as an OBJECT - the model, the neck slot, and
	the two things you can do to one that is sitting in your inventory. Arming
	it is the whole interface: an armed collar locks itself around the neck of
	the next person it is handed to.
]]

ITEM.name = "Slave Collar"
ITEM.description = "An explosive device worn around the neck, with a GPS "
	.. "tracker. This item has rules of use."
ITEM.model = "models/catmop/fallout/props/slavecollar_go.mdl"
ITEM.category = "Armor"

ITEM.width = 1
ITEM.height = 1

ITEM.bodyType = "neck"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/slave_collar.mdl"
ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/slave_collar.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0

ITEM.specialBonus = {}

ITEM.takesType = {}
ITEM.takesBody = {}

ITEM.isPA = false
ITEM.noCore = false

ITEM.functions.Arm = {
	name = "Arm",
	icon = "icon16/tick.png",

	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()

		item:SetData("arm", true)

		--[[
			WHO ARMED IT IS WHO OWNS THE PERSON. Written at arming rather than
			at fitting, because by the time it goes on somebody the collar is
			already in their inventory and the previous holder is gone from the
			question.
		]]
		item:SetData("owner", character:GetID())

		client:EmitSound("weapons/mine/wpn_mine_arm.wav")
		client:Notify("The collar is armed. Give it to somebody.")

		return false
	end,

	OnCanRun = function(item)
		if (IsValid(item.entity)) then return false end
		if (item:GetData("equip")) then return false end

		return not item:GetData("arm", false)
	end
}

ITEM.functions.Disarm = {
	name = "Disarm",
	icon = "icon16/cross.png",

	OnRun = function(item)
		item:SetData("arm", false)
		item:SetData("owner", nil)

		item.player:EmitSound("weapons/mine/wpn_mine_disarm.wav")

		return false
	end,

	--[[
		ONLY THE PERSON WHO ARMED IT MAY DISARM IT. Otherwise stealing a collar
		out of somebody's bag and disarming it is a better plan than any of the
		ones the system is about.
	]]
	OnCanRun = function(item)
		local client = item.player
		local character = IsValid(client) and client:GetCharacter()

		if (IsValid(item.entity)) then return false end
		if (item:GetData("equip")) then return false end
		if (not item:GetData("arm", false)) then return false end
		if (not character) then return false end

		return item:GetData("owner") == character:GetID()
	end
}

--[[
	NEITHER OF THESE IS AVAILABLE, and both have to exist to say so.

	The armour base gives every armour an Equip and an Unequip, and a collar
	that could be taken off by its wearer is jewellery. Overriding them is
	Phoenix's approach too.
]]
ITEM.functions.Equip = {
	name = "Equip",
	icon = "icon16/tick.png",
	OnRun = function() return false end,
	OnCanRun = function() return false end
}

ITEM.functions.UnEquip = {
	name = "Unequip",
	icon = "icon16/cross.png",
	OnRun = function() return false end,
	OnCanRun = function() return false end
}

--- A collar on a neck stays on that neck.
function ITEM:CanTransfer(oldInventory, newInventory)
	return not self:GetData("equip", false)
end

--[[
	The one thing the item still has to do on its own: put the state back
	together when the character it is worn by loads.

	`sv_slavery.lua` does this too, from the other side, and deliberately: this
	runs for the collar, that runs for the player, and the two of them agree
	because both read `expireAt` off this item.
]]
function ITEM:OnLoadout()
	if (not SERVER) then return end

	local client = self:GetOwner()

	if (not IsValid(client)) then return end
	if (not self:GetData("equip", false)) then return end
	if (not self:GetData("expireAt")) then return end

	client:SetNetVar("enslaved", true)
	client:SetNetVar("collarUntil", self:GetData("expireAt"))
	client:SetNetVar("collarOwner", self:GetData("owner") or 0)
end

function ITEM:GetDescription()
	local description = self.description

	if (self:GetData("equip")) then
		return description .. "\n\n - Locked on"
	end

	return description .. (self:GetData("arm", false) and "\n\n - Armed"
		or "\n\n - Disarmed")
end

if (CLIENT) then
	local LOCK = Material("icon16/lock.png", "noclamp smooth")

	--[[
		The armed light and the time left, drawn on the icon - Phoenix's, and
		the reason the deadline is worth keeping on the item as well as on the
		wearer.
	]]
	function ITEM:PaintOver(item, width, height)
		if (item:GetData("arm")) then
			surface.SetDrawColor(255, 0, 0, 100)
			surface.DrawRect(width - 14, height - 14, 8, 8)
		end

		if (not item:GetData("equip")) then return end

		surface.SetDrawColor(color_white)
		surface.SetMaterial(LOCK)
		surface.DrawTexturedRect(4, 4, 8, 8)

		local expireAt = item:GetData("expireAt")

		if (not expireAt) then return end

		surface.SetFont("ixSmallFont")
		surface.SetTextColor(color_white)
		surface.SetTextPos(4, height - 18)
		surface.DrawText(ix.slavery.FormatTime(expireAt - os.time()))
	end
end

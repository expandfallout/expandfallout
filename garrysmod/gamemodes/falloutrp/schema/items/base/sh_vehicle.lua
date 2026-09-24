--[[
	Vehicle base item: something folded up that becomes a vehicle where you
	are looking. Everything in `items/vehicle/` inherits this - the folder
	name picks the base.

	`vehicleClass` names one of the LVS vehicles (`lvs_fo_*`, in the
	`falloutrp_vehicles` addon). The item is CONSUMED when it is put down:
	the vehicle is the item now, owned by the character who deployed it,
	and `/vehiclepack` folds it back into the item while it is empty. One
	left standing empty long enough packs itself back to its owner, and
	one still standing when the server goes down is owed to them and
	handed back when they next load in. `deployClass` names anything else
	- LVS's own jerrycans, crates and mines - which is put down and
	forgotten. See `libs/sh_vehicles.lua`.
]]

ITEM.name = "Vehicle"
ITEM.description = "A vehicle, folded up."
ITEM.model = "models/props_junk/garbage_metalcan001a.mdl"
ITEM.category = "Vehicles"
ITEM.width = 2
ITEM.height = 2

--- The marker other systems key off, rather than a base name.
ITEM.isVehicle = true

--- An LVS vehicle to deploy and track, or a plain entity to put down.
ITEM.vehicleClass = nil
ITEM.deployClass = nil

ITEM.functions.Deploy = {
	name = "Deploy",
	icon = "icon16/car.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		ix.vehicles.Deploy(client, item)

		--- False keeps the item: it goes when the ghost is placed, not now.
		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}

function ITEM:GetDescription()
	local base = self.description or ""

	if (self.vehicleClass) then
		return base .. "\n\nDeploy it where you are looking. /vehiclepack "
			.. "folds it up again while it is empty."
	end

	return base
end

function ITEM:OnRegistered()
	if (self.vehicleClass and ix.vehicles and ix.vehicles.Register) then
		ix.vehicles.Register(self.uniqueID, self.vehicleClass)
	end
end

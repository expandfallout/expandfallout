--[[
	Vehicles: the shape of owning one.

	Phoenix drove LVS vehicles (`lvs_framework`, workshop 2912816023) and so
	does this; the vehicles themselves are the `falloutrp_vehicles` addon,
	sixteen definitions on LVS's bases. This is the schema's half:

	    an ITEM is a vehicle folded up (`items/vehicle/`, base `base_vehicle`)
	    Deploy puts it down where you look and consumes the item
	    the vehicle belongs to the character who deployed it
	    only the owner drives it (staff too), passengers ride
	    /vehiclepack folds it back into the item while it is empty
	    one left unused for `vehicleDespawnEmpty` seconds is REMOVED
	    one destroyed is gone, and so is one still out at shutdown

	THAT IS THE OPTIMISATION. Vehicles are the heaviest thing a server
	runs, and every rule above is a rule about how many exist: a cap per
	character, a cap for the server, and nothing left standing with
	nobody in it. LVS's own lock (key 1 while driving) still works on top.
]]

ix.vehicles = ix.vehicles or {}
ix.vehicles.classes = ix.vehicles.classes or {}
ix.vehicles.items = ix.vehicles.items or {}

ix.config.Add("vehiclesEnabled", true, "Whether vehicles can be deployed.",
	nil, {category = "Vehicles"})

ix.config.Add("vehicleMaxPerPlayer", 1,
	"How many vehicles one character may have deployed at once.", nil, {
	data = {min = 1, max = 10}, category = "Vehicles"})

ix.config.Add("vehicleMaxTotal", 24,
	"How many deployed vehicles the whole server allows.", nil, {
	data = {min = 1, max = 100}, category = "Vehicles"})

ix.config.Add("vehicleDespawnEmpty", 3600,
	"Seconds a vehicle may stand with nobody in it before it is removed. "
	.. "0 never.", nil, {
	data = {min = 0, max = 86400}, category = "Vehicles"})

ix.config.Add("vehicleOwnerOnly", true,
	"Whether only the owner (and staff) may drive a deployed vehicle. "
	.. "Passengers may always ride.", nil, {category = "Vehicles"})

ix.config.Add("vehicleDeployRange", 260,
	"How far in front of you a vehicle is deployed, in units.", nil, {
	data = {min = 100, max = 600}, category = "Vehicles"})

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("vehicle.manage",
		"Drive, pack up and remove anybody's vehicle", "Staff")
end

--- An item deploys a class; both directions are kept.
function ix.vehicles.Register(uniqueID, class)
	ix.vehicles.classes[class] = uniqueID
	ix.vehicles.items[uniqueID] = class
end

--- Any LVS vehicle at all, ours or spawned from the menu.
function ix.vehicles.IsVehicle(entity)
	return IsValid(entity) and entity.LVS == true
end

--- The character id that deployed it, or nil for one nobody owns.
function ix.vehicles.Owner(vehicle)
	if (not IsValid(vehicle) or not vehicle.GetNetVar) then return nil end

	return vehicle:GetNetVar("ixVehicleOwner")
end

function ix.vehicles.OwnerName(vehicle)
	return IsValid(vehicle) and vehicle:GetNetVar("ixVehicleOwnerName", "") or ""
end

--- The item it folds back into.
function ix.vehicles.Item(vehicle)
	return IsValid(vehicle) and vehicle:GetNetVar("ixVehicleItem") or nil
end

function ix.vehicles.Name(vehicle)
	local uniqueID = ix.vehicles.Item(vehicle)
	local item = uniqueID and ix.item.list[uniqueID]

	if (item) then return item.name end

	return IsValid(vehicle) and vehicle.PrintName or "vehicle"
end

function ix.vehicles.Owns(client, vehicle)
	local character = IsValid(client) and client:GetCharacter()
	local owner = ix.vehicles.Owner(vehicle)

	return character ~= nil and owner ~= nil and character:GetID() == owner
end

--- Owner, or staff with the permission.
function ix.vehicles.CanManage(client, vehicle)
	if (ix.vehicles.Owns(client, vehicle)) then return true end

	return ix.admin and ix.admin.Can(client, "vehicle.manage") or false
end

--[[
	WHO DRIVES. LVS asks `LVS.CanPlayerDrive` when somebody takes the
	driver's seat with the seat switcher; a vehicle nobody deployed - one
	from the spawn menu - has no owner and anybody may.
]]
function ix.vehicles.CanDrive(client, vehicle)
	if (not ix.config.Get("vehicleOwnerOnly", true)) then return true end
	if (ix.vehicles.Owner(vehicle) == nil) then return true end

	return ix.vehicles.CanManage(client, vehicle)
end

if (SERVER) then
	hook.Add("LVS.CanPlayerDrive", "ixVehicles", function(client, vehicle)
		if (not ix.vehicles.CanDrive(client, vehicle)) then return false end
	end)

	hook.Add("LVS.OnPlayerCannotDrive", "ixVehicles", function(client, vehicle)
		if (IsValid(client) and ix.vehicles.Owner(vehicle) ~= nil) then
			client:Notify(string.format("This is %s's vehicle.",
				ix.vehicles.OwnerName(vehicle)))
		end
	end)
end

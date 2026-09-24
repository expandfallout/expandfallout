--[[
	Vehicles - the half that puts them down and takes them away.

	See `sh_vehicles.lua` for the rules. What is kept:

	    ix.vehicles.list[vehicle] = {owner = charID, uniqueID, since, used}

	A vehicle is tracked when its item is deployed, and when staff spawn one
	of ours from the spawn menu - the spawner owns that one, and can pack it
	up like any other. Nothing is refunded: a vehicle left with nobody in it
	for `vehicleDespawnEmpty` seconds is removed, a destroyed one is gone,
	and a restart clears the map like it clears everything else.
]]

if (not SERVER) then return end

ix.vehicles = ix.vehicles or {}
ix.vehicles.list = ix.vehicles.list or {}

util.AddNetworkString("ixVehicleBeginPlacing")
util.AddNetworkString("ixVehiclePlace")

--------------------------------------------------------------------------------
-- Seats set in game
--------------------------------------------------------------------------------

--[[
	WHERE THE SEATS ARE, PER CLASS, PLACED BY STANDING IN THEM. The helper
	guesses seats from a model's box, and a guess is wrong on half of them.
	`/vehicleseat driver` while standing where the driver should sit and
	looking at the vehicle stores your position and facing in the vehicle's
	frame; `/vehicleseat add` appends a passenger; `clear` forgets the
	class; `show` prints it. The vehicle is respawned on the spot so the
	result is seen at once. Kept in `ix.data` ("vehicleseats"), read by the
	addon's `FOVehicles.SeatOverride` when a vehicle is built.
]]
ix.vehicles.seats = ix.vehicles.seats or {}

local SEATS = "vehicleseats"
local seatsLoaded = false

local function LoadSeats()
	if (seatsLoaded) then return end

	ix.vehicles.seats = ix.data.Get(SEATS, nil, false, true) or {}
	seatsLoaded = true
end

hook.Add("LoadData", "ixVehicleSeats", LoadSeats)
hook.Add("PostLoadData", "ixVehicleSeats", LoadSeats)
timer.Simple(10, LoadSeats)

local function SaveSeats()
	if (not seatsLoaded) then return end

	ix.data.Set(SEATS, ix.vehicles.seats, false, true)
end

function FOVehicles.SeatOverride(class)
	LoadSeats()

	return ix.vehicles.seats[class]
end

--- Where the asker stands, in the vehicle's frame, and where they look.
local function Sitting(client, vehicle)
	return {
		pos = vehicle:WorldToLocal(client:GetPos() + Vector(0, 0, 8)),
		yaw = math.Round(vehicle:WorldToLocalAngles(Angle(0, client:EyeAngles().y, 0)).y)
	}
end

--- The same vehicle again, on the spot, with the seats as they are now.
local function Respawn(vehicle)
	local class, pos, ang = vehicle:GetClass(), vehicle:GetPos(), vehicle:GetAngles()
	local data = ix.vehicles.list[vehicle]
	local creator = vehicle:GetCreator()

	vehicle:Remove()

	local fresh = ents.Create(class)

	if (not IsValid(fresh)) then return end

	fresh:SetPos(pos + Vector(0, 0, 8))
	fresh:SetAngles(ang)

	if (IsValid(creator)) then
		if (fresh.StoreCPPI) then fresh:StoreCPPI(creator) end

		fresh:SetCreator(creator)
	end

	fresh:Spawn()
	fresh:Activate()

	if (data and IsValid(creator)) then
		ix.vehicles.Track(fresh, creator, data.uniqueID)
	end

	return fresh
end

--------------------------------------------------------------------------------
-- Who and how many
--------------------------------------------------------------------------------

function ix.vehicles.Count(charID)
	local count = 0

	for vehicle, data in pairs(ix.vehicles.list) do
		if (IsValid(vehicle) and data.owner == charID) then count = count + 1 end
	end

	return count
end

function ix.vehicles.Total()
	local count = 0

	for vehicle in pairs(ix.vehicles.list) do
		if (IsValid(vehicle)) then count = count + 1 end
	end

	return count
end

--- Anybody in any seat.
local function Occupied(vehicle)
	if (vehicle.GetDriver and IsValid(vehicle:GetDriver())) then return true end

	local seats = vehicle.GetPassengerSeats and vehicle:GetPassengerSeats() or {}

	for _, pod in pairs(seats) do
		if (IsValid(pod) and pod.GetDriver and IsValid(pod:GetDriver())) then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Tracking
--------------------------------------------------------------------------------

--- This vehicle is somebody's, from now.
function ix.vehicles.Track(vehicle, client, uniqueID)
	local character = IsValid(client) and client:GetCharacter()

	if (not character or not IsValid(vehicle)) then return end

	vehicle:SetNetVar("ixVehicleOwner", character:GetID())
	vehicle:SetNetVar("ixVehicleOwnerName", character:GetName())
	vehicle:SetNetVar("ixVehicleItem", uniqueID)

	ix.vehicles.list[vehicle] = {
		owner = character:GetID(),
		uniqueID = uniqueID,
		since = CurTime(),
		used = CurTime()
	}

	vehicle:CallOnRemove("ixVehicles", function(entity)
		ix.vehicles.list[entity] = nil
	end)
end

--[[
	SPAWNED FROM THE MENU, STILL OWNED. Staff spawning one of ours from the
	sandbox menu get the same vehicle a deployed item makes - theirs, and
	packable - so a spawn-menu Buggy is not "not a deployed vehicle".
]]
hook.Add("PlayerSpawnedSENT", "ixVehicles", function(client, entity)
	if (not IsValid(entity)) then return end

	local uniqueID = ix.vehicles.classes[entity:GetClass()]

	if (not uniqueID) then return end

	ix.vehicles.Track(entity, client, uniqueID)
end)

--------------------------------------------------------------------------------
-- Putting one down
--------------------------------------------------------------------------------

--[[
	THE GHOST. Deploying a vehicle is the same three steps as putting down a
	crop plot or a workbench: the server hands the client the model, the
	client shows a ghost of it that follows the aim and turns with J and K
	(`cl_deploy.lua`), and a left click sends the spot and the angle back.
	What you see is what you get, because the ghost IS the vehicle's model.
]]
local function Allowed(client, item)
	local character = client:GetCharacter()

	if (not character) then return false end

	if (not ix.config.Get("vehiclesEnabled", true)) then
		return false, "Vehicles are off."
	end

	if (item.vehicleClass) then
		local charID = character:GetID()

		if (ix.vehicles.Count(charID) >= ix.config.Get("vehicleMaxPerPlayer", 1)) then
			return false, "You already have a vehicle out. Pack it up first."
		end

		if (ix.vehicles.Total() >= ix.config.Get("vehicleMaxTotal", 24)) then
			return false, "There are too many vehicles out already."
		end
	end

	return true
end

--- Deploy: begins the ghost. False always - the item goes when it is placed.
function ix.vehicles.Deploy(client, item)
	local ok, why = Allowed(client, item)

	if (not ok) then
		if (why) then client:Notify(why) end

		return false
	end

	local class = item.vehicleClass or item.deployClass

	if (not class) then return false end

	local definition = scripted_ents.Get(class)

	if (not definition) then
		client:Notify("That vehicle is not installed on this server.")

		return false
	end

	net.Start("ixVehicleBeginPlacing")
		net.WriteString(item.vehicleClass and (definition.MDL or item.model) or item.model)
		net.WriteUInt(item.id, 32)
	net.Send(client)

	return false
end

--[[
	The click. The item is found again here rather than trusted from the
	message, the spot is checked for reach and for room for the whole box,
	and only then does the vehicle exist and the item not.
]]
net.Receive("ixVehiclePlace", function(_, client)
	local itemID = net.ReadUInt(32)
	local position = net.ReadVector()
	local angles = net.ReadAngle()

	local item = ix.item.instances[itemID]

	if (not item or (not item.vehicleClass and not item.deployClass)) then return end
	if (item:GetOwner() ~= client) then return end

	local ok, why = Allowed(client, item)

	if (not ok) then
		if (why) then client:Notify(why) end

		return
	end

	local reachable, because = ix.deploy.CanPlace(client, position)

	if (not reachable) then
		client:Notify(because or "You cannot put it there.")

		return
	end

	local class = item.vehicleClass or item.deployClass
	local definition = scripted_ents.Get(class)

	if (not definition) then return end

	local vehicle = ents.Create(class)

	if (not IsValid(vehicle)) then return end

	vehicle:SetModel(definition.MDL or vehicle:GetModel())

	local lift = tonumber(definition.SpawnNormalOffset) or 40
	local spot = position + Vector(0, 0, lift)

	if (item.vehicleClass) then
		local room = util.TraceHull({start = spot, endpos = spot,
			mins = vehicle:OBBMins(), maxs = vehicle:OBBMaxs(), filter = client,
			mask = MASK_SOLID})

		if (room.Hit or room.StartSolid) then
			vehicle:Remove()
			client:Notify("Not enough room there.")

			return
		end
	end

	vehicle:SetPos(spot)
	vehicle:SetAngles(Angle(0, angles.y, 0))

	if (vehicle.StoreCPPI) then vehicle:StoreCPPI(client) end

	vehicle:SetCreator(client)
	vehicle:Spawn()
	vehicle:Activate()

	local name = item.name

	item:Remove()

	if (not item.vehicleClass) then
		ix.log.Add(client, "vehicleDeploy", name)

		return
	end

	ix.vehicles.Track(vehicle, client, item.uniqueID)

	client:Notify(string.format("%s deployed. /vehiclepack folds it up while nobody is in it.",
		name))
	ix.log.Add(client, "vehicleDeploy", name)
end)

--------------------------------------------------------------------------------
-- Taking one away
--------------------------------------------------------------------------------

--- Fold it into the item, into the hands of whoever asked.
function ix.vehicles.Pack(client, vehicle)
	local data = ix.vehicles.list[vehicle]

	if (not data) then return false, "That is not a deployed vehicle." end

	if (not ix.vehicles.CanManage(client, vehicle)) then
		return false, "That is not your vehicle."
	end

	if (Occupied(vehicle)) then return false, "Somebody is still in it." end

	if (vehicle.IsDestroyed and vehicle:IsDestroyed()) then
		return false, "It is wrecked."
	end

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory or inventory:Add(data.uniqueID) == false) then
		return false, "There is no room in your inventory for it."
	end

	local name = ix.vehicles.Name(vehicle)

	ix.vehicles.list[vehicle] = nil
	vehicle:Remove()

	ix.log.Add(client, "vehiclePack", name)

	return true, name .. " packed up."
end

--- Gone, item and all.
function ix.vehicles.Remove(vehicle, why)
	local data = ix.vehicles.list[vehicle]

	if (data) then
		ix.log.Add(nil, "vehicleRemove", ix.vehicles.Name(vehicle), data.owner, why)
	end

	ix.vehicles.list[vehicle] = nil

	if (IsValid(vehicle)) then vehicle:Remove() end
end

--- Nothing stands unused for long.
timer.Create("ixVehiclesSweep", 30, 0, function()
	local limit = ix.config.Get("vehicleDespawnEmpty", 3600)

	for vehicle, data in pairs(ix.vehicles.list) do
		if (not IsValid(vehicle)) then
			ix.vehicles.list[vehicle] = nil
		elseif (Occupied(vehicle)) then
			data.used = CurTime()
		elseif (limit > 0 and CurTime() - data.used > limit) then
			ix.vehicles.Remove(vehicle, "unused for " .. math.Round(limit / 60) .. " minutes")
		end
	end
end)

--- Destroyed is gone: the wreck goes with the explosion, the item with it.
hook.Add("LVS.OnVehicleDestroyed", "ixVehicles", function(vehicle)
	local data = ix.vehicles.list[vehicle]

	if (not data) then return end

	ix.vehicles.list[vehicle] = nil

	ix.log.Add(nil, "vehicleDestroyed", ix.vehicles.Name(vehicle), data.owner)
end)

--[[
	THE DRIVER'S SEAT ON THE WAY IN. LVS asks `LVS.CanPlayerDrive` from its
	seat switcher and on entry; this is the belt to those braces. The moment
	anybody is seated, the driver's seat of an owned vehicle is checked, and
	somebody who may not drive is put out again.
]]
hook.Add("PlayerEnteredVehicle", "ixVehicles", function(client, pod)
	if (not IsValid(pod)) then return end

	local vehicle = pod.GetVehicle and pod:GetVehicle() or pod:GetParent()

	if (not ix.vehicles.IsVehicle(vehicle)) then return end
	if (ix.vehicles.Owner(vehicle) == nil) then return end

	local driverSeat = vehicle.GetDriverSeat and vehicle:GetDriverSeat()

	if (driverSeat ~= pod) then return end
	if (ix.vehicles.CanDrive(client, vehicle)) then return end

	timer.Simple(0, function()
		if (IsValid(client) and client:GetVehicle() == pod) then
			client:ExitVehicle()
			client:Notify(string.format("This is %s's vehicle.",
				ix.vehicles.OwnerName(vehicle)))
		end
	end)
end)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

--[[
	The vehicle in front of somebody. A trace first, walked up the parent
	chain - a seat, a wheel, a rotor, a door - and when the trace hits
	nothing, the nearest vehicle whose body the line of sight passes
	through: a model the trace goes straight through, which the Vertibird's
	does ("Look at a vehicle first", stood in its cabin).
]]
local function Looked(client)
	local start, dir = client:EyePos(), client:GetAimVector()
	local trace = util.TraceLine({start = start, endpos = start + dir * 2000, filter = client})
	local entity = trace.Entity

	for _ = 1, 6 do
		if (not IsValid(entity) or ix.vehicles.IsVehicle(entity)) then break end

		entity = entity:GetParent()
	end

	if (ix.vehicles.IsVehicle(entity)) then return entity end

	local best, bestAlong

	for _, vehicle in ipairs(ents.FindInSphere(start, 1500)) do
		if (not ix.vehicles.IsVehicle(vehicle)) then continue end

		local centre = vehicle:LocalToWorld(vehicle:OBBCenter())
		local along = (centre - start):Dot(dir)

		if (along <= 0) then continue end

		local miss = (centre - (start + dir * along)):Length()

		if (miss <= vehicle:BoundingRadius() + 64 and (not bestAlong or along < bestAlong)) then
			best, bestAlong = vehicle, along
		end
	end

	return best
end

--- The nearest vehicle within reach, for the one thing done from inside one.
local function Nearest(client)
	local best, bestDistance
	local at = client:GetPos()

	for _, vehicle in ipairs(ents.FindInSphere(at, 800)) do
		if (not ix.vehicles.IsVehicle(vehicle)) then continue end

		local distance = at:DistToSqr(vehicle:LocalToWorld(vehicle:OBBCenter()))

		if (not bestDistance or distance < bestDistance) then
			best, bestDistance = vehicle, distance
		end
	end

	return best
end

ix.command.Add("VehicleSeat", {
	description = "Set a vehicle's seats by standing in them: driver, add, view (the driver's eyes), clear, show.",
	privilege = "Manage Vehicles",
	arguments = {ix.type.text},

	OnCheckAccess = function(self, client)
		return ix.admin and ix.admin.Can(client, "vehicle.manage") or false
	end,

	OnRun = function(self, client, what)
		what = string.lower(string.Trim(what or ""))

		--[[
			The view is set from where the eyes should be, which is rarely a
			spot the vehicle is in view from - the cockpit glass is above
			and behind the nose - so that one takes the nearest aircraft.
		]]
		local vehicle = Looked(client) or (what == "view" and Nearest(client)) or nil

		if (not vehicle) then return "Look at a vehicle first." end

		if (what == "view" and vehicle.ixVehicleKind ~= "helicopter") then
			return "The view is set for aircraft only; a car's driver looks out of the seat."
		end

		local class = vehicle:GetClass()

		LoadSeats()

		local seats = ix.vehicles.seats[class] or {passengers = {}}

		if (what == "driver") then
			seats.driver = Sitting(client, vehicle)
		elseif (what == "add") then
			seats.passengers = seats.passengers or {}
			seats.passengers[#seats.passengers + 1] = Sitting(client, vehicle)
		elseif (what == "view") then
			--- Where the driver's first-person view sits, and the way it looks: the asker's own.
			local look = vehicle:WorldToLocalAngles(client:EyeAngles())

			seats.view = {pos = vehicle:WorldToLocal(client:EyePos()),
				ang = {p = math.Round(look.p), y = math.Round(look.y)}}
		elseif (what == "clear") then
			ix.vehicles.seats[class] = nil
			SaveSeats()
			Respawn(vehicle)

			return class .. ": seats forgotten; the definition's own are back."
		elseif (what == "show") then
			local lines = {}

			if (seats.driver) then
				lines[#lines + 1] = string.format("driver %s yaw %d",
					tostring(seats.driver.pos), seats.driver.yaw or 0)
			end

			for index, seat in ipairs(seats.passengers or {}) do
				lines[#lines + 1] = string.format("passenger %d %s", index, tostring(seat.pos))
			end

			if (seats.view) then
				lines[#lines + 1] = string.format("view %s looking p %d y %d",
					tostring(seats.view.pos), seats.view.ang and seats.view.ang.p or 0,
					seats.view.ang and seats.view.ang.y or 0)
			end

			return #lines > 0 and (class .. ": " .. table.concat(lines, "; "))
				or (class .. ": no seats set in game")
		else
			return "Usage: /vehicleseat driver | add | view | clear | show"
		end

		ix.vehicles.seats[class] = seats
		SaveSeats()
		Respawn(vehicle)

		ix.log.Add(client, "vehicleSeat", class, what)

		return string.format("%s: %s seat set at %s. Respawned.", class, what,
			tostring(Sitting(client, vehicle).pos))
	end
})

ix.command.Add("VehiclePack", {
	description = "Fold the vehicle you are looking at back into its item.",

	OnRun = function(self, client)
		local vehicle = Looked(client)

		if (not vehicle) then return "Look at a vehicle first." end

		local ok, said = ix.vehicles.Pack(client, vehicle)

		return said
	end
})

ix.command.Add("VehicleRemove", {
	description = "Remove the vehicle you are looking at.",
	privilege = "Manage Vehicles",

	OnCheckAccess = function(self, client)
		return ix.admin and ix.admin.Can(client, "vehicle.manage") or false
	end,

	OnRun = function(self, client)
		local vehicle = Looked(client)

		if (not vehicle) then return "Look at a vehicle first." end

		ix.vehicles.Remove(vehicle, "removed by " .. client:Name())

		return "Removed."
	end
})

ix.command.Add("Vehicles", {
	description = "Where your deployed vehicles are.",

	OnRun = function(self, client)
		local character = client:GetCharacter()

		if (not character) then return end

		local lines = {}

		for vehicle, data in pairs(ix.vehicles.list) do
			if (IsValid(vehicle) and data.owner == character:GetID()) then
				lines[#lines + 1] = string.format("%s, %dm away",
					ix.vehicles.Name(vehicle),
					math.Round(vehicle:GetPos():Distance(client:GetPos()) / 52.5))
			end
		end

		if (#lines == 0) then return "You have no vehicle out." end

		return table.concat(lines, "; ")
	end
})

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("vehicleDeploy", function(client, name)
	return string.format("%s deployed a %s.", client:Name(), name)
end, FLAG_NORMAL)

ix.log.AddType("vehiclePack", function(client, name)
	return string.format("%s packed up a %s.", client:Name(), name)
end, FLAG_NORMAL)

ix.log.AddType("vehicleRemove", function(_, name, owner, why)
	return string.format("A %s belonging to character #%s was removed: %s.",
		name, tostring(owner), why)
end, FLAG_NORMAL)

ix.log.AddType("vehicleDestroyed", function(_, name, owner)
	return string.format("A %s belonging to character #%s was destroyed.",
		name, tostring(owner))
end, FLAG_WARNING)

ix.log.AddType("vehicleSeat", function(client, class, what)
	return string.format("%s set the %s seat of %s.", client:Name(), what, class)
end, FLAG_NORMAL)

--- For the crash watch: what was standing when the server went.
hook.Add("OnEntityCreated", "ixVehiclesWatch", function(entity)
	timer.Simple(0, function()
		if (IsValid(entity) and entity.LVS and ix.crashwatch and ix.crashwatch.Note) then
			ix.crashwatch.Note("vehicle spawned: " .. entity:GetClass())
		end
	end)
end)

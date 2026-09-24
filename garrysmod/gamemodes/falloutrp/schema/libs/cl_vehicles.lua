--[[
	Vehicles on the screen: whose it is, when you look at one.

	A line over the vehicle under the crosshair, within a few hundred units:
	its name, and its owner, or that it is yours and how to pack it. LVS
	entities are not Helix's, so `PopulateEntityInfo` never sees them; this
	is the one place a vehicle says anything.

	`ix.vehicles` is declared here too: `cl_` loads before `sh_`.
]]

if (not CLIENT) then return end

ix.vehicles = ix.vehicles or {}

--- The ghost; the placement flow is `cl_deploy.lua`'s, shared with plots and benches.
net.Receive("ixVehicleBeginPlacing", function()
	local model = net.ReadString()
	local itemID = net.ReadUInt(32)

	if (not ix.deploy.Begin(model, function(position, angles)
		net.Start("ixVehiclePlace")
			net.WriteUInt(itemID, 32)
			net.WriteVector(position)
			net.WriteAngle(angles)
		net.SendToServer()
	end)) then
		LocalPlayer():Notify("That model could not be loaded.")

		return
	end

	LocalPlayer():Notify("Left click to place, J and K to turn, right click to cancel.")
end)

local function Looked()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local trace = util.TraceLine({start = client:EyePos(),
		endpos = client:EyePos() + client:GetAimVector() * 500, filter = client})
	local entity = trace.Entity

	if (not IsValid(entity)) then return end

	if (not entity.LVS) then
		local parent = entity:GetParent()

		if (IsValid(parent) and parent.LVS) then entity = parent end
	end

	if (not entity.LVS) then return end

	return entity
end

hook.Add("HUDPaint", "ixVehicles", function()
	local client = LocalPlayer()

	if (IsValid(client) and client:InVehicle()) then return end

	local vehicle = Looked()

	if (not vehicle) then return end

	local owner = vehicle:GetNetVar("ixVehicleOwner")
	local name = ix.vehicles.Name and ix.vehicles.Name(vehicle) or vehicle.PrintName or "Vehicle"
	local top = vehicle:LocalToWorld(Vector(0, 0, vehicle:OBBMaxs().z + 12)):ToScreen()

	if (not top.visible) then return end

	local lines = {{name, Color(255, 255, 255)}}

	if (owner == nil) then
		lines[2] = {"nobody's", Color(190, 190, 180)}
	elseif (ix.vehicles.Owns and ix.vehicles.Owns(client, vehicle)) then
		lines[2] = {"yours  -  /vehiclepack folds it up while nobody is in it",
			Color(160, 210, 160)}
	else
		lines[2] = {vehicle:GetNetVar("ixVehicleOwnerName", "somebody") .. "'s",
			Color(220, 200, 150)}
	end

	for index, line in ipairs(lines) do
		draw.SimpleTextOutlined(line[1], "DermaDefaultBold", top.x,
			top.y + (index - 1) * 16, line[2], TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP,
			1, Color(0, 0, 0, 200))
	end
end)

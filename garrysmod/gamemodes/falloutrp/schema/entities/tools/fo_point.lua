--[[
	The point tool: cap stashes, capture points and orbital drop sites.

	    left click    place one where you are pointing
	    right click   remove the one you are pointing at
	    reload        rename the one you are pointing at

	One tool with a dropdown rather than three tools, for the reason the zone
	tool gives: they differ in what they spawn and in nothing else, and three
	near-identical files is three places for the permission check to drift.

	SERVER ONLY, like every tool here - the client's click is predicted and can
	fire more than once for one press, so anything that spawns must happen at
	the end that only sees it once. See `fo_zone.lua` for the longer note,
	including why the convars are created by hand.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_point.name"

TOOL.ClientConVar = {
	type = "capstash",
	model = "",
	name = "",
	caps = "250",
	respawn = "900",
	capturetime = "45",
	radius = "160",
	payout = "50",
	payoutinterval = "5",
	factions = "",
	plant = "xanderroot",
	plantrespawn = "300",
	plantyield = "1",
	plantxp = "-1",
	plantcollisions = "0"
}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_point.name", "Point Placer")
	language.Add("tool.fo_point.desc",
		"Cap stashes, capture points and drop sites.")
	language.Add("tool.fo_point.0",
		"Left click to place. Right click to remove. Reload to rename.")
end

--[[
	The faction list from the panel, as uniqueIDs.

	Comma-separated unique IDs rather than a menu, because a tool panel is a
	set of convars and a multi-select is not one of them. The panel prints the
	list of ids underneath so nobody has to guess them.

	Anything that is not a faction is dropped and SAID SO - silently ignoring a
	typo would leave somebody certain they had let the NCR onto a point.
]]
function TOOL:FactionList()
	local text = self:GetClientInfo("factions") or ""
	local out, bad = {}, {}

	for _, piece in ipairs(string.Explode(",", text)) do
		piece = string.lower(string.Trim(piece))

		if (piece == "") then continue end

		if (ix.faction.teams[piece]) then
			out[#out + 1] = piece
		else
			bad[#bad + 1] = piece
		end
	end

	return out, bad
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "point.edit")) then
		client:Notify("You cannot place points.")

		return false
	end

	return true
end

--------------------------------------------------------------------------------
-- Placing
--------------------------------------------------------------------------------

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end
	if (trace.HitSky or not trace.Hit) then return false end

	local client = self:GetOwner()
	local typeID = self:GetClientInfo("type") or "capstash"
	local pointType = ix.points.byID[typeID]

	if (not pointType) then
		client:Notify("'" .. typeID .. "' is not a point type.")

		return false
	end

	--[[
		Stood up and turned to face whoever placed it.

		A flagpole lying on its side because the ground was a ramp is the
		normal result of using the surface normal, and none of these are things
		that should ever be anything but upright. Only the yaw is taken from
		the player.
	]]
	local angles = Angle(0, client:EyeAngles().y + 180, 0)

	local ok, result = ix.points.Add(client, typeID, trace.HitPos + Vector(0, 0, 2),
		angles, self:GetClientInfo("model") or "")

	if (not ok) then
		client:Notify(result)

		return false
	end

	self:ApplySettings(ix.points.stored[result], true)

	client:Notify("Placed a " .. pointType.name .. ".")

	return true
end

--[[
	Write the panel's settings onto one record.

	SHARED BY PLACING AND BY RELOAD, which is the whole point of it existing.
	Reload used to set the name and nothing else, so changing a stash's caps or
	a point's payout meant deleting it and placing it again - and the reason
	was simply that the two paths had been written separately and only one of
	them had ever been finished.

	`bFresh` is what tells a cap stash to fill itself up. Placing one should
	hand it its caps; editing one that somebody emptied five minutes ago should
	not quietly refill it as a side effect of changing its respawn time.
]]
function TOOL:ApplySettings(record, bFresh)
	if (not record) then return false end

	local client = self:GetOwner()
	local typeID = record.type
	local name = string.Trim(self:GetClientInfo("name") or "")

	if (name ~= "") then record.data.name = name end

	if (typeID == "capstash") then
		record.data.caps = math.Clamp(
			tonumber(self:GetClientInfo("caps")) or 250, 0, 100000)
		record.data.respawn = math.Clamp(
			tonumber(self:GetClientInfo("respawn")) or 900, 10, 86400)

		if (bFresh) then
			record.data.remaining = record.data.caps
			record.data.refillAt = 0
		end
	elseif (typeID == "captureflag") then
		record.data.captureTime = math.Clamp(
			tonumber(self:GetClientInfo("capturetime")) or 45, 5, 3600)
		record.data.radius = math.Clamp(
			tonumber(self:GetClientInfo("radius")) or 160, 32, 2048)
		record.data.payout = math.Clamp(
			tonumber(self:GetClientInfo("payout")) or 0, 0, 100000)
		record.data.payoutInterval = math.Clamp(
			tonumber(self:GetClientInfo("payoutinterval")) or 5, 1, 240)

		local list, bad = self:FactionList()

		record.data.factions = list

		if (#bad > 0 and IsValid(client)) then
			client:Notify("Not a faction, ignored: " .. table.concat(bad, ", "))
		end
	elseif (typeID == "plant") then
		local plantID = string.lower(string.Trim(
			self:GetClientInfo("plant") or ""))
		local plant = ix.plants.Get(plantID)

		if (not plant) then
			if (IsValid(client)) then
				client:Notify("'" .. plantID .. "' is not a plant, using "
					.. "the last one.")
			end
		else
			record.data.plant = plant.id
		end

		record.data.respawn = math.Clamp(
			tonumber(self:GetClientInfo("plantrespawn")) or 300, 10, 86400)
		record.data.yield = math.Clamp(
			math.floor(tonumber(self:GetClientInfo("plantyield")) or 1), 1, 20)

		--[[
			MINUS ONE MEANS "USE THE CONFIG", and that is the slider's left
			end rather than a checkbox next to it. A plant that says nothing
			about experience follows the server-wide `plantXP`; one that names
			a number keeps it whatever the config is set to afterwards.
		]]
		record.data.xp = math.Clamp(
			math.floor(tonumber(self:GetClientInfo("plantxp")) or -1), -1, 1000)
		record.data.collisions =
			tonumber(self:GetClientInfo("plantcollisions")) == 1

		--[[
			A model typed into the box beats the kind's own; anything else
			follows whatever plant was chosen. `OnRestored` is what actually
			swaps it, so this only has to record which of the two applies.
		]]
		record.data.customModel =
			string.Trim(self:GetClientInfo("model") or "") ~= "" or nil

		if (bFresh) then record.data.refillAt = 0 end
	end

	--[[
		The entity is told to read its record again. Everything each kind keeps
		on itself - the caps, the radius, the name over its head - is set from
		`OnRestored`, so one call is the whole of "apply this".
	]]
	local entity = record.entity

	if (IsValid(entity) and entity.OnRestored) then
		entity:OnRestored(record)
	end

	ix.points.Save()

	return true
end

--------------------------------------------------------------------------------
-- Removing and renaming
--------------------------------------------------------------------------------

function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local entity = trace.Entity

	if (not IsValid(entity) or not ix.points.TypeOf(entity)) then
		client:Notify("That is not one of these.")

		return false
	end

	local ok, why = ix.points.Remove(client, entity)

	if (not ok) then
		client:Notify(why)

		return false
	end

	client:Notify("Removed.")

	return true
end

--[[
	Reload applies EVERYTHING in the panel to whatever is under the crosshair -
	the name, the caps, the respawn, the capture time, the payout, the faction
	list.

	The panel rather than a menu because the values are already fields on the
	tool, and a Derma prompt would mean a message from the server to open it
	and another back with the answer for something the tool can already read.

	A blank name is left alone rather than clearing it, so adjusting a payout
	does not silently rename the point to nothing.
]]
function TOOL:Reload(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local entity = trace.Entity

	if (not IsValid(entity) or not ix.points.TypeOf(entity)) then
		client:Notify("Point at one of these to apply the panel to it.")

		return false
	end

	local record = entity.ixPointID and ix.points.stored[entity.ixPointID]

	if (not record) then
		client:Notify("That one is not in the list.")

		return false
	end

	self:ApplySettings(record, false)

	client:Notify("Settings applied.")

	return true
end

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Left click to place, right click to remove, reload to "
			.. "rename."
	})

	local types = {}

	for _, pointType in ipairs(ix.points.types) do
		types[pointType.name] = {fo_point_type = pointType.id}
	end

	panel:AddControl("ComboBox", {
		Label = "Type",
		MenuButton = 0,
		Options = types
	})

	panel:TextEntry("Name", "fo_point_name")
	panel:TextEntry("Model (blank for the default)", "fo_point_model")

	panel:Help("Cap stash")
	panel:NumSlider("Caps it holds", "fo_point_caps", 0, 5000, 0)
	panel:NumSlider("Seconds to refill", "fo_point_respawn", 10, 7200, 0)

	panel:Help("Capture point")
	panel:NumSlider("Seconds to capture", "fo_point_capturetime", 5, 600, 0)
	panel:NumSlider("Half-width of the square", "fo_point_radius", 32, 1024, 0)
	panel:NumSlider("Caps paid to each member", "fo_point_payout", 0, 5000, 0)
	panel:NumSlider("Minutes between payments", "fo_point_payoutinterval",
		1, 240, 0)
	panel:TextEntry("Factions allowed (comma separated)", "fo_point_factions")

	local ids = {}

	for uniqueID in pairs(ix.faction.teams) do
		ids[#ids + 1] = uniqueID
	end

	table.sort(ids)

	panel:Help("Leave the factions blank to let any faction take it. A "
		.. "default faction - Wastelanders - can never hold one.")
	panel:Help("Factions: " .. table.concat(ids, ", "))

	panel:Help("Plant")

	local plants = {}

	for _, plant in ipairs(ix.plants.types) do
		plants[plant.name] = {fo_point_plant = plant.id}
	end

	panel:AddControl("ComboBox", {
		Label = "Which plant",
		MenuButton = 0,
		Options = plants
	})

	panel:NumSlider("Seconds to grow back", "fo_point_plantrespawn",
		10, 7200, 0)
	panel:NumSlider("How many it gives", "fo_point_plantyield", 1, 20, 0)
	panel:NumSlider("Experience it gives (-1 uses the config)",
		"fo_point_plantxp", -1, 500, 0)
	panel:CheckBox("Players collide with it", "fo_point_plantcollisions")
	panel:Help("Leaving the model blank lets the plant choose its own, which "
		.. "is what you want - a model typed in here overrides it and stays "
		.. "put when the kind is changed.")

	panel:Help("A drop site is a marker only - nothing lands on it yet.")
end

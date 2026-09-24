--[[
	Doors - what the extra rules look like.

	    the sign      the factions on a door, under its name
	    the thread    where a teleport door goes, while the tool is out

	`GetDoorInfo` IS HELIX'S OWN EXTENSION POINT:

	    local info = hook.Run("GetDoorInfo", door) or self:GetDefaultDoorInfo(door)

	Returning a table REPLACES the default outright, so this builds on top of
	the default rather than instead of it - a door with no extra rules returns
	nothing at all and Helix draws exactly what it always did.
]]

if (not CLIENT) then return end

--- `libs/` is alphabetical, so `sh_doors.lua` has not run yet.
ix.doors = ix.doors or {}
ix.doors.factions = ix.doors.factions or {}
ix.doors.links = ix.doors.links or {}
ix.doors.propLinks = ix.doors.propLinks or {}
ix.doors.deleted = ix.doors.deleted or {}

--[[
	The map's triggers, as the server described them.

	`trigger_teleport` and its relatives are SERVER-ONLY entities: no model,
	never transmitted. `ents.GetAll()` on this end does not contain a single
	one, which is why the remover highlighted nothing at all - the tool was
	asking somebody to point at something their game had never been told about.

	So the server sends their shapes and this draws those. See
	`ix.doors.SendWorld`.
]]
ix.doors.triggers = ix.doors.triggers or {}

net.Receive("ixDoorSync", function()
	local length = net.ReadUInt(32)
	local data = util.Decompress(net.ReadData(length))

	if (not data) then
		ErrorNoHalt("[falloutrp] could not decompress the door rules\n")

		return
	end

	local decoded = util.JSONToTable(data) or {}

	--[[
		Renumbered on arrival, for the same reason the server renumbers on
		load: JSON has no integer keys, and `MapCreationID` returns a number.
		A table keyed by "42" and looked up with 42 is an empty table that
		looks full in a print.
	]]
	ix.doors.factions = {}
	ix.doors.links = {}

	for key, value in pairs(decoded.factions or {}) do
		ix.doors.factions[tonumber(key) or key] = value
	end

	for key, value in pairs(decoded.links or {}) do
		value.position = isvector(value.position) and value.position
			or Vector(value.position)

		ix.doors.links[tonumber(key) or key] = value
	end

	ix.doors.propLinks = {}

	for key, value in pairs(decoded.props or {}) do
		value.position = isvector(value.position) and value.position
			or Vector(value.position)
		value.origin = isvector(value.origin) and value.origin
			or Vector(value.origin)

		ix.doors.propLinks[tonumber(key) or key] = value
	end

	ix.doors.deleted = {}

	for key, value in pairs(decoded.deleted or {}) do
		ix.doors.deleted[tonumber(key) or key] = value
	end

	ix.doors.AttachPropLinks()
end)

net.Receive("ixDoorWorld", function()
	local length = net.ReadUInt(32)
	local data = util.Decompress(net.ReadData(length))

	ix.doors.triggers = data and util.JSONToTable(data) or {}

	--- JSON gives back plain tables; the draw code wants vectors.
	for _, trigger in ipairs(ix.doors.triggers) do
		trigger.pos = Vector(trigger.pos)
		trigger.ang = Angle(trigger.ang)
		trigger.mins = Vector(trigger.mins)
		trigger.maxs = Vector(trigger.maxs)
	end
end)

--[[
	Props arrive after the link list does, so the tagging is repeated.

	A permanent prop is restored some time after the map loads and reaches a
	client some time after that; a link tagged once, on arrival, would attach
	to nothing on a fresh join. Every few seconds costs one sphere query per
	link and is never wrong for long.
]]
timer.Create("ixDoorsAttach", 5, 0, function()
	if (table.IsEmpty(ix.doors.propLinks)) then return end

	ix.doors.AttachPropLinks()
end)

--------------------------------------------------------------------------------
-- The sign on the door
--------------------------------------------------------------------------------

hook.Add("GetDoorInfo", "ixDoors", function(door)
	local factions = ix.doors.Factions(door)
	local link = ix.doors.Link(door)

	--- Nothing extra to say, so Helix says what it always said.
	if (#factions == 0 and not link) then return end

	local plugin = ix.plugin.Get("doors")
	local info = plugin and plugin.GetDefaultDoorInfo
		and plugin:GetDefaultDoorInfo(door)

	if (not istable(info)) then
		info = {
			name = door:GetNetVar("title", door:GetNetVar("name", "Door")),
			description = "",
			color = ix.config.Get("color")
		}
	end

	if (#factions > 0) then
		local names = {}

		for _, faction in ipairs(factions) do
			names[#names + 1] = faction.name
		end

		info.description = table.concat(names, ", ")

		--[[
			One faction on the list means its colour; several means the door
			belongs to an arrangement rather than to anybody, so it keeps the
			default. Blending them would produce a brown nobody chose.
		]]
		if (#factions == 1 and factions[1].color) then
			info.color = factions[1].color
		end
	end

	if (link) then
		local where = link.name ~= "" and link.name or "somewhere else"

		info.name = info.name .. "  ->  " .. where

		if (ix.doors.Locked(door)) then
			info.description = info.description ~= ""
				and (info.description .. " - locked")
				or "locked"
		end
	end

	return info
end)

--------------------------------------------------------------------------------
-- The thread, while the teleport tool is out
--------------------------------------------------------------------------------

local function HoldingTool(mode)
	local client = LocalPlayer()

	if (not IsValid(client)) then return false end

	local weapon = client:GetActiveWeapon()

	if (not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool") then
		return false
	end

	return client:GetInfo("gmod_toolmode") == mode
end

--- Where the tool's first click landed, sent by `ix.doors.SendPending`.
net.Receive("ixDoorPending", function()
	local has = net.ReadBool()

	ix.doors.pending = has and net.ReadEntity() or nil
end)

hook.Add("PostDrawTranslucentRenderables", "ixDoors", function(depth, skybox)
	if (skybox or not HoldingTool("fo_teleport")) then return end

	--[[
		A line from each teleport door to where it sends you, and a box at the
		far end. Without it a teleport is invisible until you walk into it, and
		checking a dozen of them would mean walking through a dozen of them.
	]]
	for id, link in pairs(ix.doors.links) do
		local door = ents.GetMapCreatedEntity(id)

		if (not IsValid(door)) then continue end

		render.SetColorMaterial()
		render.DrawLine(door:GetPos() + door:OBBCenter(), link.position,
			Color(140, 220, 255), true)

		render.DrawWireframeBox(link.position, angle_zero,
			Vector(-16, -16, 0), Vector(16, 16, 72), Color(140, 220, 255),
			true)

		cam.Start2D()
			local screen = link.position:ToScreen()

			draw.SimpleText(link.name ~= "" and link.name or "exit",
				"ixZoneNote", screen.x, screen.y, Color(140, 220, 255),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End2D()
	end

	--[[
		The same for teleports on props. They are not in `ix.doors.links` and
		have no `MapCreationID` to look up, so they are found through the tag
		`AttachPropLinks` puts on the entity.
	]]
	for _, link in pairs(ix.doors.propLinks) do
		render.SetColorMaterial()
		render.DrawLine(link.origin, link.position, Color(200, 180, 255), true)

		render.DrawWireframeBox(link.position, angle_zero,
			Vector(-16, -16, 0), Vector(16, 16, 72), Color(200, 180, 255),
			true)

		cam.Start2D()
			local screen = link.position:ToScreen()

			draw.SimpleText(link.name ~= "" and link.name or "exit",
				"ixZoneNote", screen.x, screen.y, Color(200, 180, 255),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End2D()
	end

	--- The door waiting for its destination.
	local pending = ix.doors.pending

	if (not IsValid(pending)) then return end

	local hit = LocalPlayer():GetEyeTrace().HitPos

	render.SetColorMaterial()
	render.DrawLine(pending:GetPos() + pending:OBBCenter(), hit,
		Color(255, 255, 255, 200), true)

	render.DrawWireframeBox(hit, angle_zero, Vector(-16, -16, 0),
		Vector(16, 16, 72), Color(255, 255, 255,
			40 + (1 + math.sin(SysTime() * 6)) * 100), true)
end)

--------------------------------------------------------------------------------
-- The map's teleports, while that tool is out
--------------------------------------------------------------------------------

hook.Add("PostDrawTranslucentRenderables", "ixDoorsWorld", function(_, skybox)
	if (skybox or not HoldingTool("fo_worldtp")) then return end

	--[[
		Drawn from the list the server sent, not from `ents.GetAll()` - see the
		note at the top of this file. Its bounding box IS the trigger, so that
		is what is drawn.
	]]
	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		return
	end

	for _, trigger in ipairs(ix.doors.triggers) do
		render.DrawWireframeBox(trigger.pos, trigger.ang, trigger.mins,
			trigger.maxs, Color(255, 120, 60), true)

		cam.Start2D()
			local centre = trigger.pos + (trigger.mins + trigger.maxs) * 0.5
			local screen = centre:ToScreen()

			draw.SimpleText(trigger.class, "ixZoneNote", screen.x, screen.y,
				Color(255, 120, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End2D()
	end
end)

--------------------------------------------------------------------------------
-- What a teleport says about itself
--------------------------------------------------------------------------------

--[[
	Drawn BY US, on the HUD, for anything you are looking at that is a
	teleport.

	Helix's own door sign was the obvious place and cannot do it. Its draw pass
	is

	    if (!IsValid(v) or !v:IsDoor() or !v:GetNetVar("visible")) then

	so a teleport on a PROP is skipped for not being a door, and a door is
	skipped unless something has explicitly set `visible` on it - which nothing
	does by default. The `GetDoorInfo` hook above still improves the sign
	wherever Helix does draw one; this is what makes the information exist at
	all.

	On the HUD rather than in the world because it appears exactly when it is
	wanted - you are looking at the thing - and needs no guess about which way
	an arbitrary prop is facing.
]]
local REACH = 110

local function LookingAtTeleport()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:Alive()) then return end

	local entity = client:GetEyeTrace().Entity

	if (not IsValid(entity)) then return end
	if (client:GetShootPos():Distance(entity:GetPos()) > REACH * 2) then
		return
	end

	local link = ix.doors.Link(entity)

	return link and entity or nil, link
end

hook.Add("HUDPaint", "ixDoors", function()
	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		return
	end

	local entity, link = LookingAtTeleport()

	if (not entity) then return end

	local locked = ix.doors.Locked(entity)
	local factions = ix.doors.Factions(entity)
	local x, y = ScrW() * 0.5, ScrH() * 0.56

	local name = (link.name ~= "" and link.name) or "Teleport"

	draw.SimpleText(name, "ixZoneName", x + 2, y + 2, Color(0, 0, 0, 190),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	--- Whatever the tool set, or the old locked/unlocked pair. See `Colour`.
	draw.SimpleText(name, "ixZoneName", x, y, ix.doors.Colour(entity),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local parts = {locked and "LOCKED" or "unlocked"}

	--[[
		Which way it goes is NOT on the sign.

		It is a property of how the teleport was built rather than anything the
		person standing in front of it can act on - they walk through it and
		find out - and the line is short enough to read at a glance only while
		everything on it is something they need.
	]]
	local owner = ix.doors.Owner(entity)
	local price = ix.doors.Price(entity)

	if (owner) then
		parts[#parts + 1] = "owned by " .. owner.name
	elseif (price > 0) then
		parts[#parts + 1] = string.format("for sale - %s - /buydoor",
			ix.points.FormatCaps(price))
	end

	if (#factions > 0) then
		local names = {}

		for _, faction in ipairs(factions) do
			names[#names + 1] = faction.name
		end

		parts[#parts + 1] = table.concat(names, ", ")
	else
		parts[#parts + 1] = "anybody"
	end

	local below = y + 28

	draw.SimpleText(table.concat(parts, "  -  "), "ixZoneNote", x + 1,
		below + 1, Color(0, 0, 0, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(table.concat(parts, "  -  "), "ixZoneNote", x, below,
		Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--------------------------------------------------------------------------------
-- Deleted map entities, for the tool panels
--------------------------------------------------------------------------------

--[[
	One row per thing taken out of the map, with a button to put it back.

	Shared by both removers because it is one list - `fo_worldtp` shows the
	teleports and `fo_worldprop` shows everything else, and the filter is the
	only difference between them.

	IT BUILDS INTO A CONTAINER, NOT INTO THE TOOL PANEL. `panel:Clear()` would
	take the tool's own header and buttons with it, so the rows live in a panel
	of their own and only that is emptied and refilled.

	Restoring only takes the entry off the list: the engine rebuilds map
	entities from the BSP, so nothing reappears until the map reloads. The
	button says so rather than leaving it to be discovered.
]]
function ix.doors.BuildDeletedList(panel, bTeleports)
	local container = vgui.Create("DPanel")

	container:SetPaintBackground(false)

	panel:AddItem(container)

	local Refresh

	Refresh = function()
		container:Clear()

		local tall, shown = 0, 0

		for id, record in SortedPairs(ix.doors.deleted) do
			--[[
				An older save wrote `true` rather than a description. Read
				rather than migrated, because a list of ids is still a list you
				can restore from - it just reads worse.
			]]
			if (not istable(record)) then record = {class = "unknown"} end

			local isTeleport = ix.doors.worldClasses[record.class or ""]
				and true or false

			if (isTeleport ~= bTeleports) then continue end

			shown = shown + 1

			local row = container:Add("DButton")

			row:Dock(TOP)
			row:SetTall(22)
			row:DockMargin(0, 0, 0, 2)
			row:SetText(string.format("restore  %s  (%s)",
				record.class or "?", tostring(id)))

			row.DoClick = function()
				net.Start("ixDoorRestore")
					net.WriteUInt(id, 32)
				net.SendToServer()

				--[[
					Rebuilt on a delay: the answer comes back in the next sync,
					and redrawing before it arrives would leave the row there
					and read as the button not working.
				]]
				timer.Simple(0.5, function()
					if (IsValid(container)) then Refresh() end
				end)
			end

			tall = tall + 24
		end

		if (shown == 0) then
			local label = container:Add("DLabel")

			label:Dock(TOP)
			label:SetTall(20)
			label:SetText("  Nothing has been deleted on this map.")
			label:SetDark(true)

			tall = 22
		end

		container:SetTall(math.max(tall, 22))
	end

	panel:Button("Refresh the list").DoClick = Refresh

	Refresh()

	return Refresh
end

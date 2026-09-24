--[[
	Zones - what they look like.

	    the banner      the name of the place, across the top, on entry
	    the second line the faction holding it, smaller, under the name
	    the hint        a chat line saying a place can be claimed, and how
	    the bar         how far through claiming or capturing you are
	    the countdown   how long you have left in an out-of-bounds box
	    the fog         radiation, lying on the ground
	    the wireframes  every zone, while somebody is holding the zone tool

	THE BANNER IS WORKED OUT HERE, NOT SENT.

	`ix.area.stored` is a complete copy on the client - the area plugin
	compresses the whole table to everybody on join - so "which place am I in"
	is a question this end can answer for itself, once a quarter of a second,
	with no message and no server tick behind it.

	That also fixes what Helix's own answer gets wrong. `PLUGIN:AreaThink`
	keeps ONE area per player, `overlappingBoxes[1]`, chosen by whatever order
	the hash table iterated - so a shop inside a town is the shop or the town
	depending on the weather. Here the SMALLEST box containing you wins, which
	is what nesting is for, and radiation and out-of-bounds boxes are not
	places at all so they never take the name away from one.

	NOTHING IS DRAWN WHILE YOU ARE DEAD. Every piece below is a fact about
	where you are standing, and a corpse is not standing anywhere - a countdown
	still ticking over a death screen was exactly the fault that made this rule
	explicit.
]]

if (not CLIENT) then return end

--[[
	`libs/` is included ALPHABETICALLY, so this file runs before `sh_zones.lua`
	and `ix.zones` does not exist yet. Every function below is only CALLED long
	after everything has loaded, but assigning into a nil table is a file-scope
	error - which takes the whole file down and takes the banner with it.
]]
ix.zones = ix.zones or {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--------------------------------------------------------------------------------
-- Which place am I in
--------------------------------------------------------------------------------

local banner
local currentID
local nextCheck = 0

--- `[zone id] = when we may mention it in chat again`.
local hinted = {}

--- How long the banner stays up, and how long it takes to arrive and leave.
local HOLD = 5
local FADE = 0.6

--- A quiet spell before the same place offers itself again.
local HINT_AGAIN = 300

--[[
	Say in CHAT that a place is going spare, not with a notification.

	A notification is the same channel as "you are out of ammo" and disappears
	the same way; a chat line stays in the log, can be scrolled back to, and is
	where somebody would look for the name of a command.

	Only for a claimable area with nobody on it, and only once every few
	minutes per place - walking along the edge of one would otherwise print a
	line every time you crossed the boundary.
]]
local function Hint(id, area)
	local zoneType = ix.zones.TypeOf(area)

	if (not zoneType or not zoneType.claimable) then return end
	if (ix.zones.Owner(area)) then return end
	if ((hinted[id] or 0) > RealTime()) then return end

	hinted[id] = RealTime() + HINT_AGAIN

	chat.AddText(Color(255, 200, 100), "[Area] ", Color(220, 220, 220),
		"Nobody holds ", Color(255, 200, 100), id, Color(220, 220, 220),
		". A faction lead can take it with ", Color(255, 255, 255),
		"/claimarea", Color(220, 220, 220), ".")
end

local function Check()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter()) then
		currentID = nil

		return
	end

	local id, area = ix.zones.Displayed(client:GetPos() + client:OBBCenter())

	if (id == currentID) then return end

	currentID = id

	if (not id) then return end

	local owner = ix.zones.Owner(area)

	banner = {
		text = id,
		holder = owner and owner.name or nil,
		color = ix.zones.Color(area),
		time = RealTime()
	}

	Hint(id, area)
end

hook.Add("Think", "ixZones", function()
	if (RealTime() < nextCheck) then return end

	nextCheck = RealTime() + 0.25

	Check()
end)

--- The area you are in, for anything else that wants to ask.
function ix.zones.Current()
	return currentID, currentID and ix.zones.Get(currentID)
end

--[[
	Helix's chatbox notice, off.

	Returning false here is what `PLUGIN:OnAreaChanged` checks before adding an
	entry to its panel, so this is the plugin's own way of being told not to -
	no method is replaced and nothing is removed.
]]
hook.Add("ShouldDisplayArea", "ixZones", function()
	return false
end)

--------------------------------------------------------------------------------
-- Out of bounds, and claiming
--------------------------------------------------------------------------------

local oobLeft, oobTotal = -1, 0
local capture

net.Receive("ixZoneWarn", function()
	oobLeft = net.ReadFloat()
	oobTotal = net.ReadFloat()
end)

net.Receive("ixZoneCapture", function()
	if (not net.ReadBool()) then
		capture = nil

		return
	end

	capture = {id = net.ReadString(), progress = net.ReadFloat()}
end)

--[[
	Where the zone tool's first corner is, sent by the server.

	The tool runs on the server only - see `ix.zones.SendPending` - so this is
	how the preview box knows where to start from.
]]
net.Receive("ixZonePending", function()
	local has = net.ReadBool()
	local position = net.ReadVector()

	ix.zones.pending = has and position or nil
end)

--[[
	Counted down between messages rather than waiting for the next one.

	The server sends one a second. A number that only moves once a second reads
	as broken, and worse, reads as though you have longer than you do.
]]
hook.Add("Think", "ixZonesOOB", function()
	if (oobLeft > 0) then
		oobLeft = math.max(oobLeft - FrameTime(), 0)
	end
end)

--------------------------------------------------------------------------------
-- Radiation, seen
--------------------------------------------------------------------------------

--[[
	PHOENIX'S FOG, not a swarm of motes.

	Their `nut.area:createRadiationFog` is worth copying exactly, because what
	it produces does not look like particles at all:

	    particle/smokesprites_0007..0016   large soft smoke sprites
	    SetVelocity(Vector(0, 0, -100000)) with SetCollide(true)
	    SetLifeTime(0), SetDieTime(1e15)
	    SetColor(0, 100, 0), alpha 120, size 100
	    density = surface area / 10000

	They are spawned anywhere in the box and immediately dropped through the
	air with no resistance until they hit the floor, where collision stops
	them - so the fog LAYS ON THE GROUND following its contours, rather than
	hanging in a cube. Then it never dies; it is a static bank of green smoke
	that is removed by hand.

	My first version was drifting motes, which is a different effect entirely:
	small, sparse, and obviously spawned rather than there.

	The one thing not copied is Phoenix's trigger: they hang the fog on the
	area ENTITY and build it from `NotifyShouldTransmit`, which is the engine
	telling them the box entered the PVS. These zones are table entries with no
	entity, so distance does the same job.
]]
local emitter
local fog = {}
local nextSweep = 0

--[[
	How far away a zone still gets its fog built.

	THE WHOLE MAP, effectively - 16384 is the edge of a Source level, so every
	radiation zone has its fog from the moment the client knows about it rather
	than building it as somebody walks up. Fog that appears when you arrive is
	fog you can see appearing, and the point of it is to be visible from a
	distance so people know to go round.

	It is still a range and not "always" so that the sweep has something to
	answer, and so a server that wants to trade the frames back can lower it.
	The per-zone cap below is what actually bounds the cost.
]]
local RANGE = 16384

--[[
	Phoenix's own density, with a ceiling.

	`surfaceArea / 10000` is one sprite per hundred-unit square, which is right
	for a town-sized zone and would be forty thousand sprites for a box drawn
	across the whole map. The cap is not in their version because their zones
	were placed by hand at a sensible size; ours are drawn with a tool and a
	slip of the mouse should not be a frame rate.
]]
local cvarDensity = CreateClientConVar("fo_radfog_density", "1", true, false,
	"How thick radiation fog is. 0 turns it off.")

local MAX_PARTICLES = 700

local function RemoveFog(id)
	if (not fog[id]) then return end

	--[[
		Their removal, exactly: a die time in the past and a lifetime far in
		the future. `Particle` has no "remove" - this is how you tell one that
		it is already over.
	]]
	for _, particle in ipairs(fog[id]) do
		particle:SetDieTime(0)
		particle:SetLifeTime(100000000000000000000)
	end

	fog[id] = nil
end

local function BuildFog(id, area)
	RemoveFog(id)

	if (not emitter) then emitter = ParticleEmitter(vector_origin) end
	if (not emitter) then return end

	local mins, maxs = area.startPosition, area.endPosition
	local size = maxs - mins
	--- Named `footprint`, not `surface` - that is the drawing library's name.
	local footprint = math.abs(size.x) * math.abs(size.y)
	local density = math.Clamp(
		math.floor((footprint / 10000) * cvarDensity:GetFloat()), 0,
		MAX_PARTICLES)

	if (density < 1) then return end

	local particles = {}

	for _ = 1, density do
		local position = Vector(math.Rand(mins.x, maxs.x),
			math.Rand(mins.y, maxs.y), math.Rand(mins.z, maxs.z))

		local particle = emitter:Add(string.format(
			"particle/smokesprites_00%02d", math.random(7, 16)), position)

		if (not particle) then continue end

		particle:SetAirResistance(0)

		--- Dropped hard so it reaches the floor on the first tick.
		particle:SetVelocity(Vector(0, 0, -100000))
		particle:SetLifeTime(0)
		particle:SetDieTime(1000000000000000)
		particle:SetColor(0, 100, 0)
		particle:SetStartAlpha(120)
		particle:SetEndAlpha(120)
		particle:SetCollide(true)
		particle:SetStartSize(100)
		particle:SetEndSize(100)
		particle:SetRoll(math.Rand(0, 360))
		particle:SetRollDelta(0.1 * math.Rand(-40, 40))

		particles[#particles + 1] = particle
	end

	fog[id] = particles
end

--[[
	Which zones should have fog right now.

	Swept twice a second rather than every frame: building a bank of fog is
	hundreds of allocations and the answer only changes when somebody walks a
	few hundred metres.
]]
local function Radiation()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end
	if (RealTime() < nextSweep) then return end

	nextSweep = RealTime() + 0.5

	if (cvarDensity:GetFloat() <= 0) then
		for id in pairs(fog) do RemoveFog(id) end

		return
	end

	local position = client:GetPos()
	local wanted = {}

	for id, area in pairs(ix.area.stored or {}) do
		if (area.type ~= "radiation") then continue end
		if ((tonumber(ix.zones.Properties(area).radiation) or 0) <= 0) then
			continue
		end

		local centre = (area.startPosition + area.endPosition) * 0.5
		local reach = (area.endPosition - area.startPosition):Length() * 0.5

		if (position:Distance(centre) > RANGE + reach) then continue end

		wanted[id] = area

		if (not fog[id]) then BuildFog(id, area) end
	end

	for id in pairs(fog) do
		if (not wanted[id]) then RemoveFog(id) end
	end
end

hook.Add("Think", "ixZonesRadiation", Radiation)

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

--- One bar, used by both kinds of capture. Nothing else up here draws bars.
local function DrawBar(y, fraction, colour, label)
	local width = Scaled(360)
	local height = Scaled(16)
	local x = ScrW() * 0.5 - width * 0.5

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(colour)
	surface.DrawRect(x + 1, y + 1, (width - 2) * math.Clamp(fraction, 0, 1),
		height - 2)

	surface.SetDrawColor(0, 0, 0, 120)
	surface.DrawOutlinedRect(x, y, width, height)

	draw.SimpleText(label, "ixZoneNote", ScrW() * 0.5, y - Scaled(12),
		colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawBanner()
	if (not banner) then return end

	local age = RealTime() - banner.time

	if (age > HOLD) then
		banner = nil

		return
	end

	--- In over FADE, out over FADE, solid in between.
	local alpha = 255

	if (age < FADE) then
		alpha = (age / FADE) * 255
	elseif (age > HOLD - FADE) then
		alpha = ((HOLD - age) / FADE) * 255
	end

	local x = ScrW() * 0.5
	local y = ScrH() * 0.12

	--[[
		Drawn twice: a black copy offset by one, then the text. A shadow rather
		than an outline because the banner sits over the sky as often as not,
		and an outline on a light background reads as a smudge.
	]]
	draw.SimpleText(banner.text, "ixZoneName", x + 2, y + 2,
		Color(0, 0, 0, alpha * 0.7), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(banner.text, "ixZoneName", x, y,
		ColorAlpha(banner.color, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if (not banner.holder) then return end

	--[[
		The holder on its own line, smaller.

		Not appended to the name: the name is the place and the faction is who
		is standing on it this month, and one line reading "Springvale [BoS]"
		makes the second half look like part of the name of the town.
	]]
	local below = y + Scaled(26)

	draw.SimpleText(banner.holder, "ixZoneNote", x + 1, below + 1,
		Color(0, 0, 0, alpha * 0.7), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(banner.holder, "ixZoneNote", x, below,
		ColorAlpha(banner.color, alpha * 0.85), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

local function DrawOutOfBounds()
	if (oobLeft < 0) then return end

	local x = ScrW() * 0.5
	local y = ScrH() * 0.24

	--- Pulses faster as it runs out, which is the whole point of showing it.
	local urgency = oobTotal > 0 and (1 - oobLeft / oobTotal) or 1
	local pulse = 0.6 + 0.4 * math.abs(math.sin(RealTime() * (3 + urgency * 9)))

	local colour = Color(255, 60 + 60 * (1 - urgency), 60, 255 * pulse)

	draw.SimpleText("OUT OF BOUNDS", "ixZoneName", x + 2, y + 2,
		Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText("OUT OF BOUNDS", "ixZoneName", x, y, colour,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(string.format("Turn back - %.1f seconds", oobLeft),
		"ixZoneNote", x, y + ScrH() * 0.035, Color(255, 220, 220, 230),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

--[[
	The capture point you are standing in, worked out here.

	The entities are networked, so the client can run the same box test the
	server runs and needs no message of its own - which also means the bar is
	right on the frame you cross the line rather than up to half a second
	later.
]]
local function CapturePoint()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local position = client:GetPos() + client:OBBCenter()

	for _, entity in ipairs(ents.FindByClass("ix_captureflag")) do
		if (IsValid(entity) and entity.IsInside and entity:IsInside(position))
		then
			return entity
		end
	end
end

local function DrawCapture()
	local y = ScrH() * 0.78

	if (capture) then
		DrawBar(y, capture.progress, Color(255, 200, 100),
			"Claiming " .. capture.id)

		y = y + Scaled(44)
	end

	local point = CapturePoint()

	if (not IsValid(point)) then return end

	if (point:GetContested()) then
		local pulse = 0.5 + 0.5 * math.abs(math.sin(RealTime() * 6))

		DrawBar(y, 1, Color(220, 70, 60, 255 * pulse),
			point:GetPointName() .. " - CONTESTED")

		return
	end

	local holder = point:GetHolderName()

	DrawBar(y, point:GetProgress(), point:HolderColour(),
		string.format("%s - %s", point:GetPointName(),
			holder ~= "" and holder or "unclaimed"))
end

hook.Add("HUDPaint", "ixZones", function()
	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		return
	end

	local client = LocalPlayer()

	--- See the header: none of this is true of a corpse.
	if (not IsValid(client) or not client:Alive()) then return end

	if (hook.Run("ShouldDrawZoneHUD") == false) then return end

	DrawBanner()
	DrawOutOfBounds()
	DrawCapture()
end)

--------------------------------------------------------------------------------
-- The wireframes, while the tool is out
--------------------------------------------------------------------------------

--[[
	Every zone drawn as a box, but ONLY while the zone tool is held.

	Zones are meant to be invisible - a town is a name, not a glowing crate -
	so this is not a permanent overlay.
]]
function ix.zones.ShouldDraw()
	local client = LocalPlayer()

	if (not IsValid(client)) then return false end

	local weapon = client:GetActiveWeapon()

	if (not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool") then
		return false
	end

	--- The editor, and the music tool, which needs to see them as much.
	local mode = client:GetInfo("gmod_toolmode")

	return mode == "fo_zone" or mode == "fo_zonemusic"
end

hook.Add("PostDrawTranslucentRenderables", "ixZones", function(depth, skybox)
	if (skybox or not ix.zones.ShouldDraw()) then return end
	if (not ix.area or not ix.area.stored) then return end

	for id, area in pairs(ix.area.stored) do
		local center = LerpVector(0.5, area.startPosition, area.endPosition)
		local min = WorldToLocal(area.startPosition, angle_zero, center,
			angle_zero)
		local max = WorldToLocal(area.endPosition, angle_zero, center,
			angle_zero)

		local colour = ix.zones.Color(area)

		render.DrawWireframeBox(center, angle_zero, min, max,
			ColorAlpha(colour, 255), true)

		cam.Start2D()
			local screen = center:ToScreen()
			local zoneType = ix.zones.TypeOf(area)

			draw.SimpleText(ix.zones.DisplayName(id, area), "ixZoneNote",
				screen.x, screen.y, colour, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(zoneType and zoneType.name or area.type,
				"ixZoneNote", screen.x, screen.y + 16,
				ColorAlpha(colour, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End2D()
	end

	--[[
		The box being drawn right now, from the corner already placed to
		wherever the tool is pointing. Pulsed white so it cannot be mistaken
		for one that already exists.
	]]
	local pending = ix.zones.pending

	if (not pending) then return end

	local hit = LocalPlayer():GetEyeTrace().HitPos
	local heightVar = GetConVar("fo_zone_height")
	local height = math.max(heightVar and heightVar:GetFloat() or 256, 8)

	local first = Vector(pending.x, pending.y, math.min(pending.z, hit.z))
	local second = Vector(hit.x, hit.y, math.max(pending.z, hit.z) + height)

	local center = LerpVector(0.5, first, second)
	local min = WorldToLocal(first, angle_zero, center, angle_zero)
	local max = WorldToLocal(second, angle_zero, center, angle_zero)

	render.DrawWireframeBox(center, angle_zero, min, max,
		Color(255, 255, 255, 40 + (1 + math.sin(SysTime() * 6)) * 100), true)
end)

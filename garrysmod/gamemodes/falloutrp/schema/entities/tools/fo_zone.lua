--[[
	The zone tool.

	    left click    place a corner, then place the other one
	    right click   delete the zone you are standing in
	    reload        forget the corner you placed

	The type is a dropdown in the tool's own panel, so the one tool makes named
	areas, claimable areas, radiation clouds and out-of-bounds boxes.

	EVERYTHING HAPPENS ON THE SERVER. `TOOL:LeftClick` returns `true` on the
	client and does nothing else, which is the sandbox idiom and not laziness:
	the client runs a PREDICTED click that can be replayed several times for one
	press, so a corner stored there would sometimes be the second click's. The
	preview box the client draws is told to it in one message - see
	`ix.zones.SendPending`.

	CONVARS ARE CREATED HERE, NOT DECLARED.

	Helix registers tools with

	    TOOL = ix.meta.tool:Create()
	    TOOL.Mode = className
	    TOOL:CreateConVars()      -- <- before the file is included
	    ix.util.Include(...)

	so `TOOL.ClientConVar` is still empty when `CreateConVars` reads it, and
	anything declared that way is never created. Sandbox's own loader calls
	`CreateConVars` AFTER the include, which is why every tool ever written
	assumes the declaration works. `CreateClientConVar` here does what the
	declaration was going to.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_zone.name"

--- The height a box is given above its two corners, in units.
local DEFAULT_HEIGHT = 256

TOOL.ClientConVar = {
	name = "New Area",
	type = "area",
	height = tostring(DEFAULT_HEIGHT),
	radiation = "3",
	radinterval = "1",
	killtime = "5",
	capturetime = "30",
	music = "",

	--[[
		The colour, as three numbers rather than one.

		A convar is a string and `ix.type.color` is a Helix concept the tool
		panel knows nothing about, so a colour has to be three sliders. Helix's
		own `AddControl("Color")` writes exactly this shape.
	]]
	r = "255",
	g = "200",
	b = "100"
}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_zone.name", "Zone Editor")
	language.Add("tool.fo_zone.desc", "Areas, claims, radiation, out of bounds.")
	language.Add("tool.fo_zone.0",
		"Left click to place a corner. Right click to delete the zone you "
		.. "are in. Reload to start over.")
end

--------------------------------------------------------------------------------
-- Making one
--------------------------------------------------------------------------------

--[[
	Everything the tool needs from the person holding it, read once.

	`GetClientInfo` reads the owner's convar from the server, which is what
	makes a userinfo convar the right place to keep tool settings - no message
	of our own, and the value is whatever the panel currently says.
]]
function TOOL:Settings()
	return {
		name = string.Trim(self:GetClientInfo("name") or ""),
		type = self:GetClientInfo("type") or "area",
		height = math.Clamp(tonumber(self:GetClientInfo("height"))
			or DEFAULT_HEIGHT, 8, 8192),
		radiation = math.Clamp(tonumber(self:GetClientInfo("radiation")) or 0,
			0, 25),
		radInterval = math.Clamp(
			tonumber(self:GetClientInfo("radinterval")) or 1, 1, 120),
		killTime = math.Clamp(tonumber(self:GetClientInfo("killtime")) or 5,
			1, 120),
		captureTime = math.Clamp(
			tonumber(self:GetClientInfo("capturetime")) or 30, 1, 900),
		music = self:GetClientInfo("music") or "",
		color = Color(
			math.Clamp(tonumber(self:GetClientInfo("r")) or 255, 0, 255),
			math.Clamp(tonumber(self:GetClientInfo("g")) or 200, 0, 255),
			math.Clamp(tonumber(self:GetClientInfo("b")) or 100, 0, 255))
	}
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "zone.edit")) then
		client:Notify("You cannot edit zones.")

		return false
	end

	return true
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()

	if (not self.zoneStart) then
		self.zoneStart = trace.HitPos

		ix.zones.SendPending(client, self.zoneStart)

		client:Notify("Corner placed. Click the opposite corner.")

		return true
	end

	local settings = self:Settings()

	if (settings.name == "") then
		client:Notify("Give the zone a name in the tool panel first.")

		return false
	end

	if (ix.zones.Get(settings.name)) then
		client:Notify("There is already a zone called '" .. settings.name
			.. "'.")

		return false
	end

	if (not ix.zones.byID[settings.type]) then
		client:Notify("'" .. settings.type .. "' is not a zone type.")

		return false
	end

	if (settings.music ~= "" and not ix.zonemusic.Resolve(settings.music)) then
		client:Notify("That music is not something the server has.")

		return false
	end

	--[[
		THE BOX IS GROWN UPWARDS FROM THE LOWER CLICK.

		Two points on a floor describe a rectangle with no height, and a zone
		with no height contains nobody. The height is added above whichever
		corner was higher, so clicking across a slope still produces a box that
		reaches over the whole of it.
	]]
	local first, second = self.zoneStart, trace.HitPos

	local low = Vector(first.x, first.y, math.min(first.z, second.z))
	local high = Vector(second.x, second.y,
		math.max(first.z, second.z) + settings.height)

	ix.zones.Create(settings.name, settings.type, low, high, {
		radiation = settings.radiation,
		radInterval = settings.radInterval,
		killTime = settings.killTime,
		captureTime = settings.captureTime,
		color = settings.color,
		music = settings.music
	})

	self.zoneStart = nil

	ix.zones.SendPending(client, nil)

	client:Notify(string.format("Made %s '%s'.",
		ix.zones.byID[settings.type].name, settings.name))

	ix.log.Add(client, "zoneCreate", settings.name, settings.type)

	return true
end

--------------------------------------------------------------------------------
-- Deleting one
--------------------------------------------------------------------------------

--[[
	Right click deletes the zone you are STANDING IN, not the one you are
	pointing at.

	A zone has no surface to point at - it is a volume, and the thing under the
	crosshair is the world behind it. Standing in it is the only unambiguous
	way to say which one you mean, and it is how you found it in the first
	place.

	The smallest one wins, for the same reason the banner picks the smallest:
	inside a shop inside a town, "this one" means the shop.
]]
function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local position = client:GetPos() + client:OBBCenter()

	local best, bestVolume

	for _, entry in ipairs(ix.zones.At(position)) do
		local volume = ix.zones.Volume(entry.area)

		if (not bestVolume or volume < bestVolume) then
			best, bestVolume = entry.id, volume
		end
	end

	if (not best) then
		client:Notify("You are not standing in a zone.")

		return false
	end

	ix.zones.Remove(best)

	client:Notify("Deleted '" .. best .. "'.")

	ix.log.Add(client, "zoneRemove", best)

	return true
end

function TOOL:Reload(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not self.zoneStart) then return false end

	self.zoneStart = nil

	ix.zones.SendPending(client, nil)

	client:Notify("Corner forgotten.")

	return true
end

--[[
	Putting the tool away drops the corner too.

	Otherwise a corner placed yesterday is still waiting, and the next left
	click makes a box across half the map from a position nobody remembers
	choosing.
]]
function TOOL:Holster()
	if (CLIENT) then return end
	if (not self.zoneStart) then return end

	self.zoneStart = nil

	ix.zones.SendPending(self:GetOwner(), nil)
end

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Left click twice for two corners. Right click inside a "
			.. "zone to delete it."
	})

	panel:TextEntry("Name", "fo_zone_name")

	local types = {}

	for _, zoneType in ipairs(ix.zones.types) do
		types[zoneType.name] = {fo_zone_type = zoneType.id}
	end

	panel:AddControl("ComboBox", {
		Label = "Type",
		MenuButton = 0,
		Options = types
	})

	panel:NumSlider("Height", "fo_zone_height", 8, 4096, 0)

	panel:AddControl("Color", {
		Label = "Colour",
		Red = "fo_zone_r",
		Green = "fo_zone_g",
		Blue = "fo_zone_b",
		ShowAlpha = 0,
		ShowHSV = 1,
		ShowRGB = 1,
		Multiplier = 255
	})

	--- What it plays; the Zone Music tool changes it afterwards.
	local music = {}

	for _, option in ipairs(ix.zonemusic.Options()) do
		music[option.name] = {fo_zone_music = option.value}
	end

	panel:AddControl("ComboBox", {
		Label = "Music",
		MenuButton = 0,
		Options = music
	})

	panel:Help("Radiation Zone")
	panel:NumSlider("Rads each time", "fo_zone_radiation", 0, 25, 0)
	panel:NumSlider("Seconds between doses", "fo_zone_radinterval", 1, 120, 0)

	panel:Help("Out of Bounds")
	panel:NumSlider("Seconds before it kills", "fo_zone_killtime", 1, 120, 0)

	panel:Help("Claimable Area")
	panel:NumSlider("Seconds to claim", "fo_zone_capturetime", 1, 900, 0)

	panel:Help("A claimable area is taken with /claimarea - you have to stand "
		.. "in it for the whole time. A claimed one shows its faction under "
		.. "the name in the faction\'s own colour, so the colour above is "
		.. "what an unclaimed or ordinary area uses.")
end

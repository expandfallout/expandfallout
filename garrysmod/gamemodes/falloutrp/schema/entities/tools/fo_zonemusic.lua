--[[
	The zone music tool.

	    left click    the zone you point at (or stand in) plays the track
	                  picked in the panel
	    right click   that zone plays nothing
	    reload        hear the picked track for twenty seconds, wherever
	                  you are

	The pick is a combo box of every station and every song the radio
	knows (`sh_radio.lua`), and "None". What a zone plays is its `music`
	property; `sh_zonemusic.lua` says what the string means and
	`cl_zonemusic.lua` plays it.

	THE CLICKS HAPPEN ON THE SERVER, like every tool here - the client's
	click is predicted and can fire more than once for one press. The
	reload is the exception, because a preview is the client's own ears
	and nothing else's. See `fo_zone.lua` for why the convars are created
	by hand.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_zonemusic.name"

TOOL.ClientConVar = {
	track = ""
}

TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_zonemusic.name", "Zone Music")
	language.Add("tool.fo_zonemusic.desc",
		"What plays in a zone.")
	language.Add("tool.fo_zonemusic.0",
		"Left click a zone to set its music. Right click to silence it. "
		.. "Reload to hear the pick.")
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

--- The pick, checked against what the server actually has.
function TOOL:Track()
	local value = self:GetClientInfo("track") or ""

	if (value ~= "" and not ix.zonemusic.Resolve(value)) then return nil end

	return value
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local value = self:Track()

	if (not value) then
		client:Notify("That track is not one the server has.")

		return false
	end

	local id = ix.zonemusic.Target(client, trace.HitPos)

	if (not id) then
		client:Notify("Point at a zone, or stand in one.")

		return false
	end

	ix.zones.SetProperty(id, "music", value)

	local said = ix.zonemusic.Describe(value)

	client:Notify(string.format("'%s' now plays %s.", id, said))
	ix.log.Add(client, "zoneMusic", id, said)

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local id = ix.zonemusic.Target(client, trace.HitPos)

	if (not id) then
		client:Notify("Point at a zone, or stand in one.")

		return false
	end

	ix.zones.SetProperty(id, "music", "")

	client:Notify(string.format("'%s' now plays nothing.", id))
	ix.log.Add(client, "zoneMusic", id, "nothing")

	return true
end

--- The preview is the holder's ears only, so this half runs on the client.
function TOOL:Reload(trace)
	if (CLIENT and ix.zonemusic.Preview) then
		ix.zonemusic.Preview(self:GetClientInfo("track") or "", 20)
	end

	return true
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Left click the floor of a zone to give it music. Right "
			.. "click to take it away. Reload plays your pick for twenty "
			.. "seconds so you can hear it first."
	})

	local options = {}

	for _, option in ipairs(ix.zonemusic.Options()) do
		options[option.name] = {fo_zonemusic_track = option.value}
	end

	panel:AddControl("ComboBox", {
		Label = "Track",
		MenuButton = 0,
		Options = options
	})

	panel:Help("A station shuffles its songs; a song repeats. The smallest "
		.. "zone around a player that has music is the one they hear, so a "
		.. "shop inside a town with no music of its own keeps the town's. "
		.. "Players hear it under the radio and the menu music, at their own "
		.. "fo_zone_music_volume.")
end

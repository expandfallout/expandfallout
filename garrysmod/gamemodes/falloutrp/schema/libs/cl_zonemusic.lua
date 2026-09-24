--[[
	The zone's music, played.

	One channel for what is playing and a list of channels on their way
	out: entering a zone starts its music from silence and brings it up
	over a second, leaving one takes a second and a half to fade what was
	playing, and walking from one zone straight into another does both at
	once. A station shuffles its songs; a single song repeats.

	IT WAITS ITS TURN. Nothing while the character menu is up (that has
	music of its own), nothing while the radio is tuned (the player chose
	that), and off altogether with `fo_zone_music 0`. The volume is
	`fo_zone_music_volume`, quiet by default - this is a background, not a
	jukebox.

	`ix.zonemusic` is declared here too: `cl_` loads before `sh_` (gotcha
	26), and the functions in `sh_zonemusic.lua` are only ever called at
	run time.
]]

if (not CLIENT) then return end

ix.zonemusic = ix.zonemusic or {}
ix.zones = ix.zones or {}

local enabled = CreateClientConVar("fo_zone_music", "1", true, false,
	"Play the music a zone is set to.")
local volume = CreateClientConVar("fo_zone_music_volume", "0.3", true, false,
	"Zone music volume, 0 to 1.")

ix.zonemusic.channel = ix.zonemusic.channel or nil
ix.zonemusic.current = ix.zonemusic.current or ""
ix.zonemusic.zone = ix.zonemusic.zone or nil
ix.zonemusic.song = ix.zonemusic.song or nil
ix.zonemusic.level = 0
ix.zonemusic.preview = nil

local fading = {}
local nextCheck = 0

--- The playing channel joins the fade-out list.
local function Release()
	local channel = ix.zonemusic.channel

	if (IsValid(channel)) then
		fading[#fading + 1] = {channel = channel, level = ix.zonemusic.level}
	end

	ix.zonemusic.channel = nil
	ix.zonemusic.song = nil
	ix.zonemusic.level = 0
end

--- Start the next file for the current value, from silence.
local function Play()
	local kind, what = ix.zonemusic.Resolve(ix.zonemusic.current)

	if (not kind) then
		Release()

		return
	end

	local song

	if (kind == "station") then
		local songs = what.songs or {}

		if (#songs == 0) then
			Release()

			return
		end

		if (#songs > 1) then
			repeat
				song = songs[math.random(#songs)]
			until not ix.zonemusic.song or song.path ~= ix.zonemusic.song.path
		else
			song = songs[1]
		end
	else
		song = what
	end

	Release()

	ix.zonemusic.song = song

	local wanted, value = song.path, ix.zonemusic.current

	sound.PlayFile("sound/" .. song.path, "noplay", function(channel)
		--- The zone changed again before this loaded.
		if (not IsValid(channel) or ix.zonemusic.current ~= value
		or not ix.zonemusic.song or ix.zonemusic.song.path ~= wanted) then
			if (IsValid(channel)) then channel:Stop() end

			return
		end

		channel:SetVolume(0)
		channel:Play()

		ix.zonemusic.channel = channel
		ix.zonemusic.level = 0
	end)
end

function ix.zonemusic.Switch(id, value)
	ix.zonemusic.zone = id
	ix.zonemusic.current = value or ""

	Release()

	if (ix.zonemusic.current ~= "") then Play() end
end

--- Hear a track for a while, wherever you are; the tool's reload.
function ix.zonemusic.Preview(value, seconds)
	ix.zonemusic.preview = {value = value or "",
		until_ = RealTime() + (seconds or 20)}
	nextCheck = 0
end

--- What should be playing: the preview if one is on, else the zone's.
local function Wanted()
	local preview = ix.zonemusic.preview

	if (preview) then
		if (preview.until_ > RealTime()) then return "preview", preview.value end

		ix.zonemusic.preview = nil
	end

	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter()) then return nil, "" end

	return ix.zonemusic.At(client:GetPos() + client:OBBCenter())
end

--- The level it should sit at right now.
local function Target()
	if (not enabled:GetBool()) then return 0 end
	if (IsValid(ix.gui.characterMenu)) then return 0 end
	if (ix.radio and IsValid(ix.radio.channel)) then return 0 end

	return math.Clamp(volume:GetFloat(), 0, 1)
end

hook.Add("Think", "ixZoneMusic", function()
	if (RealTime() >= nextCheck) then
		nextCheck = RealTime() + 0.5

		local id, value = Wanted()

		if ((value or "") ~= ix.zonemusic.current) then
			ix.zonemusic.Switch(id, value)
		end
	end

	--- Whatever is on its way out.
	for index = #fading, 1, -1 do
		local out = fading[index]

		if (not IsValid(out.channel)) then
			table.remove(fading, index)
		else
			out.level = math.Approach(out.level, 0, FrameTime() / 1.5)
			out.channel:SetVolume(out.level)

			if (out.level <= 0) then
				out.channel:Stop()
				table.remove(fading, index)
			end
		end
	end

	local channel = ix.zonemusic.channel

	if (not IsValid(channel)) then return end

	ix.zonemusic.level = math.Approach(ix.zonemusic.level, Target(), FrameTime())
	channel:SetVolume(ix.zonemusic.level)

	if (channel:GetState() == GMOD_CHANNEL_STOPPED) then Play() end
end)

--------------------------------------------------------------------------------
-- What the tool shows
--------------------------------------------------------------------------------

--[[
	With the Zone Music tool out: the zone under the crosshair and what it
	plays, drawn by the crosshair, and what is playing for you now. The
	zones' wireframes come from `cl_zones.lua`, which draws them for this
	tool as well as for the editor.
]]
local function ToolOut()
	local client = LocalPlayer()

	if (not IsValid(client)) then return false end

	local weapon = client:GetActiveWeapon()

	if (not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool") then
		return false
	end

	return client:GetInfo("gmod_toolmode") == "fo_zonemusic"
end

hook.Add("HUDPaint", "ixZoneMusicTool", function()
	if (not ToolOut()) then return end

	local client = LocalPlayer()
	local trace = client:GetEyeTrace()
	local id = ix.zonemusic.Target(client, trace.HitPos)
	local x, y = ScrW() / 2, ScrH() / 2 + 40

	local lines = {}

	if (id) then
		local area = ix.zones.Get(id)
		local value = area and area.properties and area.properties.music or ""

		lines[1] = {id, Color(255, 255, 255)}
		lines[2] = {"plays " .. ix.zonemusic.Describe(value), Color(200, 200, 190)}
	else
		lines[1] = {"no zone here", Color(200, 120, 120)}
	end

	if (ix.zonemusic.song) then
		lines[#lines + 1] = {"you hear: " .. (ix.zonemusic.song.name or "?"),
			Color(160, 200, 160)}
	end

	for index, line in ipairs(lines) do
		draw.SimpleTextOutlined(line[1], "DermaDefaultBold", x,
			y + (index - 1) * 18, line[2], TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP,
			1, Color(0, 0, 0, 200))
	end
end)

concommand.Add("fo_zone_music_preview", function(_, _, args)
	ix.zonemusic.Preview(args[1] or "", tonumber(args[2]))
end)

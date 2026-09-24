--[[
	The radio: a station from `sh_radio.lua`, playing in the background.

	Tuned from the F1 menu's RADIO tab (`derma/cl_radio.lua`), remembered in
	a convar so it is on again next session, and quiet while the character
	menu is up, because that has music of its own. Everything plays through
	one channel; a song that ends picks the next at random.
]]

if (not CLIENT) then return end

ix.radio = ix.radio or {}

local station = CreateClientConVar("fo_radio_station", "", true, false,
	"The station the radio is tuned to; blank is off.")
local volume = CreateClientConVar("fo_radio_volume", "0.35", true, false,
	"Radio volume, 0 to 1.")

ix.radio.channel = ix.radio.channel or nil
ix.radio.current = ix.radio.current or nil
ix.radio.now = ix.radio.now or nil

local function Silence()
	if (IsValid(ix.radio.channel)) then ix.radio.channel:Stop() end

	ix.radio.channel = nil
	ix.radio.now = nil
end

--- The station tuned in, or nil.
function ix.radio.Station()
	return ix.radio.byID and ix.radio.byID[station:GetString()] or nil
end

function ix.radio.Volume()
	return volume:GetFloat()
end

function ix.radio.SetVolume(value)
	volume:SetFloat(math.Clamp(tonumber(value) or 0.35, 0, 1))

	if (IsValid(ix.radio.channel)) then
		ix.radio.channel:SetVolume(volume:GetFloat())
	end
end

--- The next song on the station, at random, never the one just played.
function ix.radio.Next()
	local tuned = ix.radio.Station()

	if (not tuned or #tuned.songs == 0) then
		Silence()

		return
	end

	local index

	if (#tuned.songs > 1) then
		repeat index = math.random(#tuned.songs)
		until not ix.radio.now or tuned.songs[index] ~= ix.radio.now
	else
		index = 1
	end

	local song = tuned.songs[index]

	Silence()

	ix.radio.now = song
	ix.radio.current = tuned.id

	local wanted = song.path

	sound.PlayFile("sound/" .. song.path, "noplay", function(channel)
		if (not IsValid(channel) or not ix.radio.now
		or ix.radio.now.path ~= wanted) then
			if (IsValid(channel)) then channel:Stop() end

			return
		end

		channel:SetVolume(IsValid(ix.gui.characterMenu) and 0 or volume:GetFloat())
		channel:Play()

		ix.radio.channel = channel

		hook.Run("RadioChanged")
	end)

	hook.Run("RadioChanged")
end

function ix.radio.Tune(id)
	if (not ix.radio.byID or not ix.radio.byID[id]) then return false end

	station:SetString(id)
	ix.radio.Next()

	return true
end

function ix.radio.Off()
	station:SetString("")
	Silence()
	ix.radio.current = nil

	hook.Run("RadioChanged")
end

hook.Add("Think", "ixRadio", function()
	local tuned = ix.radio.Station()

	--- Tuned last session, and nothing playing yet: pick it up.
	if (tuned and not IsValid(ix.radio.channel) and not ix.radio.now) then
		ix.radio.Next()

		return
	end

	local channel = ix.radio.channel

	if (not IsValid(channel)) then return end

	--- The character menu has its own music; the radio waits.
	channel:SetVolume(IsValid(ix.gui.characterMenu) and 0 or volume:GetFloat())

	if (channel:GetState() == GMOD_CHANNEL_STOPPED) then
		ix.radio.Next()
	end
end)

concommand.Add("fo_radio_next", function() ix.radio.Next() end)
concommand.Add("fo_radio_off", function() ix.radio.Off() end)

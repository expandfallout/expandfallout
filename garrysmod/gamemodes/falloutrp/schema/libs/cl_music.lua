--[[
	The main menu's music player.

	Helix's character menu plays one file - `ix.config.Get("music")`, which
	is Half-Life 2's second song - through `ixCharMenu:PlayMusic`. Phoenix
	replaced that with a player in the corner of their menu: a list of
	Fallout themes, play, pause, shuffle. This is that, on the menu Helix
	already draws: `PlayMusic` is replaced on the registered panel table, so
	every menu made from now on asks this instead, and the panel itself is
	`derma/cl_musicplayer.lua`, added when the menu is created.

	`ix.radio` IS DECLARED HERE TOO: `cl_` files load before `sh_` ones
	(gotcha 26); the themes list in `sh_radio.lua` is only read at run time.
]]

if (not CLIENT) then return end

ix.radio = ix.radio or {}
ix.music = ix.music or {}

local enabled = CreateClientConVar("fo_menu_music", "1", true, false,
	"Play music in the character menu.")
local shuffle = CreateClientConVar("fo_menu_shuffle", "1", true, false,
	"Pick the next menu song at random.")
local volume = CreateClientConVar("fo_menu_volume", "0.5", true, false,
	"Menu music volume, 0 to 1.")
local last = CreateClientConVar("fo_menu_track", "", true, false,
	"The last menu song played; picked up again next time.")

ix.music.channel = ix.music.channel or nil
ix.music.index = ix.music.index or 0
ix.music.paused = false

--[[
	THE THEMES AND THE SONGS. Phoenix's menu list had Sinatra and Marty
	Robbins in it alongside the title themes, so the whole radio catalogue
	is in here after the themes - every station's songs, once each, built
	the first time it is asked for.
]]
local playlist

function ix.music.Playlist()
	if (playlist) then return playlist end

	playlist = {}

	local seen = {}

	local function Take(song)
		if (song and song.path and not seen[song.path]) then
			seen[song.path] = true
			playlist[#playlist + 1] = song
		end
	end

	for _, song in ipairs(ix.radio.themes or {}) do Take(song) end

	for _, station in ipairs(ix.radio.stations or {}) do
		for _, song in ipairs(station.songs or {}) do Take(song) end
	end

	return playlist
end

function ix.music.Current()
	return ix.music.Playlist()[ix.music.index]
end

function ix.music.Stop()
	if (IsValid(ix.music.channel)) then ix.music.channel:Stop() end

	ix.music.channel = nil
	ix.music.paused = false

	hook.Run("MenuMusicChanged")
end

--- Play one song of the list by index; the channel is made fresh each time.
function ix.music.Play(index)
	local list = ix.music.Playlist()
	local song = list[index]

	if (not song) then return end

	ix.music.Stop()
	ix.music.index = index

	last:SetString(song.path)

	local wanted = song.path

	sound.PlayFile("sound/" .. song.path, "noplay", function(channel)
		--- Somebody skipped again before this loaded.
		if (not IsValid(channel) or last:GetString() ~= wanted) then
			if (IsValid(channel)) then channel:Stop() end

			return
		end

		channel:SetVolume(volume:GetFloat())
		channel:Play()

		ix.music.channel = channel

		hook.Run("MenuMusicChanged")
	end)
end

function ix.music.Next(step)
	local list = ix.music.Playlist()

	if (#list == 0) then return end

	local index

	if (shuffle:GetBool() and #list > 1 and not step) then
		repeat index = math.random(#list) until index ~= ix.music.index
	else
		index = ix.music.index + (step or 1)

		if (index > #list) then index = 1 end
		if (index < 1) then index = #list end
	end

	ix.music.Play(index)
end

function ix.music.Toggle()
	local channel = ix.music.channel

	if (not IsValid(channel)) then
		ix.music.Start()

		return
	end

	if (ix.music.paused) then
		channel:Play()
		ix.music.paused = false
	else
		channel:Pause()
		ix.music.paused = true
	end

	hook.Run("MenuMusicChanged")
end

--- Where the menu starts: the last song, or a random one.
function ix.music.Start()
	if (not enabled:GetBool()) then return end

	local list = ix.music.Playlist()

	if (#list == 0) then return end

	local wanted = last:GetString()

	for index, song in ipairs(list) do
		if (song.path == wanted) then
			ix.music.Play(index)

			return
		end
	end

	ix.music.Play(math.random(#list))
end

function ix.music.SetVolume(value)
	volume:SetFloat(math.Clamp(tonumber(value) or 0.5, 0, 1))

	if (IsValid(ix.music.channel)) then
		ix.music.channel:SetVolume(volume:GetFloat())
	end
end

--- When one finishes, the next; when the menu is gone, silence.
hook.Add("Think", "ixMenuMusic", function()
	local channel = ix.music.channel

	if (not IsValid(channel)) then return end

	if (not IsValid(ix.gui.characterMenu)) then
		ix.music.Stop()

		return
	end

	if (channel:GetState() == GMOD_CHANNEL_STOPPED and not ix.music.paused) then
		ix.music.Next()
	end
end)

--------------------------------------------------------------------------------
-- Onto Helix's menu
--------------------------------------------------------------------------------

local menu = vgui.GetControlTable("ixCharMenu")

if (menu) then
	--- Replaces the Half-Life 2 track; the fade-in animation is dropped with it.
	menu.PlayMusic = function(self)
		ix.music.Start()
	end

	local onRemove = menu.OnRemove

	menu.OnRemove = function(self)
		if (onRemove) then onRemove(self) end

		ix.music.Stop()
	end
end

hook.Add("OnCharacterMenuCreated", "ixMusicPlayer", function(panel)
	if (not IsValid(panel)) then return end

	if (IsValid(ix.gui.musicPlayer)) then ix.gui.musicPlayer:Remove() end

	ix.gui.musicPlayer = vgui.Create("ixFOMusicPlayer", panel)
end)

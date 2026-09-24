--[[
	The music player in the corner of the character menu.

	Phoenix's sat top-left of their main menu: a song name, play, pause, a
	shuffle toggle and a list to add to. This is the same in this schema's
	widgets, parented to Helix's `ixCharMenu` by `libs/cl_music.lua`, which
	owns the playback. The panel only shows and asks.

	`derma/` loads before `sh_schema.lua`: nothing from `ix.fallout` or
	`ix.music` is read at file scope here.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

local NOTE = Color(190, 190, 180)

function PANEL:Init()
	if (ix.fallout and ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(Scaled(340), Scaled(118))
	self:SetPos(Scaled(24), Scaled(24))

	local title = self:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(18))
	title:DockMargin(Scaled(10), Scaled(6), Scaled(10), 0)
	title:SetFont("ixLootBadge")
	title:SetTextColor(NOTE)
	title:SetText("MENU MUSIC")

	self.song = self:Add("ixFOLabel")
	self.song:Dock(TOP)
	self.song:SetTall(Scaled(22))
	self.song:DockMargin(Scaled(10), 0, Scaled(10), 0)
	self.song:SetFont("ixLootRow")
	self.song:SetTextColor(color_white)

	local bar = self:Add("Panel")

	bar:Dock(BOTTOM)
	bar:SetTall(Scaled(30))
	bar:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(8))

	local function Button(text, tip, callback, wide)
		local button = bar:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(wide or 34))
		button:DockMargin(0, 0, Scaled(4), 0)
		button:SetText(text)
		button:SetFont("ixLootRow")
		button:SetContentAlignment(5)
		button:SetTooltip(tip)
		button.DoClick = callback

		return button
	end

	Button("◁", "Previous", function() ix.music.Next(-1) end)

	self.play = Button("▷", "Play / pause", function() ix.music.Toggle() end)

	Button("▷▷", "Next", function() ix.music.Next() end)

	self.shuffle = Button("", "Shuffle, or in order", function()
		local convar = GetConVar("fo_menu_shuffle")

		convar:SetBool(not convar:GetBool())
		self:Refresh()
	end, 44)

	self.mute = Button("", "Music on or off", function()
		local convar = GetConVar("fo_menu_music")

		convar:SetBool(not convar:GetBool())

		if (convar:GetBool()) then ix.music.Start() else ix.music.Stop() end

		self:Refresh()
	end, 44)

	--- The list, as a dropdown: pick one and it plays.
	self.list = bar:Add("DComboBox")
	self.list:Dock(FILL)
	self.list:SetFont("ixLootBadge")
	self.list:SetTextColor(color_white)
	self.list:SetValue("Pick a song")

	for index, song in ipairs(ix.music.Playlist()) do
		self.list:AddChoice(song.name, index)
	end

	self.list.OnSelect = function(_, _, _, index)
		ix.music.Play(index)
	end

	self:Refresh()

	hook.Add("MenuMusicChanged", self, function() self:Refresh() end)
end

function PANEL:Refresh()
	if (not IsValid(self)) then return end

	local song = ix.music.Current()
	local playing = IsValid(ix.music.channel) and not ix.music.paused

	self.song:SetText(song and song.name
		or (GetConVar("fo_menu_music"):GetBool() and "Nothing playing" or "Off"))
	self.play:SetText(playing and "||" or "▷")
	self.shuffle:SetText(GetConVar("fo_menu_shuffle"):GetBool() and "∞" or "↺")
	self.mute:SetText(GetConVar("fo_menu_music"):GetBool() and "ON" or "OFF")
end

function PANEL:Paint(width, height)
	surface.SetDrawColor(10, 10, 10, 200)
	surface.DrawRect(0, 0, width, height)

	local palette = ix.fallout and ix.fallout.GetPalette
		and ix.fallout.GetPalette() or nil
	local color = palette and palette.color_primary or Color(255, 182, 66)

	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.DrawRect(0, 0, Scaled(3), height)
end

vgui.Register("ixFOMusicPlayer", PANEL, "Panel")

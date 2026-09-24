--[[
	The RADIO tab of the F1 menu.

	Every station `sh_radio.lua` knows, with what it is and how much of it
	there is; TUNE on one, OFF on the one that is playing, NEXT to skip, a
	volume slider. `libs/cl_radio.lua` does the playing and remembers the
	choice; this shows and asks.

	`derma/` loads before `sh_schema.lua`: nothing from `ix.radio` is read at
	file scope here.
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

	self.header = self:Add("Panel")
	self.header:Dock(TOP)
	self.header:SetTall(Scaled(64))
	self.header:DockMargin(Scaled(12), Scaled(8), Scaled(12), Scaled(6))

	local title = self.header:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(26))
	title:SetFont("ixLootHeader")
	title:SetTextColor(color_white)
	title:SetText("RADIO")

	self.now = self.header:Add("ixFOLabel")
	self.now:Dock(TOP)
	self.now:SetTall(Scaled(20))
	self.now:SetFont("ixLootRow")
	self.now:SetTextColor(NOTE)

	local controls = self:Add("Panel")

	controls:Dock(BOTTOM)
	controls:SetTall(Scaled(36))
	controls:DockMargin(Scaled(12), Scaled(6), Scaled(12), Scaled(10))

	local function Button(text, callback)
		local button = controls:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(96))
		button:DockMargin(0, 0, Scaled(6), 0)
		button:SetText(text)
		button:SetFont("ixLootBadge")
		button:SetContentAlignment(5)
		button.DoClick = callback
	end

	Button("NEXT", function() ix.radio.Next() end)
	Button("OFF", function() ix.radio.Off() end)

	local slider = controls:Add("DNumSlider")

	slider:Dock(FILL)
	slider:DockMargin(Scaled(12), 0, 0, 0)
	slider:SetText("Volume")
	slider:SetMin(0)
	slider:SetMax(1)
	slider:SetDecimals(2)
	slider:SetValue(ix.radio.Volume())
	slider.Label:SetTextColor(color_white)
	slider.OnValueChanged = function(_, value) ix.radio.SetVolume(value) end

	self.list = self:Add("DScrollPanel")
	self.list:Dock(FILL)
	self.list:DockMargin(Scaled(12), 0, Scaled(12), 0)

	self:Rebuild()

	hook.Add("RadioChanged", self, function() self:Rebuild() end)
end

function PANEL:Rebuild()
	if (not IsValid(self)) then return end

	self.list:Clear()

	local tuned = ix.radio.Station()
	local song = ix.radio.now

	self.now:SetText(tuned
		and string.format("Tuned to %s  ·  %s", tuned.name,
			song and song.name or "...")
		or "Off. Tune a station and it plays in the background until you "
			.. "turn it off - even next session.")

	for _, station in ipairs(ix.radio.stations or {}) do
		local row = self.list:Add("Panel")
		local current = tuned == station

		row:Dock(TOP)
		row:SetTall(Scaled(52))
		row:DockMargin(0, 0, 0, Scaled(4))

		row.Paint = function(_, w, h)
			surface.SetDrawColor(0, 0, 0, current and 160 or 100)
			surface.DrawRect(0, 0, w, h)

			if (current) then
				local palette = ix.fallout.GetPalette and ix.fallout.GetPalette()
				local color = palette and palette.color_primary
					or Color(255, 182, 66)

				surface.SetDrawColor(color.r, color.g, color.b, 255)
				surface.DrawRect(0, 0, Scaled(4), h)
			end
		end

		local button = row:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(Scaled(96))
		button:DockMargin(Scaled(8), Scaled(10), Scaled(8), Scaled(10))
		button:SetText(current and "OFF" or "TUNE")
		button:SetFont("ixLootBadge")
		button:SetContentAlignment(5)
		button.DoClick = function()
			if (current) then ix.radio.Off() else ix.radio.Tune(station.id) end
		end

		local name = row:Add("ixFOLabel")

		name:Dock(TOP)
		name:SetTall(Scaled(24))
		name:DockMargin(Scaled(12), Scaled(4), 0, 0)
		name:SetFont("ixLootRow")
		name:SetTextColor(color_white)
		name:SetText(string.format("%s   (%d songs)", station.name,
			#station.songs))

		local blurb = row:Add("ixFOLabel")

		blurb:Dock(TOP)
		blurb:SetTall(Scaled(18))
		blurb:DockMargin(Scaled(12), 0, 0, 0)
		blurb:SetFont("ixLootBadge")
		blurb:SetTextColor(NOTE)
		blurb:SetText(station.blurb or "")
	end
end

vgui.Register("ixFORadio", PANEL, "Panel")

hook.Add("CreateMenuButtons", "ixFalloutRadio", function(tabs)
	tabs["radio"] = function(container)
		local panel = container:Add("ixFORadio")

		panel:Dock(FILL)
	end
end)

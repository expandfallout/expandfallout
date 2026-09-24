--[[
	The crosshair editor - `/Crosshair`.

	Phoenix's has a live preview on one side and the controls on the other, and
	so does this. The controls are BUILT FROM `ix.crosshair.settings` rather
	than written out one at a time, so a new setting is a line in that table and
	appears here with the right kind of control and the right bounds.

	EVERY CHANGE IS IMMEDIATE. There is no save button because there is nothing
	to lose: the crosshair in the preview is the crosshair you will have, and
	`ix.crosshair.Set` writes the file as it goes. RESET puts the defaults back.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.crosshair)) then
		ix.gui.crosshair:Remove()
	end

	ix.gui.crosshair = self

	if (ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(900)),
		math.min(ScrH() - Scaled(80), Scaled(640)))
	self:Center()
	self:MakePopup()
	self:SetTitle("CROSSHAIR")

	--------------------------------------------------------------------------
	-- The footer, docked first so that it keeps its height
	--------------------------------------------------------------------------

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(32))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	local reset = footer:Add("ixFOButton")

	reset:Dock(LEFT)
	reset:SetWide(Scaled(110))
	reset:SetText("RESET")
	reset:SetContentAlignment(5)
	reset.DoClick = function()
		Derma_Query("Put every crosshair setting back to its default?",
			"Crosshair", "Reset", function()
				ix.crosshair.Reset()
				ix.crosshair.Apply()

				self:Rebuild()
			end, "Cancel", function() end)
	end

	local hint = footer:Add("ixFOLabel")

	hint:Dock(FILL)
	hint:DockMargin(Scaled(10), 0, Scaled(10), 0)
	hint:SetContentAlignment(4)
	hint:SetFont("ixLootSmall")
	hint:SetText("Changes apply as you make them, and are saved on this "
		.. "computer rather than on your character.")

	--------------------------------------------------------------------------
	-- The preview
	--------------------------------------------------------------------------

	--[[
		The preview is a third of the window, which is Phoenix's arrangement -
		it has to be big enough to judge a two pixel gap by.
	]]
	local preview = self:Add("ixFOPanelBracketed")

	preview:Dock(LEFT)
	preview:SetWide(Scaled(300))
	preview:DockMargin(0, 0, Scaled(8), 0)
	preview.Paint = function(panel, width, height)
		surface.SetDrawColor(16, 18, 16, 255)
		surface.DrawRect(0, 0, width, height)

		self:DrawPreview(width, height)

		ix.fallout.DrawBrackets(width, height, nil, 0, true)
	end

	self.preview = preview

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	self:Rebuild()
end

--[[
	The crosshair as it will look, drawn with the same numbers the real one
	uses rather than as a picture of one. The middle of the panel stands in for
	the middle of the screen, so these are the panel's own coordinates.
]]
function PANEL:DrawPreview(width, height)
	local x, y = math.Round(width * 0.5), math.Round(height * 0.5)

	local colour = ix.crosshair.ToColor(ix.crosshair.Get("colour"))
	local outline = ix.crosshair.Get("outline")
		and ix.crosshair.ToColor(ix.crosshair.Get("outlineColour")) or nil
	local outlineSize = ix.crosshair.Get("outlineSize")

	local shape = ix.crosshair.Get("shape")
	local gap = ix.crosshair.Get("gap")
	local size = ix.crosshair.Get("size")
	local thickness = ix.crosshair.Get("thickness")

	local function Arm(ax, ay, aw, ah)
		if (outline) then
			surface.SetDrawColor(outline)
			surface.DrawRect(ax - outlineSize, ay - outlineSize,
				aw + outlineSize * 2, ah + outlineSize * 2)
		end

		surface.SetDrawColor(colour)
		surface.DrawRect(ax, ay, aw, ah)
	end

	if (shape == "cross") then
		local half = math.floor(thickness * 0.5)

		Arm(x - gap - size, y - half, size, thickness)
		Arm(x + gap, y - half, size, thickness)
		Arm(x - half, y + gap, thickness, size)

		if (not ix.crosshair.Get("tShape")) then
			Arm(x - half, y - gap - size, thickness, size)
		end
	elseif (shape == "circle") then
		if (outline) then
			for ring = 0, outlineSize do
				surface.DrawCircle(x, y, gap + size + ring, outline)
				surface.DrawCircle(x, y, math.max(gap - ring, 1), outline)
			end
		end

		for ring = 0, math.max(size - 1, 0) do
			surface.DrawCircle(x, y, gap + ring, colour)
		end
	end

	if (ix.crosshair.Get("dot") or shape == "dot") then
		local dot = ix.crosshair.Get("dotSize")

		Arm(x - math.floor(dot * 0.5), y - math.floor(dot * 0.5), dot, dot)
	end

	--- The hit marker, always shown here: this is where its size is judged.
	if (not ix.crosshair.Get("hitMarker")) then return end

	local marker = ix.crosshair.ToColor(ix.crosshair.Get("hitColour"))
	local length = ix.crosshair.Get("hitSize")
	local hitGap = math.max(length * 0.4, 2)

	surface.SetDrawColor(marker)

	for _, corner in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
		local dx, dy = corner[1], corner[2]

		surface.DrawLine(x + hitGap * dx, y + hitGap * dy,
			x + (hitGap + length) * dx, y + (hitGap + length) * dy)
	end
end

--[[
	Rebuilt whole rather than updated in place, because changing the shape
	changes which rows make sense. The scroll is put back afterwards so that
	the row that was just clicked does not jump out from under the cursor.
]]
function PANEL:Rebuild()
	local scroll = self.list:GetVBar():GetScroll()

	self.list:Clear()

	for _, setting in ipairs(ix.crosshair.settings) do
		self:AddSetting(setting)
	end

	self.list:InvalidateLayout(true)
	self.list:GetVBar():SetScroll(scroll)
end

--------------------------------------------------------------------------------
-- The controls
--------------------------------------------------------------------------------

--[[
	A slider in the schema's own look.

	`DNumSlider` is Derma's grey-on-grey and would be the only control in the
	menu that is not the terminal green, so this is a bar that fills, drawn the
	way the rest of the UI is, with its number on the right of it.
]]
local function Slider(parent, setting, width)
	local minimum, maximum = setting.min or 0, setting.max or 100
	local slider = parent:Add("DPanel")

	slider:Dock(RIGHT)
	slider:SetWide(width)
	slider:SetPaintBackground(false)

	function slider:Fraction()
		local value = ix.crosshair.Get(setting.key)
		local span = maximum - minimum

		return math.Clamp((value - minimum) / math.max(span, 1), 0, 1)
	end

	--- The bar is everything but the room the number needs on the right.
	function slider:BarWidth()
		return math.max(self:GetWide() - Scaled(46), 1)
	end

	--- Where the pointer is, written back as a value.
	function slider:Read(x)
		local fraction = math.Clamp(x / self:BarWidth(), 0, 1)
		local span = maximum - minimum

		ix.crosshair.Set(setting.key,
			math.Round(minimum + fraction * span))
	end

	function slider:OnMousePressed()
		self.dragging = true

		self:MouseCapture(true)
		self:Read(self:CursorPos())
		ix.fallout.PlayUISound("select")
	end

	function slider:OnMouseReleased()
		self.dragging = false

		self:MouseCapture(false)
	end

	function slider:Think()
		if (not self.dragging) then return end

		self:Read(self:CursorPos())
	end

	function slider:Paint(panelWidth, height)
		local palette = ix.fallout.GetPalette()
		local bar = self:BarWidth()
		local middle = math.Round(height * 0.5) - Scaled(3)
		local filled = math.Round(bar * self:Fraction())

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, middle, bar, Scaled(6))

		surface.SetDrawColor(palette.color_primary)
		surface.DrawRect(0, middle, filled, Scaled(6))

		--- A handle, so that it is obvious the bar is something you can drag.
		surface.SetDrawColor(palette.color_active)
		surface.DrawRect(math.Clamp(filled - Scaled(2), 0, bar - Scaled(4)),
			middle - Scaled(4), Scaled(4), Scaled(14))

		draw.SimpleText(ix.crosshair.Get(setting.key), "ixLootRow",
			panelWidth, height * 0.5, palette.text_primary, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end

	return slider
end

--- One row, whose control depends on what kind of setting it is.
function PANEL:AddSetting(setting)
	local row = self.list:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(setting.note and 50 or 34))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:DockPadding(Scaled(8), Scaled(4), Scaled(8), Scaled(4))
	row:SetNoOverdraw(true)

	local value = ix.crosshair.Get(setting.key)

	if (setting.kind == "bool") then
		local button = row:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(Scaled(70))
		button:SetText(value and "ON" or "OFF")
		button:SetContentAlignment(5)
		button:SetActive(value and true or false)
		button.DoClick = function()
			local now = not ix.crosshair.Get(setting.key)

			ix.crosshair.Set(setting.key, now)
			ix.crosshair.Apply()

			button:SetText(now and "ON" or "OFF")
			button:SetActive(now)
		end
	elseif (setting.kind == "colour") then
		local swatch = row:Add("DButton")

		swatch:Dock(RIGHT)
		swatch:SetWide(Scaled(70))
		swatch:SetText("")
		swatch.Paint = function(_, width, height)
			--- Checkerboard behind it, so that a low alpha still reads as one.
			surface.SetDrawColor(70, 70, 70, 255)
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(40, 40, 40, 255)
			surface.DrawRect(0, 0, width * 0.5, height * 0.5)
			surface.DrawRect(width * 0.5, height * 0.5, width * 0.5,
				height * 0.5)

			surface.SetDrawColor(ix.crosshair.ToColor(
				ix.crosshair.Get(setting.key)))
			surface.DrawRect(0, 0, width, height)

			ix.fallout.DrawBrackets(width, height, nil, 0, true)
		end

		swatch.DoClick = function()
			ix.fallout.PlayUISound("select")

			self:PickColour(setting)
		end
	elseif (setting.kind == "choice") then
		--[[
			Reversed, because docking RIGHT stacks right-to-left in child order
			- without this the choices read backwards from how they are listed.
		]]
		for index = #setting.choices, 1, -1 do
			local choice = setting.choices[index]
			local button = row:Add("ixFOButton")

			button:Dock(RIGHT)
			button:SetWide(Scaled(84))
			button:DockMargin(Scaled(4), 0, 0, 0)
			button:SetText(string.upper(choice.name))
			button:SetContentAlignment(5)
			button:SetFont("ixLootSmall")
			button:SetActive(value == choice.id)
			button.DoClick = function()
				ix.crosshair.Set(setting.key, choice.id)

				self:Rebuild()
			end
		end
	else
		Slider(row, setting, Scaled(200))
	end

	local label = row:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(18))
	label:SetFont("ixLootRow")
	label:SetText(setting.name)

	if (not setting.note) then return end

	local note = row:Add("ixFOLabel")

	note:Dock(FILL)
	note:SetFont("ixLootSmall")
	note:SetTextColor(ix.fallout.GetPalette().color_active)
	note:SetWrap(true)
	note:SetText(setting.note)
end

--[[
	The colour picker.

	Derma's mixer inside one of this schema's frames rather than a bare
	`DFrame`, because a grey Windows-looking box in the middle of the terminal
	green is the one thing people notice. The mixer itself is Derma's - a
	colour wheel is a colour wheel.
]]
function PANEL:PickColour(setting)
	if (IsValid(self.picker)) then self.picker:Remove() end

	local frame = vgui.Create("ixFOFrame")

	self.picker = frame

	frame:SetSize(Scaled(280), Scaled(330))
	frame:Center()
	frame:SetTitle(string.upper(setting.name))
	frame:MakePopup()

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(28))
	close:DockMargin(0, Scaled(8), 0, 0)
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local mixer = frame:Add("DColorMixer")

	mixer:Dock(FILL)
	mixer:SetAlphaBar(true)
	mixer:SetPalette(true)
	mixer:SetColor(ix.crosshair.ToColor(ix.crosshair.Get(setting.key)))

	--[[
		`ValueChanged` fires while the wheel is being dragged, so this writes
		the file on every frame of a drag. That is what `Set` does everywhere
		else and the file is a few hundred bytes, so it is left simple rather
		than made clever.
	]]
	mixer.ValueChanged = function(_, colour)
		ix.crosshair.Set(setting.key,
			{colour.r, colour.g, colour.b, colour.a})
	end
end

function PANEL:OnRemove()
	if (IsValid(self.picker)) then self.picker:Remove() end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("ixFOCrosshair", PANEL, "ixFOFrame")

--[[
	`fo_crosshair` as well as `/Crosshair`.

	The command goes through the server and comes back, like every other window
	in this schema; this one does not have to, because there is nothing on the
	other end - the settings are the player's own. So it is here for anybody who
	would rather bind a key than type in chat.
]]
concommand.Add("fo_crosshair", function()
	vgui.Create("ixFOCrosshair")
end)

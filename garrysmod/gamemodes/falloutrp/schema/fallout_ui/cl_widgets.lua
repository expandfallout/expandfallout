--[[
	Fallout UI - widget set.

	Ported from Phoenix's `fallout_ui/vgui/cl_fo_*.lua`. These are the building
	blocks the panel work uses, registered under `ixFO*` names.

	The visual signature of the Fallout interface is the BRACKET: a rule along
	the top and bottom of a panel with short ticks turning down at each corner,
	drawn a couple of pixels OUTSIDE the panel bounds (hence DisableClipping),
	with a one-pixel black shadow offset behind it. `ix.fallout.DrawBrackets`
	is that motif, factored out - Phoenix repeats the twelve DrawRect calls
	verbatim in four separate panels.

	Note these widgets invert on hover - solid palette fill, dark text - which
	is the authentic look and is safe HERE, unlike in the derma skin, because
	each widget sets its own text colour rather than inheriting it from
	SKIN.Colours. See 16-ui.md.
]]

ix.fallout = ix.fallout or {}

--[[
	The bracket motif.

	`inset` shifts the rules inward, for panels that cannot overdraw their
	parent. Everything scales off the font scale so it holds up at 4K, where
	Phoenix's fixed 2px rules almost vanish.

	`bNoOverdraw` keeps the rules INSIDE the panel and skips `DisableClipping`
	entirely. That matters inside a scroll panel: `DisableClipping(true)` does
	not just let this panel draw past its own edge, it lifts the scissor for the
	whole draw - so rows near the bottom of a list render straight through the
	viewport and out over whatever is beneath it.
]]
function ix.fallout.DrawBrackets(w, h, color, inset, bNoOverdraw)
	local palette = ix.fallout.GetPalette()
	local scale = math.max(ix.fallout.GetFontScale(), 1)

	color = color or palette.color_primary
	inset = inset or 0

	local t = math.Round(2 * scale)      -- rule thickness
	local tick = math.Round(6 * scale)   -- corner tick length

	--[[
		Overdrawing puts the top rule ABOVE y=0 and the side ticks LEFT of x=0.
		Without clipping to escape, everything has to start one thickness in.
	]]
	if (bNoOverdraw) then
		inset = inset + t
	end

	local top = inset - t
	local bottom = h - inset

	if (not bNoOverdraw) then
		DisableClipping(true)

		-- Shadow, one pixel down-right of everything below it.
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(1, top + 1, w, t)
		surface.DrawRect(1 - t, top + 1, t, tick)
		surface.DrawRect(w + 1, top + 1, t, tick)
		surface.DrawRect(1, bottom + 1, w, t)
		surface.DrawRect(1 - t, bottom + 1 - tick + t, t, tick)
		surface.DrawRect(w + 1, bottom + 1 - tick + t, t, tick)
	end

	local left = bNoOverdraw and 0 or -t
	local right = bNoOverdraw and (w - t) or w

	surface.SetDrawColor(color)
	surface.DrawRect(inset, top, w - inset * 2, t)
	surface.DrawRect(left, top, t, tick)
	surface.DrawRect(right, top, t, tick)
	surface.DrawRect(inset, bottom, w - inset * 2, t)
	surface.DrawRect(left, bottom - tick + t, t, tick)
	surface.DrawRect(right, bottom - tick + t, t, tick)

	if (not bNoOverdraw) then
		DisableClipping(false)
	end
end

--[[
	UI sounds.

	Phoenix's live in a sound pack we do not have installed, and PlaySound on a
	missing file spams the console once per click. Checked once, then cached.
]]
local UI_SOUNDS = {
	select = "phoenix/ui/76/ui_select_on.mp3",
	hover = "phoenix/ui/76/ui_select_off.mp3"
}

local soundExists = {}

function ix.fallout.PlayUISound(name)
	local path = UI_SOUNDS[name]

	if (not path) then return end

	if (soundExists[name] == nil) then
		soundExists[name] = file.Exists("sound/" .. path, "GAME")
	end

	if (soundExists[name]) then
		surface.PlaySound(path)
	end
end

--------------------------------------------------------------------------------
-- SPECIAL rows
--------------------------------------------------------------------------------

--[[
	One SPECIAL row, drawn identically wherever SPECIAL appears - the creation
	screen's allocation list and the F1 tab. Shared rather than duplicated
	because the two drifting apart is exactly the sort of thing nobody notices
	until both are wrong in different ways.

	Phoenix's row is a filled box with a DOUBLE border - two accent outlines a
	pixel apart, over a black one offset down-right for depth:

	    surface.DrawRect(0, 0, w, h)                      -- color_background
	    surface.DrawOutlinedRect(2, 2, w - 1, h - 1)      -- black
	    surface.DrawOutlinedRect(0, 0, w, h)              -- color_primary
	    surface.DrawOutlinedRect(1, 1, w - 2, h - 2)      -- color_primary

	then the initial, the name and the value as three fixed columns, with the
	action right-aligned.
]]
ix.fallout.SPECIAL_ROW_HEIGHT = 46

--- Row height at the current resolution.
function ix.fallout.GetSpecialRowHeight()
	return math.Round(ix.fallout.SPECIAL_ROW_HEIGHT * ix.fallout.GetFontScale())
end

--[[
	`data` carries { letter, name, value, action, actionColor, valueColor,
	hovered }. Everything is optional: a row with no `letter` skips the initial
	cell entirely, which is what the points-remaining row needs.
]]
function ix.fallout.DrawSpecialRow(x, y, w, h, data)
	local palette = ix.fallout.GetPalette()
	local scale = ix.fallout.GetFontScale()

	local function S(value)
		return math.Round(value * scale)
	end

	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, 235)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(ColorAlpha(palette.color_background, data.hovered and 235 or 190))
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawOutlinedRect(x + 2, y + 2, w - 1, h - 1)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawOutlinedRect(x, y, w, h)
	surface.DrawOutlinedRect(x + 1, y + 1, w - 2, h - 2)

	local textY = y + h * 0.5

	if (data.letter) then
		draw.SimpleText(data.letter, "UI_Medium", x + S(24), textY,
			palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (data.name) then
		draw.SimpleText(data.name, "UI_Regular", x + S(64), textY,
			palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (data.value) then
		draw.SimpleText(data.value, "UI_Medium", x + S(210), textY,
			data.valueColor or palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (data.action) then
		draw.SimpleText(data.action, "UI_Regular", x + w - S(16), textY,
			data.actionColor or palette.color_active, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

--------------------------------------------------------------------------------
-- Panels
--------------------------------------------------------------------------------

local PANEL = {}

function PANEL:Init()
	self.backgroundAlpha = 200
end

function PANEL:SetBackgroundAlpha(alpha)
	self.backgroundAlpha = alpha
end

function PANEL:Paint(w, h)
	if (not self:GetPaintBackground()) then return end

	surface.SetDrawColor(ColorAlpha(ix.fallout.GetPalette().color_background, self.backgroundAlpha))
	surface.DrawRect(0, 0, w, h)
end

vgui.Register("ixFOPanel", PANEL, "DPanel")

--- The bracketed panel - the workhorse of the Fallout layout.
PANEL = {}

function PANEL:Init()
	self.backgroundAlpha = 200
	self.bNoBackground = false
end

function PANEL:SetBackgroundAlpha(alpha)
	self.backgroundAlpha = alpha
end

--- Draw brackets only, no fill. For grouping without boxing something in.
function PANEL:SetNoBackground(bValue)
	self.bNoBackground = bValue ~= false
end

function PANEL:Paint(w, h)
	if (not self:GetPaintBackground()) then return end

	if (not self.bNoBackground) then
		surface.SetDrawColor(ColorAlpha(self.backgroundColor
			or ix.fallout.GetPalette().color_background, self.backgroundAlpha))
		surface.DrawRect(0, 0, w, h)
	end

	ix.fallout.DrawBrackets(w, h, self.bracketColor, 0, self.bNoOverdraw)
end

function PANEL:SetBackgroundColor(color)
	self.backgroundColor = color
end

--[[
	Keep the brackets inside the panel.

	For panels inside a scroll list: the overdraw the brackets normally do
	needs `DisableClipping`, which lifts the scissor for the whole draw and lets
	rows spill out through the bottom of the viewport.
]]
function PANEL:SetNoOverdraw(bValue)
	self.bNoOverdraw = bValue ~= false
end

function PANEL:SetBracketColor(color)
	self.bracketColor = color
end

vgui.Register("ixFOPanelBracketed", PANEL, "DPanel")

--- Frame: bracketed, with the title sitting in the gap in the top rule.
PANEL = {}

function PANEL:Init()
	local palette = ix.fallout.GetPalette()

	self.lblTitle:SetTextColor(palette.text_primary)
	self.lblTitle:SetExpensiveShadow(1, color_black)
	self.lblTitle:SetFont("UI_Bold")

	self:DockPadding(12, 36, 12, 12)
	self:SetDraggable(false)
	self:ShowCloseButton(false)

	self.backgroundAlpha = 200
end

function PANEL:Paint(w, h)
	local palette = ix.fallout.GetPalette()
	local scale = math.max(ix.fallout.GetFontScale(), 1)
	local t = math.Round(2 * scale)
	local tick = math.Round(6 * scale)
	local titleW = self.lblTitle:GetContentSize()
	local top = 22

	surface.SetDrawColor(ColorAlpha(palette.color_background, self.backgroundAlpha))
	surface.DrawRect(0, top + t, w, h - top - t)

	DisableClipping(true)

	-- The top rule breaks around the title rather than running behind it.
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(1, top + 1, 8, t)
	surface.DrawRect(titleW + 11, top + 1, w - (titleW + 11), t)
	surface.DrawRect(1 - t, top + 1, t, tick)
	surface.DrawRect(w + 1, top + 1, t, tick)
	surface.DrawRect(1, h + 1, w, t)
	surface.DrawRect(1 - t, h + 1 - tick + t, t, tick)
	surface.DrawRect(w + 1, h + 1 - tick + t, t, tick)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawRect(0, top, 8, t)
	surface.DrawRect(titleW + 10, top, w - (titleW + 10), t)
	surface.DrawRect(-t, top, t, tick)
	surface.DrawRect(w, top, t, tick)
	surface.DrawRect(0, h, w, t)
	surface.DrawRect(-t, h - tick + t, t, tick)
	surface.DrawRect(w, h - tick + t, t, tick)

	DisableClipping(false)
end

vgui.Register("ixFOFrame", PANEL, "DFrame")

--- Button. Inverts on hover: solid palette fill, dark text.
PANEL = {}

function PANEL:Init()
	local palette = ix.fallout.GetPalette()

	self:SetTextColor(palette.text_primary)
	self:SetExpensiveShadow(1, color_black)
	self:SetContentAlignment(4)
	self:SetFont("UI_Bold")
	self:SetTall(math.Round(32 * ix.fallout.GetFontScale()))

	self.bActive = false
end

function PANEL:Paint(w, h)
	if (not self:GetPaintBackground()) then return end

	local hovered = (self:IsHovered() or self:IsDown()) and not self:GetDisabled()

	if (not (hovered or self.bActive)) then return end

	local palette = ix.fallout.GetPalette()

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(1, 1, w, h)

	surface.SetDrawColor(self.bActive and palette.color_active or palette.color_primary)
	surface.DrawRect(0, 0, w - 1, h - 1)
end

function PANEL:OnMousePressed(code)
	if (self:GetDisabled()) then return end

	ix.fallout.PlayUISound("select")

	if (code == MOUSE_LEFT) then
		self:DoClick()
	elseif (code == MOUSE_RIGHT) then
		self:DoRightClick()
	end
end

function PANEL:OnCursorEntered()
	if (self:GetDisabled() or self.bActive) then return end

	-- Text flips dark because the background just went solid behind it.
	self:SetTextColor(ix.fallout.GetPalette().text_hover)
	self:SetExpensiveShadow(0, color_black)
	ix.fallout.PlayUISound("hover")
end

function PANEL:OnCursorExited()
	if (self:GetDisabled() or self.bActive) then return end

	self:SetTextColor(ix.fallout.GetPalette().text_primary)
	self:SetExpensiveShadow(1, color_black)
end

function PANEL:SetDisabled(bDisabled)
	self.m_bDisabled = bDisabled
	self:InvalidateLayout()

	local palette = ix.fallout.GetPalette()

	self:SetTextColor(bDisabled and palette.text_disabled or palette.text_primary)
	self:SetExpensiveShadow(1, color_black)
end

function PANEL:SetActive(bValue)
	self.bActive = bValue

	local palette = ix.fallout.GetPalette()

	self:SetTextColor(bValue and palette.text_hover or palette.text_primary)
end

function PANEL:GetActive()
	return self.bActive
end

vgui.Register("ixFOButton", PANEL, "DButton")

--- Label.
PANEL = {}

function PANEL:Init()
	self:SetTextColor(ix.fallout.GetPalette().text_primary)
	self:SetExpensiveShadow(1, color_black)
	self:SetFont("UI_Regular")
end

vgui.Register("ixFOLabel", PANEL, "DLabel")

--- Text entry: solid palette field with dark text, like a terminal prompt.
PANEL = {}

function PANEL:Init()
	local palette = ix.fallout.GetPalette()

	self:SetContentAlignment(4)
	self:SetFont("UI_Bold")
	self:SetTall(math.Round(32 * ix.fallout.GetFontScale()))
	self:SetTextColor(palette.text_hover)
	self:SetHighlightColor(palette.color_active)
	self:SetCursorColor(palette.text_hover)
	self:SetPlaceholderColor(palette.text_disabled)
end

function PANEL:Paint(w, h)
	local palette = ix.fallout.GetPalette()

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(1, 1, w, h)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawRect(0, 0, w, h)

	-- Placeholder handling, then the real text. DrawTextEntryText is what
	-- actually renders the value, the selection and the caret - a text entry
	-- that overrides Paint and omits it silently accepts input and shows
	-- nothing. See 16-ui.md.
	local placeholder = self.GetPlaceholderText and self:GetPlaceholderText()

	if (placeholder and placeholder:Trim() ~= "" and self:GetPlaceholderColor()
	and (not self:GetText() or self:GetText() == "")) then
		local oldText = self:GetText()
		local str = placeholder

		if (str:StartWith("#")) then
			str = str:sub(2)
		end

		self:SetText(language.GetPhrase(str))
		self:DrawTextEntryText(self:GetPlaceholderColor(), self:GetHighlightColor(), self:GetCursorColor())
		self:SetText(oldText)

		return
	end

	self:DrawTextEntryText(self:GetTextColor(), self:GetHighlightColor(), self:GetCursorColor())
end

vgui.Register("ixFOTextEntry", PANEL, "DTextEntry")

--- Scroll panel with a flat palette-coloured bar.
PANEL = {}

local function PaintScrollPiece(panel, w, h)
	local palette = ix.fallout.GetPalette()

	surface.SetDrawColor(panel.Depressed and palette.color_active or palette.color_primary)
	surface.DrawRect(0, 0, w, h)
end

function PANEL:Init()
	local bar = self:GetVBar()

	bar.Paint = function(_, w, h)
		surface.SetDrawColor(ColorAlpha(ix.fallout.GetPalette().color_background, 200))
		surface.DrawRect(0, 0, w, h)
	end

	bar.btnUp.Paint = PaintScrollPiece
	bar.btnDown.Paint = PaintScrollPiece
	bar.btnGrip.Paint = PaintScrollPiece
end

vgui.Register("ixFOScrollPanel", PANEL, "DScrollPanel")

--------------------------------------------------------------------------------
-- Numeric entry
--------------------------------------------------------------------------------

--[[
	A number field with a unit suffix and a clamped range.

	Used for the character's height, weight and age. A plain text entry would
	do, but these values are read back by other systems - they end up on the
	HUD when you look at someone - so a field that can only ever hold a number
	in range is worth more than one that validates on submit.

	It starts EMPTY. A prefilled default is a value the player never chose, and
	one they will happily walk past without reading; an empty box with the valid
	range as a placeholder asks the question instead of answering it.
	`GetValue` returns nil while it is empty, which is what makes "you didn't
	fill this in" distinguishable from "you chose the default".
]]
local PANEL = {}

AccessorFunc(PANEL, "minimum", "Min", FORCE_NUMBER)
AccessorFunc(PANEL, "maximum", "Max", FORCE_NUMBER)
AccessorFunc(PANEL, "suffix", "Suffix", FORCE_STRING)

function PANEL:Init()
	self.minimum = 0
	self.maximum = 100
	self.suffix = ""
	self.label = ""

	self.entry = self:Add("ixTextEntry")
	self.entry:Dock(FILL)
	self.entry:SetNumeric(true)
	self.entry:SetUpdateOnType(true)
	self.entry:SetText("")

	self.entry.OnValueChange = function()
		self:OnChanged(self:GetValue())
	end

	--[[
		Clamped on FOCUS LOSS, not per keystroke: clamping as you type makes 18
		impossible to reach from an empty box when the minimum is 18, because
		the first "1" snaps straight to it.

		An empty box is left empty rather than snapped to the minimum, so it
		stays distinguishable from a real choice.
	]]
	self.entry.OnLoseFocus = function(entry)
		local value = self:GetValue()

		entry:SetText(value and tostring(value) or "")
		self:OnChanged(value)
	end
end

function PANEL:SetLabel(text)
	self.label = text
end

--- The range, shown while the box is empty.
function PANEL:GetPlaceholder()
	return string.format("%d-%d", self.minimum, self.maximum)
end

function PANEL:SetValue(value)
	value = tonumber(value)

	self.entry:SetText(value
		and tostring(math.Clamp(math.floor(value), self.minimum, self.maximum))
		or "")
end

--- Clamped, or nil while the box is empty.
function PANEL:GetValue()
	local text = string.Trim(self.entry:GetValue() or "")

	if (text == "") then return end

	local value = tonumber(text)

	if (not value) then return end

	return math.Clamp(math.floor(value), self.minimum, self.maximum)
end

function PANEL:OnChanged(value)
end

function PANEL:PerformLayout(width, height)
	local scale = math.max(ix.fallout.GetFontScale(), 1)
	local pad = math.Round(8 * scale)

	--[[
		The suffix is MEASURED, not assumed. A fixed reserve was too narrow for
		"inches" at 1440p, so the unit ran off the panel and rendered as
		"nches" - clipped by the container, not by this panel.

		Helix already draws a label above every character-var panel, so the left
		reserve is only used when this one sets its own.
	]]
	surface.SetFont("UI_Regular")

	local suffixWidth = self.suffix ~= "" and (surface.GetTextSize(self.suffix) + pad * 2) or 0
	local labelWidth = self.label ~= "" and (surface.GetTextSize(self.label) + pad * 2) or 0

	self.entry:DockMargin(labelWidth, 0, suffixWidth, 0)
end

function PANEL:Paint(width, height)
	local palette = ix.fallout.GetPalette()
	local scale = math.max(ix.fallout.GetFontScale(), 1)
	local pad = math.Round(8 * scale)

	if (self.label ~= "") then
		draw.SimpleText(self.label, "UI_Regular", pad, height * 0.5,
			palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (self.suffix ~= "") then
		draw.SimpleText(self.suffix, "UI_Regular", width - pad, height * 0.5,
			palette.color_active, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- The range, while nothing has been entered.
	if (self:GetValue() == nil and not self.entry:HasFocus()) then
		local x, _, _, _ = self.entry:GetDockMargin()

		draw.SimpleText(self:GetPlaceholder(), "UI_Regular", x + pad, height * 0.5,
			palette.text_disabled, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("ixFONumberEntry", PANEL, "Panel")

--------------------------------------------------------------------------------
-- Height entry
--------------------------------------------------------------------------------

--[[
	Feet and inches, side by side.

	Stored and validated as a single inch count - one number is far easier to
	clamp and compare than a pair - but nobody gives their height in inches, so
	that is a storage detail and not what the field should ask for.
]]
PANEL = {}

function PANEL:Init()
	self.feet = self:Add("ixFONumberEntry")
	self.feet:Dock(LEFT)
	self.feet:SetSuffix("ft")
	self.feet:SetMin(0)
	self.feet:SetMax(8)
	self.feet.OnChanged = function()
		self:OnChanged(self:GetValue())
	end

	self.inches = self:Add("ixFONumberEntry")
	self.inches:Dock(FILL)
	self.inches:SetSuffix("in")
	self.inches:SetMin(0)
	self.inches:SetMax(11)
	self.inches.OnChanged = function()
		self:OnChanged(self:GetValue())
	end
end

--- The feet box's range. Inches is always 0-11.
function PANEL:SetFeetRange(minimum, maximum)
	self.feet:SetMin(minimum)
	self.feet:SetMax(maximum)
end

function PANEL:SetValue(total)
	total = tonumber(total)

	if (not total) then
		self.feet:SetValue(nil)
		self.inches:SetValue(nil)
		return
	end

	self.feet:SetValue(math.floor(total / 12))
	self.inches:SetValue(total % 12)
end

--[[
	Total inches, or nil while FEET is empty.

	Inches alone may be blank - "6ft" is a complete answer and means 6ft 0in -
	but feet alone is not, so an empty feet box is what makes the whole field
	unanswered.
]]
function PANEL:GetValue()
	local feet = self.feet:GetValue()

	if (not feet) then return end

	return feet * 12 + (self.inches:GetValue() or 0)
end

function PANEL:OnChanged(value)
end

function PANEL:PerformLayout(width, height)
	self.feet:SetWide(width * 0.5)
	self.feet:DockMargin(0, 0, math.Round(6 * ix.fallout.GetFontScale()), 0)
end

vgui.Register("ixFOHeightEntry", PANEL, "Panel")

--[[
	Rebuild widget colours when the palette changes.

	Widgets cache their colours in Init (SetTextColor and friends), so anything
	already on screen keeps the old palette until it is recreated. Walking the
	live panel tree is cheap and only happens on an option change.
]]
hook.Add("FalloutPaletteChanged", "ixFalloutWidgets", function(palette)
	local function Refresh(panel)
		if (not IsValid(panel)) then return end

		local class = panel:GetName()

		if (class == "ixFOButton") then
			panel:SetTextColor(panel:GetActive() and palette.text_hover or palette.text_primary)
		elseif (class == "ixFOLabel") then
			panel:SetTextColor(palette.text_primary)
		elseif (class == "ixFOTextEntry") then
			panel:SetTextColor(palette.text_hover)
			panel:SetCursorColor(palette.text_hover)
			panel:SetHighlightColor(palette.color_active)
			panel:SetPlaceholderColor(palette.text_disabled)
		end

		for _, child in ipairs(panel:GetChildren()) do
			Refresh(child)
		end
	end

	for _, panel in ipairs(vgui.GetWorldPanel():GetChildren()) do
		Refresh(panel)
	end
end)

--[[
	CRT treatment.

	Scanlines plus a faint phosphor wash of the tube colour. That is all - and
	the restraint is deliberate.

	A first version also drew a vignette from four edge gradients. Gradient
	textures have hard outer edges, so instead of a soft falloff it produced
	four visible rectangular BANDS across the screen. A real vignette needs a
	radial material; Helix ships one (`helix/gui/radial-gradient.png`) but it is
	bright-centre, so it would have to be inverted first. Not worth it - the
	scanlines carry the effect on their own.

	Use this on the PANEL you want to look like a screen, never on a fullscreen
	backdrop: washing the whole viewport in amber is what made the menu look
	like a sepia photograph rather than a Pip-Boy.

	`intensity` scales the effect, 0-1.
]]
function ix.fallout.DrawCRT(w, h, intensity)
	intensity = intensity or 1

	local primary = ix.fallout.GetPalette().color_primary

	-- Phosphor: just enough that the black reads as a lit tube.
	surface.SetDrawColor(primary.r, primary.g, primary.b, 10 * intensity)
	surface.DrawRect(0, 0, w, h)

	if (not ix.option.Get("falloutScanlines", true)) then return end

	surface.SetDrawColor(0, 0, 0, 40 * intensity)

	for y = 0, h, 3 do
		surface.DrawRect(0, y, w, 1)
	end
end

--- Corner ticks, for marking a selected tab the way Phoenix brackets theirs.
function ix.fallout.DrawCorners(x, y, w, h, color, length, thickness)
	local scale = math.max(ix.fallout.GetFontScale(), 1)

	length = length or math.Round(6 * scale)
	thickness = thickness or math.max(math.Round(2 * scale), 1)

	surface.SetDrawColor(color or ix.fallout.GetPalette().color_primary)

	-- top left, top right, bottom left, bottom right
	surface.DrawRect(x, y, length, thickness)
	surface.DrawRect(x, y, thickness, length)
	surface.DrawRect(x + w - length, y, length, thickness)
	surface.DrawRect(x + w - thickness, y, thickness, length)
	surface.DrawRect(x, y + h - thickness, length, thickness)
	surface.DrawRect(x, y + h - length, thickness, length)
	surface.DrawRect(x + w - length, y + h - thickness, length, thickness)
	surface.DrawRect(x + w - thickness, y + h - length, thickness, length)
end

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_widgets.lua")

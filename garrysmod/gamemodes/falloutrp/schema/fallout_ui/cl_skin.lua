--[[
	Fallout UI - Helix skin override.

	Helix registers one derma skin, "helix", and every panel it ships paints
	through it. Rather than rewriting all thirty of Helix's derma files, this
	reaches into that skin table after Helix has loaded and replaces the paint
	functions with Fallout ones.

	The effect is that the F1 menu, inventory, character creation, character
	load, scoreboard, chatbox, tooltips, scrollbars, comboboxes and settings
	rows all restyle at once - and Helix itself stays unforked, so updating it
	does not clobber our work.

	The look follows Phoenix: a dark translucent fill, a one-pixel palette
	outline, clipped corners via surface.DrawEdgedBox, and inverted (solid fill,
	dark text) highlights the way a Pip-Boy renders selection.
]]

--[[
	Declared here as well as in `cl_theme.lua`, so this file is true on
	its own. These are included in a fixed order by `sh_schema.lua` and
	the theme comes first - but a file that only works because of the
	order it happens to be listed in is one edit away from an error at
	file scope, and one of those takes a whole directory with it.
]]
ix.fallout = ix.fallout or {}

local SKIN = derma.SkinList and derma.SkinList["helix"]

if (not SKIN) then
	ErrorNoHalt("[falloutrp] Helix skin not found - Fallout UI skin not applied\n")
	return
end

ix.option.Add("falloutScanlines", ix.type.bool, true, {
	category = "appearance"
})

local gradient = surface.GetTextureID("vgui/gradient-d")
local gradientUp = surface.GetTextureID("vgui/gradient-u")
local gradientLeft = surface.GetTextureID("vgui/gradient-l")

--[[
	Corner cut, in pixels.

	Applied to LEAF widgets only - buttons, combo boxes, text entries, tooltips.

	NOT to containers. A clipped corner cuts diagonally across the panel's edge,
	but anything docked inside is square and full-width, so the child's corner
	sticks out through the cut. That is what makes category panels, settings
	rows and config sections look like they spill outside their own frame.

	Phoenix does not clip container corners either - they bracket them.
]]
local EDGE = 8
local CONTAINER_EDGE = 0

local colorFill = Color(0, 0, 0, 215)
local colorFillLight = Color(0, 0, 0, 110)

--[[
	Scanlines. Cheap - one DrawRect every fourth row, clipped to the panel.
	Optional, because it is a taste thing and it is the only per-frame cost the
	skin adds.
]]
local function DrawScanlines(width, height, alpha)
	if (not ix.option.Get("falloutScanlines", true)) then return end

	surface.SetDrawColor(0, 0, 0, alpha or 14)

	for y = 0, height, 4 do
		surface.DrawRect(0, y, width, 1)
	end
end

ix.fallout.DrawScanlines = DrawScanlines

--- The standard Fallout panel body: fill, clipped-corner outline, scanlines.
local function DrawPanelBody(width, height, fillColor, outlineColor, edge)
	local palette = ix.fallout.GetPalette()

	edge = edge or CONTAINER_EDGE

	surface.DrawEdgedBox(0, 0, width, height, 1, edge, edge, edge, edge,
		outlineColor or palette.color_outline, fillColor or colorFill)

	DrawScanlines(width, height)
end

ix.fallout.DrawPanelBody = DrawPanelBody

--[[
	Palette-driven skin colours.

	Helix reads SKIN.Colours for label and button text, so these have to track
	the palette rather than being set once.
]]
local function ApplySkinColours(palette)
	SKIN.Colours.Label.Default = palette.color_primary
	SKIN.Colours.MenuLabel = palette.color_primary

	SKIN.Colours.Button.Normal = palette.color_primary
	SKIN.Colours.Button.Hover = palette.color_primary
	SKIN.Colours.Button.Down = palette.color_active
	SKIN.Colours.Button.Disabled = palette.color_active

	-- The title strip is filled solid primary, so its text has to be dark.
	-- Leaving this as the primary colour is what made frame titles invisible.
	SKIN.Colours.Window.TitleActive = color_black
	SKIN.Colours.Window.TitleInactive = palette.color_active

	SKIN.Colours.Area.Background = palette.color_background
	SKIN.Colours.SegmentedProgress.Bar = palette.color_active
	SKIN.Colours.SegmentedProgress.Text = palette.color_primary
end

hook.Add("FalloutPaletteChanged", "ixFalloutSkin", ApplySkinColours)
ApplySkinColours(ix.fallout.GetPalette())

SKIN.fontCategory = "UI_Regular"
SKIN.fontCategoryBlur = "UI_Regular_Blur"
SKIN.fontSegmentedProgress = "UI_Regular"

--[[
	Frames and panels.
]]
function SKIN:PaintFrame(panel)
	local palette = ix.fallout.GetPalette()
	local width, height = panel:GetSize()

	if (not panel.bNoBackgroundBlur) then
		ix.util.DrawBlur(panel, 10)
	end

	DrawPanelBody(width, height)

	if (panel:GetTitle() ~= "" or (panel.btnClose and panel.btnClose:IsVisible())) then
		-- Title strip: solid palette bar with dark text, Pip-Boy style.
		surface.DrawEdgedBox(0, 0, width, 24, 0, CONTAINER_EDGE, CONTAINER_EDGE,
			0, 0, nil, palette.color_primary)

		surface.SetDrawColor(palette.color_outline)
		surface.DrawRect(0, 24, width, 1)
	end
end

function SKIN:PaintBaseFrame(panel, width, height)
	if (not panel.bNoBackgroundBlur) then
		ix.util.DrawBlur(panel, 10)
	end

	DrawPanelBody(width, height)
end

function SKIN:PaintPanel(panel)
	if (not panel.m_bBackground) then return end

	local width, height = panel:GetSize()
	local palette = ix.fallout.GetPalette()

	surface.DrawEdgedBox(0, 0, width, height, 1, CONTAINER_EDGE, CONTAINER_EDGE,
		CONTAINER_EDGE, CONTAINER_EDGE, palette.color_active,
		panel.m_bgColor or colorFillLight)
end

function SKIN:DrawImportantBackground(x, y, width, height, color)
	color = color or ix.fallout.GetPalette().color_background

	surface.SetTexture(gradientLeft)
	surface.SetDrawColor(color)
	surface.DrawTexturedRect(x, y, width, height)
end

function SKIN:PaintMenuBackground(panel, width, height, alphaFraction)
	alphaFraction = alphaFraction or 1

	local palette = ix.fallout.GetPalette()

	--[[
		BLUR FIRST. ix.util.DrawBlur redraws the blurred world on top of whatever
		is already on the panel, so dimming and then blurring undoes the dim.
		Helix blurs last here, which is why a bright map washes the menu out.
	]]
	ix.util.DrawBlur(panel, alphaFraction * 15, nil, 255)

	surface.SetDrawColor(0, 0, 0, alphaFraction * 215)
	draw.NoTexture()
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(0, 0, 0, alphaFraction * 90)
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(0, 0, width, height)

	-- No colour wash here either. Tinting a fullscreen backdrop amber is what
	-- made the menu read as a sepia photograph rather than a dark screen.
	DrawScanlines(width, height, alphaFraction * 14)
end

function SKIN:PaintCategoryPanel(panel, text, color)
	text = text or ""

	local palette = ix.fallout.GetPalette()

	color = color or palette.color_primary

	surface.SetFont(self.fontCategory)

	local textHeight = select(2, surface.GetTextSize(text)) + 6
	local width, height = panel:GetSize()

	-- Square: the settings and config rows docked inside are full-width, and a
	-- clipped corner here is what they appear to spill through.
	surface.DrawEdgedBox(0, 0, width, height, 1, CONTAINER_EDGE, CONTAINER_EDGE,
		CONTAINER_EDGE, CONTAINER_EDGE, color, colorFill)

	surface.DrawEdgedBox(0, 0, width, textHeight, 0, CONTAINER_EDGE, CONTAINER_EDGE,
		0, 0, nil, color)

	surface.SetTextColor(0, 0, 0)
	surface.SetTextPos(6, 3)
	surface.DrawText(text)

	return 1, textHeight, 1, 1
end

--[[
	Buttons. Fallout inverts on hover rather than lightening.
]]
function SKIN:PaintButton(panel)
	if (not panel.m_bBackground) then return end

	local palette = ix.fallout.GetPalette()
	local w, h = panel:GetWide(), panel:GetTall()

	if (panel:GetDisabled()) then
		surface.DrawEdgedBox(0, 0, w, h, 1, EDGE, EDGE, EDGE, EDGE,
			palette.color_active, colorFillLight)

		return
	end

	-- NOTE: derma sets button text from SKIN.Colours.Button.*, which is the
	-- palette colour. Filling the background solid primary therefore renders
	-- primary text on a primary field - invisible. Highlights are translucent
	-- for exactly that reason; the outline carries the state instead.
	if (panel.Depressed or (panel.IsSelected and panel:IsSelected())) then
		surface.DrawEdgedBox(0, 0, w, h, 1, EDGE, EDGE, EDGE, EDGE,
			palette.color_primary, ColorAlpha(palette.color_primary, 90))
	elseif (panel.Hovered) then
		surface.DrawEdgedBox(0, 0, w, h, 1, EDGE, EDGE, EDGE, EDGE,
			palette.color_primary, ColorAlpha(palette.color_primary, 45))
	else
		surface.DrawEdgedBox(0, 0, w, h, 1, EDGE, EDGE, EDGE, EDGE,
			palette.color_active, colorFillLight)
	end
end

--[[
	Tooltips, lists, rows.
]]
function SKIN:PaintTooltipBackground(panel, width, height)
	ix.util.DrawBlur(panel, 1)

	DrawPanelBody(width, height, colorFill, ix.fallout.GetPalette().color_active, 4)
end

function SKIN:PaintEntityInfoBackground(panel, width, height)
	ix.util.DrawBlur(panel, 1)

	DrawPanelBody(width, height, colorFill, ix.fallout.GetPalette().color_active, 4)
end

function SKIN:PaintListRow(panel, width, height)
	surface.SetDrawColor(0, 0, 0, 150)
	draw.NoTexture()
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(ix.fallout.GetPalette().color_active)
	surface.DrawRect(0, height - 1, width, 1)
end

function SKIN:PaintAreaEntry(panel, width, height)
	local palette = ix.fallout.GetPalette()
	local color = panel:GetBackgroundColor() or palette.color_background

	self:DrawImportantBackground(0, 0, width, height,
		ColorAlpha(color, panel:GetBackgroundAlpha()))
end

function SKIN:PaintSettingsRowBackground(panel, width, height)
	local palette = ix.fallout.GetPalette()

	if (panel:GetBackgroundIndex() == 0) then
		surface.SetDrawColor(palette.color_primary.r, palette.color_primary.g,
			palette.color_primary.b, 12)
		surface.DrawRect(0, 0, width, height)
	end

	if (panel:GetShowReset()) then
		surface.SetDrawColor(self.Colours.Warning)
		surface.DrawRect(0, 0, 2, height)
	end
end

--[[
	Menus and comboboxes.
]]
function SKIN:PaintMenu(panel, width, height)
	ix.util.DrawBlur(panel)

	DrawPanelBody(width, height, colorFill, ix.fallout.GetPalette().color_outline, 4)
end

function SKIN:PaintMenuOption(panel, width, height)
	if (not panel.m_bBackground) then return end

	if (panel.Hovered or panel.Highlight) then
		-- Translucent, not solid: menu option text is MenuLabel (the palette
		-- colour) and derma will not repaint it dark for us.
		surface.SetDrawColor(ColorAlpha(ix.fallout.GetPalette().color_primary, 60))
		surface.DrawRect(0, 0, width, height)
	end
end

function SKIN:PaintComboBox(panel, width, height)
	local palette = ix.fallout.GetPalette()

	surface.DrawEdgedBox(0, 0, width, height, 1, 4, 4, 4, 4,
		panel.Hovered and palette.color_primary or palette.color_active, colorFillLight)
end

function SKIN:PaintComboDownArrow(panel, width, height)
	surface.SetFont("ixIconsSmall")

	local palette = ix.fallout.GetPalette()
	local textWidth, textHeight = surface.GetTextSize("r")
	local alpha = (panel.ComboBox:IsMenuOpen() or panel.ComboBox.Hovered) and 255 or 140

	surface.SetTextColor(ColorAlpha(palette.color_primary, alpha))
	surface.SetTextPos(width * 0.5 - textWidth * 0.5, height * 0.5 - textHeight * 0.5)
	surface.DrawText("r")
end

--[[
	Scrollbars. Helix leaves the track empty and paints only the grip.
]]
function SKIN:PaintScrollBarGrip(panel, width, height)
	local palette = ix.fallout.GetPalette()
	local parent = panel:GetParent()
	local color = panel.Hovered and palette.color_primary or palette.color_active

	surface.SetDrawColor(color)

	if (IsValid(parent.btnUp)) then
		local up = parent.btnUp:GetTall()
		local down = parent.btnDown:GetTall()

		DisableClipping(true)
			surface.DrawRect(width * 0.5 - 2, -up, 4, height + up + down)
		DisableClipping(false)
	else
		local left = parent.btnLeft:GetWide()
		local right = parent.btnRight:GetWide()

		DisableClipping(true)
			surface.DrawRect(-left, height * 0.5 - 2, width + left + right, 4)
		DisableClipping(false)
	end
end

--[[
	Progress, sliders, bars.
]]
--[[
	The creation progress bar.

	Helix draws one continuous fill across the whole bar plus the segment names
	in a single colour, so it shows how FAR you are but not WHICH steps are
	behind you - at a glance every label looks the same.

	This draws it as discrete cells: completed steps filled in the dimmer
	accent, the current step filled in the bright one, upcoming steps left
	empty. The label inverts to the background colour on a filled cell, which is
	what makes a finished step readable as finished.

	`GetFraction` is Helix's animated 0-1 value and `GetProgress` is the integer
	step. Both are used: the integer decides each cell's STATE, the fraction
	clips the leading edge, so the fill still slides between steps instead of
	snapping.
]]
function SKIN:PaintSegmentedProgress(panel, width, height)
	local palette = ix.fallout.GetPalette()
	local font = panel:GetFont() or self.fontSegmentedProgress
	local segments = panel:GetSegments()
	local count = #segments

	if (count < 1) then return end

	local cell = width / count
	local progress = panel:GetProgress() or 0
	local edge = (panel:GetFraction() or 0) * width

	draw.NoTexture()

	for i = 1, count do
		local x = (i - 1) * cell
		local current = i == progress

		if (i <= progress) then
			-- Clipped to the animation, so a step fills as you arrive on it.
			local right = math.min(x + cell, edge)

			if (right > x) then
				surface.SetDrawColor(current and palette.color_primary or palette.color_active)
				surface.DrawRect(x, 0, right - x, height)
			end
		end

		if (i > 1) then
			surface.SetDrawColor(palette.color_outline)
			surface.DrawRect(x, 0, 1, height)
		end
	end

	surface.SetDrawColor(palette.color_outline)
	surface.DrawOutlinedRect(0, 0, width, height)

	--[[
		Text last, over every fill. Colour comes from the STEP, not the
		animation - a label that changed colour partway through the slide reads
		as a glitch rather than as progress.

		NOT `color_background` for the filled cells. That is a deliberately
		TRANSLUCENT colour - the amber palette's is Color(98, 76, 16, 102) -
		so using it as a text colour over a bright fill gives washed-out olive
		on amber rather than dark on light. Filled cells get a solid near-black
		instead, which is legible against every palette's accent.
	]]
	local onFill = Color(12, 11, 8)

	for i = 1, count do
		local done = i <= progress

		draw.SimpleText(segments[i], font,
			(i - 1) * cell + cell * 0.5, height * 0.5,
			done and onFill or palette.color_active,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function SKIN:PaintHelixSlider(panel, width, height)
	local palette = ix.fallout.GetPalette()

	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawRect(0, 0, panel:GetVisualFraction() * width, height)

	surface.SetDrawColor(palette.color_outline)
	surface.DrawOutlinedRect(0, 0, width, height)
end

function SKIN:PaintInfoBar(panel, width, height, color)
	surface.SetDrawColor(color.r, color.g, color.b, 250)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(230, 230, 230, 8)
	surface.SetTexture(gradientUp)
	surface.DrawTexturedRect(0, 0, width, height)
end

function SKIN:PaintInfoBarBackground(panel, width, height)
	local palette = ix.fallout.GetPalette()

	surface.SetDrawColor(0, 0, 0, 170)
	draw.NoTexture()
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(palette.color_active)
	surface.DrawOutlinedRect(0, 0, width, height)

	panel.bar:PaintManual()

	DisableClipping(true)
		panel.label:PaintManual()
	DisableClipping(false)
end

--[[
	Inventory.
]]
function SKIN:PaintInventorySlot(panel, width, height)
	local palette = ix.fallout.GetPalette()

	-- Near-opaque. At 140 the slots let the map through, so an inventory over a
	-- bright sky reads as a blue grid rather than a dark one.
	surface.SetDrawColor(0, 0, 0, 225)
	surface.DrawRect(1, 1, width - 2, height - 2)

	surface.SetDrawColor(palette.color_active)
	surface.DrawOutlinedRect(1, 1, width - 2, height - 2)
end

--[[
	Character menu backgrounds.
]]
--[[
	Character creation and load backgrounds.

	Phoenix does NOT cover the screen here - their faction select and character
	list sit as panels over the LIVE MAP, which stays clearly visible.

	A previous pass drew a full-screen gradient plus a palette wash. Two things
	went wrong with it: it buried the map, and because `surface.DrawRect` uses
	whatever texture is currently bound, the wash after `SetTexture(gradient)`
	drew as an amber GRADIENT rather than a flat tint. Between them that is what
	turned the whole creation flow olive.

	Light dim only. The panels carry the contrast.
]]
function SKIN:PaintCharacterCreateBackground(panel, width, height)
	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 90)
	surface.DrawRect(0, 0, width, height)
end

function SKIN:PaintCharacterLoadBackground(panel, width, height)
	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, panel:GetBackgroundFraction() * 90)
	surface.DrawRect(0, 0, width, height)
end

function SKIN:PaintCharacterTransitionOverlay(panel, x, y, width, height, color)
	surface.SetDrawColor(color or ix.fallout.GetPalette().color_primary)
	surface.DrawRect(x, y, width, height)
end

--[[
	Chatbox.
]]
function SKIN:PaintChatboxBackground(panel, width, height)
	local palette = ix.fallout.GetPalette()

	ix.util.DrawBlur(panel, 10)

	-- Chat has to stay readable over a bright world, so this is a good deal
	-- more opaque than the other panels.
	surface.DrawEdgedBox(0, 0, width, height, 1, 4, 4, 4, 4,
		palette.color_outline, Color(0, 0, 0, 225))

	-- Helix fades the palette colour in behind the tab strip while the box is
	-- open. Dropping panel:GetActive() lost that entirely.
	if (panel:GetActive()) then
		surface.SetDrawColor(ColorAlpha(palette.color_primary, 120))
		surface.SetTexture(gradientUp)
		surface.DrawTexturedRect(0, panel.tabs.buttons:GetTall(), width, height * 0.25)
	end

	DrawScanlines(width, height)
end

function SKIN:PaintChatboxEntry(panel, width, height)
	local palette = ix.fallout.GetPalette()

	surface.DrawEdgedBox(0, 0, width, height, 1, 4, 4, 4, 4,
		palette.color_primary, Color(0, 0, 0, 200))

	--[[
		This line is why you can type at all.

		Helix's ixChatboxEntry overrides DTextEntry:Paint completely and never
		calls DrawTextEntryText itself - the skin function is what draws the
		text, the selection highlight and the caret. Omitting it does not throw
		an error; the entry just silently renders nothing you type.

		Arguments are (textColour, highlightColour, caretColour).
	]]
	panel:DrawTextEntryText(palette.color_primary, palette.color_active, palette.color_primary)
end

function SKIN:PaintChatboxAutocompleteEntry(panel, width, height)
	local palette = ix.fallout.GetPalette()

	-- Helix animates this through panel.highlightAlpha; GetSelected does not
	-- exist on this panel, so keying off it meant it never highlighted.
	if ((panel.highlightAlpha or 0) > 0) then
		self:DrawImportantBackground(0, 0, width, height,
			ColorAlpha(palette.color_primary, panel.highlightAlpha * 90))
	end

	surface.SetDrawColor(palette.color_active)
	draw.NoTexture()
	surface.DrawRect(0, height - 1, width, 1)
end

function SKIN:PaintChatboxTabButton(panel, width, height)
	local palette = ix.fallout.GetPalette()

	if (panel:GetActive()) then
		-- Active tab reads as selected through a translucent wash plus a solid
		-- underline. Helix fills this solid and relies on white button text;
		-- our button text is the palette colour, so a solid fill would hide it.
		surface.SetDrawColor(ColorAlpha(palette.color_primary, 55))
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(palette.color_primary)
		surface.DrawRect(0, height - 2, width, 2)
	else
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(0, 0, width, height)

		-- Unread indicator. Dropping this was a silent feature loss.
		if (panel:GetUnread()) then
			surface.SetDrawColor(ColorAlpha(self.Colours.Warning,
				Lerp(panel.unreadAlpha, 0, 100)))
			surface.SetTexture(gradient)
			surface.DrawTexturedRect(0, 0, width, height - 1)
		end

		surface.SetDrawColor(palette.color_active)
		draw.NoTexture()
		surface.DrawRect(0, height - 1, width, 1)
	end

	surface.SetDrawColor(color_black)
	surface.DrawRect(width - 1, 0, 1, height)
end

--[[
	Death screen. Phoenix tints this red; keeping that, it reads as damage
	rather than as a menu.
]]
function SKIN:PaintDeathScreenBackground(panel, width, height, progress)
	surface.SetDrawColor(0, 0, 0, math.min((progress / 0.3) * 255, 255))
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(80, 0, 0, math.min((progress / 0.3) * 60, 60))
	surface.DrawRect(0, 0, width, height)
end

--[[
	Accent colour bridge.

	The skin above only reaches panels that paint through derma's skin
	dispatch - stock DFrame, DButton, DMenu, DComboBox, scrollbars and the
	handful of places Helix calls a SKIN function explicitly.

	Most of Helix's OWN panels (notices, the F1 menu and its buttons, inventory,
	scoreboard, character load, settings rows, tooltips) define their own Paint
	and take their accent from ix.config.Get("color") - 35 call sites across the
	gamemode. Overriding that single getter is what carries the Pip-Boy colour
	into all of them, and it is why this file does not need to touch any of
	Helix's derma.

	Clientside only, so the server's stored config value, its replication and
	the admin config menu are all untouched. This only changes what the local
	player's UI reads when it asks for the accent colour.
]]
if (not ix.fallout.configPatched) then
	ix.fallout.configPatched = true

	local configGet = ix.config.Get

	function ix.config.Get(key, default)
		if (key == "color") then
			local palette = ix.fallout.GetPalette()

			if (palette.color_primary) then
				return palette.color_primary
			end
		end

		return configGet(key, default)
	end
end

-- Anything that caches the accent colour rather than reading it per frame
-- listens on this hook, so a palette change has to re-fire it.
hook.Add("FalloutPaletteChanged", "ixFalloutColorScheme", function(palette)
	hook.Run("ColorSchemeChanged", palette.color_primary)

	-- Helix's own ColorSchemeChanged listener sets Area.Background to the
	-- accent colour. That runs after ours, so restore the background shade.
	SKIN.Colours.Area.Background = palette.color_background
end)

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_skin.lua")

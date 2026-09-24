--[[
	Fallout UI - Helix panel restyling.

	Helix registers its panels with `vgui.Register`, and `vgui.GetControlTable`
	hands back the same table. Patching that table restyles every instance of
	the panel without reimplementing its data logic and without forking Helix.

	WHY WRAPPING, NOT REPLACING
	---------------------------
	Helix's panel methods routinely do FUNCTIONAL work alongside their drawing:
	`ixNotice:Paint` sets a scissor rect and runs the panel's own hover
	detection; `ixItemIcon:Paint` dispatches to `ExtraPaint`. Replacing such a
	method wholesale silently deletes that behaviour - no error, the feature
	just stops. That is exactly how a dropped `DrawTextEntryText` turned into
	"the chatbox won't let me type" (see 16-ui.md).

	So the default here is `Wrap`, which calls the original first and draws on
	top. `Replace` is used only where the original is verifiably nothing but
	drawing, and each use says so.
]]

ix.fallout = ix.fallout or {}

-- What actually got patched, for `fo_ui_report`. This matters because a missing
-- panel class fails quietly at the feature level: the UI just renders stock,
-- with no error to point at.
ix.fallout.patched = {}
ix.fallout.patchFailed = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

local function GetTable(class)
	local tbl = vgui.GetControlTable(class)

	if (not tbl) then
		ix.fallout.patchFailed[class] = true

		ErrorNoHalt(string.format(
			"[falloutrp] panel class '%s' not found - Fallout restyle skipped for it\n", class))
	end

	return tbl
end

--- Call the original, then ours. Safe by construction.
function ix.fallout.WrapPanel(class, method, fn)
	local tbl = GetTable(class)

	if (not tbl) then return end

	ix.fallout.patched[class .. ":" .. method] = "wrapped"

	local original = tbl[method]

	tbl[method] = function(panel, ...)
		if (original) then
			original(panel, ...)
		end

		return fn(panel, ...)
	end
end

--- Replace outright. Only for methods that are pure drawing.
function ix.fallout.ReplacePanel(class, method, fn)
	local tbl = GetTable(class)

	if (not tbl) then return end

	ix.fallout.patched[class .. ":" .. method] = "replaced"
	tbl[method] = fn
end

local Wrap, Replace = ix.fallout.WrapPanel, ix.fallout.ReplacePanel

--------------------------------------------------------------------------------
-- F1 menu buttons, and the character menu buttons that share the class
--------------------------------------------------------------------------------

-- Init only sets up fonts and colours, but wrapping costs nothing and keeps
-- Helix's padding and accessor setup intact.
Wrap("ixMenuButton", "Init", function(panel)
	-- Marker so cl_creation can find these without relying on how the engine
	-- names a scripted panel - GetClassName returns the ENGINE class.
	panel.ixIsMenuButton = true

	panel:SetFont("UI_Bold")
	panel:SetTextColor(ix.fallout.GetPalette().text_primary)
	panel:SetExpensiveShadow(1, color_black)
end)

--[[
	PaintBackground is pure drawing in Helix - a single translucent DrawRect -
	so replacing it is safe. `currentBackgroundAlpha` is animated by Helix on
	hover, and using it as the driver keeps that animation rather than
	snapping.
]]
Replace("ixMenuButton", "PaintBackground", function(panel, width, height)
	local palette = ix.fallout.GetPalette()
	local fraction = math.Clamp((panel.currentBackgroundAlpha or 0) / 128, 0, 1)

	if (fraction <= 0) then return end

	-- Wash plus a solid leading edge: the Fallout selection cue, and readable
	-- because the fill never reaches the text colour's opacity.
	surface.SetDrawColor(ColorAlpha(palette.color_primary, fraction * 55))
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(ColorAlpha(palette.color_primary, fraction * 255))
	surface.DrawRect(0, 0, math.Round(3 * ix.fallout.GetFontScale()), height)
end)

--------------------------------------------------------------------------------
-- Inventory
--------------------------------------------------------------------------------

--[[
	Helix's ixItemIcon:Paint is a dark rect plus a call to ExtraPaint. ExtraPaint
	is Helix's own extension point and exists precisely so schemas can draw
	here, so this replaces Paint but keeps dispatching to it.
]]
Replace("ixItemIcon", "Paint", function(panel, width, height)
	local palette = ix.fallout.GetPalette()
	local item = panel.itemTable
	local equipped = item and item.GetData and item:GetData("equip", false)

	surface.SetDrawColor(0, 0, 0, 190)
	surface.DrawRect(1, 1, width - 2, height - 2)

	-- Equipped items get a filled corner flag rather than a full border, so a
	-- grid of them still reads as a grid.
	if (equipped) then
		surface.SetDrawColor(ColorAlpha(palette.color_primary, 30))
		surface.DrawRect(1, 1, width - 2, height - 2)
	end

	surface.SetDrawColor(equipped and palette.color_primary or palette.color_active)
	surface.DrawOutlinedRect(1, 1, width - 2, height - 2)

	if (panel.Hovered) then
		surface.SetDrawColor(ColorAlpha(palette.color_primary, 40))
		surface.DrawRect(1, 1, width - 2, height - 2)
	end

	panel:ExtraPaint(width, height)
end)

--[[
	Item labels. Phoenix prints the name across the bottom of the icon and marks
	equipped items; Helix shows the name only in a tooltip, which means an
	inventory of similar models is unreadable at a glance.

	Wrapped, because Helix's PaintOver dispatches to the item's own paintOver.
]]
Wrap("ixItemIcon", "PaintOver", function(panel, width, height)
	local item = panel.itemTable

	if (not item) then return end

	local palette = ix.fallout.GetPalette()

	if (item.GetData and item:GetData("equip", false)) then
		local size = math.Round(6 * ix.fallout.GetFontScale())

		surface.SetDrawColor(palette.color_primary)
		surface.DrawRect(width - size - 2, 2, size, size)
	end

	-- Name strip, only on icons big enough to carry it legibly.
	if (height < 48) then return end

	local name = item.GetName and item:GetName() or item.name

	if (not name) then return end

	surface.SetFont("UI_InvLabel")

	local textW, textH = surface.GetTextSize(name)

	while (textW > width - 6 and #name > 3) do
		name = name:sub(1, #name - 2)
		textW = surface.GetTextSize(name .. "..")
	end

	if (textW < surface.GetTextSize(item.GetName and item:GetName() or item.name)) then
		name = name .. ".."
	end

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(1, height - textH - 3, width - 2, textH + 2)

	draw.SimpleText(name, "UI_InvLabel", width * 0.5, height - 2,
		palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end)

--[[
	Inventory frame.

	Helix hardcodes iconSize 64. Two problems with that: it is a small grid at
	1440p and a tiny one at 4K, and even at 1080p it leaves the inventory
	rattling around in the top-left of the menu page rather than filling it the
	way Phoenix's does.

	Scaled, and tunable - the right size depends on the grid dimensions the
	schema settles on, which is not decided yet.
]]
--[[
	Fallback slot size, for inventories that are NOT fitted to a container -
	storage containers, bags, anything opened outside the menu. The menu's own
	inventory is sized by FitParent further down, so this no longer has to be
	inflated to make that one fill its page.
]]
local cvarIconSize = CreateClientConVar("fo_inv_iconsize", "50", true, false,
	"Slot size at 1080p for inventories that are not fitted to their container.")

Wrap("ixInventory", "Init", function(panel)
	local size = math.Clamp(cvarIconSize:GetInt(), 32, 256)

	panel:SetIconSize(math.Round(size * ix.fallout.GetFontScale()))
end)

--[[
	The storage view, sized to the screen.

	`ixInventory` uses `fo_inv_iconsize` (72 at 1080p, scaled), which is right
	for one inventory filling a menu page and far too big for TWO side by side:
	an 8x6 storage next to a 10x7 inventory at that size is wider than the
	screen, and Helix does not check - `SetGridSize` sets whatever the grid
	comes to and the panels simply run off the edge.

	So the icon size is recomputed from what is actually available, and only
	ever DOWNWARDS: a small pair of inventories keeps the size the player chose
	rather than being stretched to fill the screen.

	Wrapped on `SetStorageInventory` because that is the last of the three
	calls `ix.storage` makes - local inventory, then id and title, then this -
	so it is the first moment both grids are known.
]]
local function FitStorageView(view)
	local storage = view.storageInventory
	local local_ = ix.gui.inv1

	if (not IsValid(storage) or not IsValid(local_)) then return end
	if (not storage.gridW or not local_.gridW) then return end

	local margin = (view.GetFrameMargin and view:GetFrameMargin()) or 4
	local columns = math.max(storage.gridW, local_.gridW)
	local rows = math.max(storage.gridH, local_.gridH)

	--[[
		Half the screen each, less the margin between them and a little for the
		title bar and the frame. The height allowance is the smaller of the two
		limits in practice, which is why both are computed rather than assuming
		width is the tight one.
	]]
	local available = (ScrW() - margin * 4) * 0.5
	local size = math.min(
		storage:GetIconSize(),
		math.floor(available / columns),
		math.floor((ScrH() * 0.82 - 48) / rows)
	)

	if (size >= storage:GetIconSize()) then return end

	size = math.max(size, 24)

	for _, panel in ipairs({storage, local_}) do
		panel:SetIconSize(size)
		panel:SetGridSize(panel.gridW, panel.gridH)
	end

	--[[
		Repositioned after resizing, because both were centred against the size
		they used to be - Helix positions them inside the same call that sets
		the inventory, and there is no layout pass afterwards to correct it.
	]]
	storage:SetPos(view:GetWide() / 2 - storage:GetWide() - margin / 2,
		view:GetTall() / 2 - storage:GetTall() / 2)

	local_:SetPos(view:GetWide() / 2 + margin / 2,
		view:GetTall() / 2 - local_:GetTall() / 2)
end

Wrap("ixStorageView", "SetStorageInventory", function(panel)
	FitStorageView(panel)
end)

--------------------------------------------------------------------------------
-- The look-at tooltip
--------------------------------------------------------------------------------

--[[
	KEEP IT NEXT TO WHAT YOU ARE LOOKING AT.

	Helix positions the entity tooltip from the far EDGE of the entity's
	bounding box:

	    self:SetPos(
	        math.Clamp(math.max(min, max), ScrW() * 0.5 + 64, ScrW() - self:GetWide()),
	        ScrH() * 0.5 - self:GetTall() * 0.5)

	`min` and `max` are the box's left and right edges projected onto the
	screen, so the closer you stand to something the further right the label
	goes - and a workbench you are standing at fills the view, which pins the
	label to the right-hand edge of the monitor with a tracer line running the
	whole way across. It is correct, and it is unreadable.

	This puts it a fixed distance from the entity's CENTRE instead, flipping to
	the left when there is no room on the right, and clamped to stay on screen.
	The arrow still draws to the entity, so the line is now short.

	Wrapped rather than replaced: Helix's `Think` also drives cursor tooltips
	and the raised-weapon position, and both are left exactly as they were -
	this only moves the case where you are looking at something.
]]
Wrap("ixTooltip", "Think", function(panel)
	if (not panel.bEntity or panel.bClosing or panel.bRaised) then return end

	local entity = panel.entity

	if (not IsValid(entity)) then return end

	local screen = entity:LocalToWorld(entity:OBBCenter()):ToScreen()

	--[[
		Not visible means behind the camera, where `ToScreen` answers with
		coordinates that are mirrored rather than off-screen. Helix's own
		position is left alone in that case; it is a moment long, since you are
		by definition not looking at the thing.
	]]
	if (not screen.visible) then return end

	local width, height = panel:GetSize()
	local margin = Scaled(8)
	local gap = Scaled(48)
	local x = screen.x + gap

	--- Flipped to the other side when it would run off the edge.
	if (x + width > ScrW() - margin) then
		x = screen.x - gap - width
	end

	panel:SetPos(
		math.Clamp(x, margin, math.max(ScrW() - width - margin, margin)),
		math.Clamp(screen.y - height * 0.5, margin,
			math.max(ScrH() - height - margin, margin)))
end)

--------------------------------------------------------------------------------
-- Notices
--------------------------------------------------------------------------------

--[[
	Wrapped, NOT replaced: Helix's ixNotice:Paint sets a scissor rect for the
	dismiss animation and runs its own mouse-hover detection. Replacing it
	would break both, silently.

	A left accent bar rather than brackets, for two reasons: the panel's own
	timer bar already occupies the bottom edge, and the scissor rect would clip
	anything drawn outside the bounds anyway.

	The font is deliberately left alone - ixNotice sizes itself from its font
	through SizeToContents, so changing it resizes every notice.
]]
Wrap("ixNotice", "Paint", function(panel, width, height)
	local color = panel.bError and derma.GetColor("Error", panel)
		or ix.fallout.GetPalette().color_primary

	surface.SetDrawColor(color)
	surface.DrawRect(0, 0, math.Round(3 * ix.fallout.GetFontScale()), height)
end)

--------------------------------------------------------------------------------
-- Character carousel
--------------------------------------------------------------------------------

--[[
	The carousel arrows and slot buttons are ixMenuButton instances, so they are
	already covered above. What is left is the model panel backdrop, which
	Helix leaves plain.
]]
Wrap("ixCharMenuCarousel", "Paint", function(panel, width, height)
	ix.fallout.DrawBrackets(width, height, nil, 2)
end)

--------------------------------------------------------------------------------
-- Palette changes
--------------------------------------------------------------------------------

-- Menu buttons cache their text colour, so recolour any that are live.
hook.Add("FalloutPaletteChanged", "ixFalloutPanels", function(palette)
	local function Refresh(panel)
		if (not IsValid(panel)) then return end

		if (panel:GetName() == "ixMenuButton" and panel.SetTextColor) then
			panel:SetTextColor(palette.text_primary)
		end

		for _, child in ipairs(panel:GetChildren()) do
			Refresh(child)
		end
	end

	for _, panel in ipairs(vgui.GetWorldPanel():GetChildren()) do
		Refresh(panel)
	end
end)

--------------------------------------------------------------------------------
-- Diagnostic
--------------------------------------------------------------------------------

--[[
	Patching through vgui.GetControlTable fails SILENTLY at the feature level:
	if a class name is wrong, or Helix renames a panel, that panel simply
	renders stock and nothing says so. This prints what actually took.
]]
concommand.Add("fo_ui_report", function()
	local applied, failed = 0, 0
	local accent = Color(255, 199, 44)
	local plain = Color(180, 180, 180)
	local bad = Color(255, 100, 100)

	MsgC(accent, "\n[Fallout UI] Helix panel patches\n")

	for key, kind in SortedPairs(ix.fallout.patched) do
		applied = applied + 1
		MsgC(plain, string.format("  %-38s %s\n", key, kind))
	end

	for class in SortedPairs(ix.fallout.patchFailed) do
		failed = failed + 1
		MsgC(bad, string.format("  %-38s CLASS NOT FOUND\n", class))
	end

	MsgC(accent, string.format("  -> %d applied, %d failed\n\n", applied, failed))

	MsgC(accent, "[Fallout UI] widgets\n")

	for _, class in ipairs({"ixFOPanel", "ixFOPanelBracketed", "ixFOFrame",
		"ixFOButton", "ixFOLabel", "ixFOTextEntry", "ixFOScrollPanel"}) do
		local ok = vgui.GetControlTable(class) ~= nil

		MsgC(ok and plain or bad, string.format("  %-38s %s\n", class, ok and "ok" or "MISSING"))
	end

	MsgC(accent, string.format("\n[Fallout UI] palette '%s', hud '%s', scale %.2f\n",
		ix.fallout.GetPalette().key, ix.option.Get("falloutHud", "nv"),
		ix.fallout.GetFontScale()))

	--[[
		Main menu button column, when it is open.

		Sizing this panel has taken several passes off screenshots. Printing the
		measurement turns "there is extra space" into a number that says which
		part is wrong - the content, the padding, or the panel.
	]]
	local charMenu = ix.gui.characterMenu

	if (IsValid(charMenu) and IsValid(charMenu.mainPanel)
	and IsValid(charMenu.mainPanel.mainButtonList)) then
		local list = charMenu.mainPanel.mainButtonList
		local measured = list.ixMeasured

		MsgC(accent, "\n[Fallout UI] main menu button column\n")
		MsgC(plain, string.format("  %-24s %dx%d at (%d,%d)\n", "panel",
			list:GetWide(), list:GetTall(), list:GetPos()))

		if (measured) then
			MsgC(plain, string.format("  %-24s %d\n", "visible buttons", measured.count))
			MsgC(plain, string.format("  %-24s %d\n", "content height", measured.content))
			MsgC(plain, string.format("  %-24s %d per side\n", "padding", measured.pad))
			MsgC(plain, string.format("  %-24s %d\n", "expected height",
				measured.content + measured.pad * 2))

			--[[
				The check that matters.

				The canvas itself is always at y = 0 - DScrollPanel forces that
				on every layout pass - so the top padding lives on the first
				button's dock margin instead. If this reads 0, the margin is not
				being applied and all the padding piles up below the last button.
			]]
			local firstY = measured.firstY or -1

			MsgC(firstY == measured.pad and plain or bad,
				string.format("  %-24s %d  (should equal padding)\n",
				"first button y", firstY))
		end
	end

	--[[
		Character select, when it is open.

		Included from the start rather than added after several rounds of
		guessing from screenshots, which is how the button column went.
	]]
	if (IsValid(charMenu) and IsValid(charMenu.loadCharacterPanel)) then
		local load = charMenu.loadCharacterPanel
		local list = load.characterList

		MsgC(accent, "\n[Fallout UI] character select\n")

		if (IsValid(list) and IsValid(list:GetParent())) then
			MsgC(plain, string.format("  %-24s %d wide\n", "list column",
				list:GetParent():GetWide()))
		end

		MsgC(IsValid(load.ixHeader) and plain or bad,
			string.format("  %-24s %s\n", "info header",
			IsValid(load.ixHeader) and "present" or "MISSING"))

		local character = load.character

		MsgC(plain, string.format("  %-24s %s\n", "selected character",
			character and character:GetName() or "none"))

		-- The model panel and, more usefully, whether its entity actually
		-- exists - a panel with no Entity renders nothing and looks identical
		-- to a broken Paint.
		local model = load.ixModel

		MsgC(IsValid(model) and plain or bad, string.format("  %-24s %s\n",
			"model panel", IsValid(model) and "present" or "MISSING"))

		if (IsValid(model)) then
			local entity = model.Entity

			MsgC(IsValid(entity) and plain or bad,
				string.format("  %-24s %s\n", "model entity",
				IsValid(entity) and entity:GetModel() or "NONE"))

			--[[
				The sequence the entity is ACTUALLY on, not the one that was
				asked for. A T-pose means it fell back to the reference pose,
				which reads identically to a broken merge in a screenshot.
			]]
			if (IsValid(entity)) then
				local sequence = entity:GetSequence()
				local name = entity:GetSequenceName(sequence)

				MsgC((name and name ~= "" and sequence > 0) and plain or bad,
					string.format("  %-24s %s (%d)\n", "sequence",
					name ~= "" and name or "NONE", sequence))
			end

			-- Framing height, so a cut-off head is a number rather than
			-- something to judge from a screenshot.
			MsgC(model.ixBounds and plain or bad,
				string.format("  %-24s %s\n", "framed height",
				model.ixBounds and math.Round(model.ixBounds) or "NOT MEASURED"))

			MsgC(plain, string.format("  %-24s yaw %d  dist %.2f  rise %.2f\n",
				"framing",
				GetConVar("fo_charpreview_yaw"):GetInt(),
				GetConVar("fo_charpreview_dist"):GetFloat(),
				GetConVar("fo_charpreview_rise"):GetFloat()))

			-- Each merged part, so a missing one is a line rather than
			-- something to spot in a screenshot.
			for i, part in ipairs(model.ixParts or {}) do
				MsgC(IsValid(part) and plain or bad, string.format("  %-24s %s\n",
					"  part " .. i, IsValid(part) and part:GetModel() or "INVALID"))
			end
		end
	end

	MsgC(accent, "\n")
end)

--[[
	Size and centre the menu inventory.

	Helix's inv tab calls `SetInventory(inventory)` with no fit, so the grid
	keeps a fixed icon size and overflows a page smaller than itself.

	`FitParent` is NOT the answer, though it looks like it: it divides the
	parent by the grid dimension, so the grid always consumes an entire axis.
	With a 10x7 inventory that produced enormous slots filling the page edge to
	edge - the opposite of Phoenix, whose grid sits in the middle with clear
	space around it (10 columns of ~64px inside an 896px window).

	So: a fixed slot size, scaled for resolution, shrunk only if the grid would
	not otherwise fit. Then the container is padded to centre it.
]]
-- Session-only while these are still being tuned; a saved value would beat any
-- later change to the default here. See the note in cl_menu.lua.
local cvarMenuIconSize = CreateClientConVar("fo_menu_iconsize", "64", false, false,
	"Menu inventory slot size at 1080p. Scales with resolution.")

hook.Add("MenuSubpanelCreated", "ixFalloutInventoryFit", function(name, container)
	if (name ~= "inv") then return end

	--[[
		INVISIBLE UNTIL IT HAS BEEN PUT WHERE IT GOES.

		This is why the inventory appeared in the top-left corner and jumped to
		the middle every time the menu was opened. The sizing below has to wait
		a frame - the container it is measured against has not been laid out yet
		when this hook runs - and Helix draws the panel during that frame at its
		default position and its default size. The move was never an animation;
		it was one frame of the truth before ours replaced it.

		Alpha rather than `SetVisible`, because a hidden panel is skipped by
		layout and the measurements below would then be taken against a panel
		that has not arranged itself.

		`Reveal` is called on EVERY path out of the timer, including the ones
		that give up: an inventory that stays invisible because the character
		was not loaded yet is a worse bug than the one being fixed. The second
		timer is the backstop for anything that stops the first from running at
		all.
	]]
	local hidden = ix.gui.inv1

	if (IsValid(hidden)) then hidden:SetAlpha(0) end

	local function Reveal()
		if (IsValid(hidden)) then hidden:SetAlpha(255) end
	end

	timer.Simple(0.5, Reveal)

	-- Next frame: the container has not been laid out yet at this point.
	timer.Simple(0, function()
		local panel = ix.gui.inv1
		local canvas = ix.gui.menuInventoryContainer

		if (not IsValid(panel) or not IsValid(canvas) or not IsValid(container)) then
			return Reveal()
		end

		local character = LocalPlayer():GetCharacter()
		local inventory = character and character:GetInventory()

		if (not inventory) then return Reveal() end

		local invWidth, invHeight = inventory:GetSize()

		if (not invWidth or invWidth < 1 or invHeight < 1) then return Reveal() end

		local availW, availH = container:GetSize()
		local scale = ix.fallout.GetFontScale()
		local margin = math.Round(8 * scale)

		-- Fixed size, capped so an unusually large grid still fits.
		local iconSize = math.floor(math.min(
			math.Clamp(cvarMenuIconSize:GetInt(), 24, 160) * scale,
			(availW - margin * 2) / invWidth,
			(availH - margin * 2) / invHeight
		))

		if (iconSize < 8) then return Reveal() end

		-- SetGridSize is Helix's own resize path: it accounts for both dock
		-- paddings, sets the minimum size, and rebuilds the slots. Doing the
		-- arithmetic by hand here would drift from it.
		panel:SetIconSize(iconSize)
		panel:SetGridSize(invWidth, invHeight)
		panel:RebuildItems()

		-- Centre on BOTH axes by padding the container the canvas fills.
		--
		-- Vertical centring does eat the space bags would tile into below the
		-- inventory; they wrap instead, which is the right trade for a grid that
		-- is meant to sit in the middle of the page.
		local padX = math.max(math.floor((availW - panel:GetWide()) * 0.5), 0)
		local padY = math.max(math.floor((availH - panel:GetTall()) * 0.5), margin)

		container:DockPadding(padX, padY, padX, padY)

		-- The canvas takes its size from docking, so the CONTAINER has to lay
		-- out again before the canvas re-tiles - otherwise the padding is set
		-- but the canvas keeps its old width and nothing moves.
		container:InvalidateLayout(true)
		canvas:Layout()

		--[[
			Shown only now, on the frame it is finally in the right place. The
			panel has been sized, the grid rebuilt and the container padded, so
			the first frame anybody sees is the finished one.
		]]
		Reveal()
	end)
end)

--------------------------------------------------------------------------------
-- Character menu
--------------------------------------------------------------------------------

--[[
	Helix's character menu is already arranged the way Phoenix's is - a button
	column at the bottom left over the map:

	    -- Helix, ixCharMenuMain:PerformLayout
	    self.mainButtonList:SetPos(padding, height - list:GetTall() - padding)

	    -- Phoenix, derma/cl_mainmenu.lua
	    menu:SetPos(ScrW() * 0.1, ScrH() - (ScrH() * 0.2 + sH() * 0.45))
	    menu:SetSize(212, sH() * 0.45)

	So this is a restyle, not a rebuild, and the whole creation flow keeps
	working untouched.
]]

--[[
	Backdrop.

	Phoenix leaves the MAP clearly visible behind their character menu - only
	slightly darkened, with the panels carrying the contrast. An earlier pass
	blurred and dimmed at 215 alpha, which buried it, and drew the schema name
	on top of the title Helix's own logo panel already draws.

	Helix's original also has the inverted blur order seen elsewhere: it dims and
	then calls DrawBlur, painting the world back over the dim.
]]
Replace("ixCharMenu", "Paint", function(panel, width, height)
	if (not ix.option.Get("cheapBlur", false)) then
		ix.util.DrawBlur(panel, 4, nil, 255)
	end

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 110)
	surface.DrawRect(0, 0, width, height)
end)

--[[
	Panels.

	Phoenix fills theirs SOLID with `color_background` and brackets the edge -
	that is what makes their menus read as panels over a live map rather than a
	tint over the whole screen. Their `UI_DPanel_Vertical`:

	    surface.SetDrawColor(ColorAlpha(nut.gui.palette.color_background, 200))
	    surface.DrawRect(0, 0, w, h)
	    -- then the bracket rules
]]
function ix.fallout.PaintContainer(panel, width, height)
	if (width <= 0 or height <= 0) then return end

	local background = ix.fallout.GetPalette().color_background

	draw.NoTexture()

	--[[
		OPAQUE base, then the palette tint on top.

		Phoenix's panels read as solid blocks of colour. Drawing only the
		palette background gets close, but `color_background` is a low-alpha
		colour by design (the amber palette's is alpha 102), so even raised to
		235 the map showed through - and against a bright sky with a dark
		building behind it, that read as a gradient rather than a flat panel.
	]]
	surface.SetDrawColor(8, 7, 4, 255)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(background.r, background.g, background.b, 215)
	surface.DrawRect(0, 0, width, height)

	ix.fallout.DrawBrackets(width, height, nil, 0)
end

local PaintFalloutContainer = ix.fallout.PaintContainer

Replace("ixCharMenuButtonList", "Paint", PaintFalloutContainer)

--[[
	Size and place the button column exactly as Phoenix does.

	    menu:SetPos(ScrW() * 0.1, ScrH() - (ScrH() * 0.2 + sH() * 0.45))
	    menu:SetSize(212, sH() * 0.45)
	    menu:DockPadding(12, 32, 12, 32)
	    button:Dock(TOP)  button:DockMargin(0, 0, 0, 12)

	Note their `sH()` with no argument returns 1080, so `sH() * 0.45` is a
	LITERAL 486 pixels, not a fraction of the screen. Written as `sH(486)` here
	so it actually scales with resolution rather than shrinking at 1440p.

	Helix instead sizes this list to the FULL height of its parent and docks the
	canvas to the bottom, so the container covers the entire left edge of the
	screen with the buttons stranded at its foot - which is exactly what it
	looked like.
]]
local function LayoutButtonList(list)
	if (not IsValid(list)) then return end

	--[[
		UNDOCK FIRST.

		Helix does `self.mainButtonList:Dock(LEFT)` in Init and then calls
		SetPos on it in PerformLayout. Docking wins - it re-runs every layout
		pass and overwrites the position - so Helix's own SetPos never took
		effect either, and neither did any set here.
	]]
	list:Dock(NODOCK)

	local padX, padY = Scaled(12), Scaled(24)

	--[[
		Width fits the widest button, with Phoenix's 212 as the floor.

		Their column is a literal 212 wide because their buttons are single
		short words - NEW, LOAD, CONTENT, STEAM. Ours read "LOAD CHARACTER" and
		"LEAVE SERVER", which do not fit, so the label was being ellipsized to
		"LOAD CHARACT...".

		`ixMenuButton` pads its text by `padding[1]` and `padding[3]` (32 each
		by default), so a button's natural width is the text plus both. The
		panel then adds the dock margin on each side of the button and its own
		padding.
	]]
	local w = sW(212)

	do
		local canvas = list:GetCanvas()

		if (IsValid(canvas)) then
			surface.SetFont("UI_Bold")

			local widest = 0

			for _, child in ipairs(canvas:GetChildren()) do
				if (child:IsVisible() and child.GetText) then
					local padding = child.GetPadding and child:GetPadding()
					local sides = padding and (padding[1] + padding[3]) or Scaled(48)

					widest = math.max(widest,
						surface.GetTextSize(child:GetText() or "") + sides)
				end
			end

			w = math.max(w, widest + padX * 4)
		end
	end

	--[[
		Padding, then a FORCED relayout, then measure.

		The canvas is positioned from the list's dock padding by the list's own
		PerformLayout - but that already ran this frame, while the padding was
		still zero, and setting it here does not re-trigger it. The canvas
		therefore sat at y = 0 and every pixel of vertical padding piled up
		below the last button.

		`fo_ui_report` showed this exactly: 4 buttons, content 244, padding 32
		per side, panel 308 - the arithmetic correct, but the content drawn from
		the top edge instead of inset.
	]]
	list:DockPadding(padX, padY, padX, padY)
	list:SetWide(w)
	list:InvalidateLayout(true)

	local canvas = list:GetCanvas()
	local contentHeight = 0

	if (IsValid(canvas)) then
		--[[
			The top padding is a DOCK MARGIN on the first button, not a canvas
			offset.

			`DScrollPanel:PerformLayout` ends with `pnlCanvas:SetPos(0, YPos)`
			where YPos is the scroll offset. It runs on every layout pass and
			resets the canvas to zero no matter what is set here - which is why
			`fo_ui_report` kept reading `canvas y 0` through two attempts at
			positioning it, first via dock padding and then directly.

			A dock margin is applied by the dock layout itself, so DScrollPanel
			never overwrites it.
		]]
		canvas:SetWide(w - padX * 2)

		local counted = 0
		local first = true

		for _, child in ipairs(canvas:GetChildren()) do
			if (child:IsVisible() and child:GetTall() > 0) then
				child:DockMargin(padX, first and padY or 0, padX, 0)
				first = false
				counted = counted + 1
			end
		end

		canvas:InvalidateLayout(true)

		-- Measured AFTER the margins are applied, so contentHeight already
		-- includes the top padding.
		for _, child in ipairs(canvas:GetChildren()) do
			if (child:IsVisible() and child:GetTall() > 0) then
				local _, y = child:GetPos()

				contentHeight = math.max(contentHeight, y + child:GetTall())
			end
		end

		canvas:SetTall(contentHeight)

		-- The first child's Y is the meaningful check now: the canvas is always
		-- at 0 because DScrollPanel forces it, so the top padding shows up as
		-- the first button's dock-margin offset instead.
		local firstY = -1

		for _, child in ipairs(canvas:GetChildren()) do
			if (child:IsVisible() and child:GetTall() > 0) then
				firstY = select(2, child:GetPos())
				break
			end
		end

		list.ixMeasured = {
			count = counted,
			content = contentHeight,
			pad = padY,
			firstY = firstY
		}
	end

	-- Top padding is already inside contentHeight (the first button's margin),
	-- so only the bottom is added here.
	local h = contentHeight + padY

	--[[
		Anchored by its BOTTOM edge, which is Phoenix's rule rearranged:

		    y = ScrH() - (ScrH() * 0.2 + h)   ->   bottom sits at 80% of height
	]]
	local x, y = ScrW() * 0.1, ScrH() * 0.8 - h

	-- Only write when it changed: SetSize inside a layout pass schedules
	-- another one, and an unconditional write loops forever.
	if (list:GetWide() ~= w or list:GetTall() ~= h) then
		list:SetSize(w, h)
	end

	local curX, curY = list:GetPos()

	if (curX ~= x or curY ~= y) then
		list:SetPos(x, y)
	end
end

Wrap("ixCharMenuButtonList", "PerformLayout", function(panel, width, height)
	local canvas = panel:GetCanvas()

	if (not IsValid(canvas)) then return end

	--[[
		Inside the padding, not the raw bounds - the main menu pads this panel,
		and ignoring that would push the buttons out under the bracket rules.

		`ixCanvasInset` wins when present: the main menu sets both the padding
		and the canvas position itself, and reading `GetDockPadding` here has
		returned zero at the wrong moment before now.
	]]
	local inset = panel.ixCanvasInset
	local left, top, right

	if (inset) then
		left, top, right = inset[1], inset[2], inset[1]
	else
		left, top, right = panel:GetDockPadding()
	end

	canvas:Dock(NODOCK)
	canvas:SetPos(left, top)
	canvas:SetWide(math.max(width - left - right, 1))
end)

Wrap("ixCharMenuMain", "PerformLayout", function(panel)
	LayoutButtonList(panel.mainButtonList)
end)



--[[
	Remove the logo band.

	Helix's logo panel paints a full-width blurred strip with a bright rule
	along its top and bottom edge, then reveals it with a scissor animation.
	That is the pair of horizontal lines running across the whole screen.
	Phoenix has no such band - just the logo over the map.

	The labels inside are created with SetPaintedManually(true), so the
	replacement still has to paint them; dropping that would leave no title at
	all.

	NOTE: Helix draws a real image here instead of text when `Schema.logo` is
	set to a valid material path. Setting that is all it takes to match Phoenix's
	logo exactly - see sh_schema.lua.
]]
Wrap("ixCharMenuMain", "Init", function(panel)
	for _, child in ipairs(panel:GetChildren()) do
		if (child:GetName() == "Panel" and child:GetWide() >= ScrW() * 0.99) then
			child.Paint = function(this, width, height)
				for _, label in ipairs(this:GetChildren()) do
					label:PaintManual()
				end
			end

			panel.ixLogoPanel = child

			break
		end
	end
end)

--[[
	Stop the character menu dimming to black.

	`ixCharMenuPanel` animates `currentDimAmount` up to `targetDimAmount`, which
	Helix sets to **255** - fully opaque black - whenever it dims to hand off to
	another subpanel. That is why character creation and the load screen were
	solid black rather than showing the map.

	Phoenix keeps the world visible throughout; their panels carry the contrast.
]]
Wrap("ixCharMenuPanel", "Init", function(panel)
	panel.targetDimAmount = 120
end)

--[[
	Character creation text fields.

	`ixTextEntry:Paint` calls `DrawImportantBackground`, which is a GRADIENT
	helper - hence the smeared name and description boxes. Phoenix's fields are
	a solid palette block with dark text, like a terminal prompt.

	`BaseClass.Paint` is what normally draws the text, and it cannot be reached
	from out here, so `DrawTextEntryText` is called directly - omitting it would
	leave a field that accepts input and displays nothing.
]]
--[[
	Text entries.

	The first version filled the WHOLE box with `color_primary` and drew the
	black only as a one-pixel shadow behind it - so every field on the character
	creation screen came up as a solid yellow block. A field is a dark well with
	an accent EDGE; the fill is the background, not the accent.
]]
Replace("ixTextEntry", "Paint", function(panel, width, height)
	local palette = ix.fallout.GetPalette()

	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, 235)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(panel:HasFocus() and palette.color_primary or palette.color_active)
	surface.DrawOutlinedRect(0, 0, width, height)

	panel:DrawTextEntryText(palette.text_primary, palette.color_primary, palette.text_primary)
end)

--[[
	Helix sets character creation's name and description fields to
	`ixMenuButtonHugeFont` - sized for the main menu's buttons.

	That is also what made the fields so TALL, not just the text: this class's
	own `SetFont` does `SetTall(text height)`, so the box grows to fit whatever
	face it is given.

	Remapped here rather than fixed at the call site because Populate rebuilds
	these panels and would undo anything applied after the fact.
]]
Wrap("ixTextEntry", "SetFont", function(panel, font)
	if (font ~= "ixMenuButtonHugeFont") then return end

	--[[
		This re-enters the wrapper once, deliberately - the resize has to go
		through the real method, not just change the face. The guard above stops
		it after one pass, since "UI_Bold" is not the font being remapped.
	]]
	panel:SetFont("UI_Bold")
end)

--------------------------------------------------------------------------------
-- Character select
--------------------------------------------------------------------------------

--[[
	Helix's load screen already has Phoenix's shape - a character list docked
	LEFT, and an info side with the model and the choose/delete buttons:

	    controlList  Dock(LEFT), half the parent width, holds characterList
	    infoPanel    Dock(FILL), holds infoButtons (BOTTOM) and carousel (FILL)

	Phoenix's differs in three ways, all additive:

	    self.characters:SetSize(256, sH() * 0.45 + 24)   a narrow, framed list
	    self.info:SetTitle(name:upper() .. " >> " .. faction.name:upper())
	    desc = self.info:Add("UI_DLabel")                the character's description

	So this narrows the list, frames both sides, and adds the header. Helix's
	loading, deletion and networking are untouched.

	`controlList` and `infoPanel` are locals in Helix's Init, but both are
	reachable through fields it does expose.
]]
--[[
	Sizes, from Phoenix's `derma/cl_charload.lua`:

	    self.characters:SetSize(256, sH() * 0.45 + 24)   compact list, left
	    self.info:SetSize(SW * 0.4, playerPanelTall)     info panel beside it
	    self.info:MoveRightOf(self.characters, 24)

	Helix instead splits the screen in half, which is why the list ran the full
	height of the window.
]]
Wrap("ixCharMenuLoad", "Init", function(panel)
	local characterList = panel.characterList
	local carousel = panel.carousel

	if (not IsValid(characterList) or not IsValid(carousel)) then return end

	local controlList = characterList:GetParent()
	local infoPanel = carousel:GetParent()

	if (not IsValid(controlList) or not IsValid(infoPanel)) then return end

	-- Stored for the layout pass below.
	panel.ixControlList = controlList
	panel.ixInfoPanel = infoPanel

	-- Both sides opaque: the main menu's button column sits underneath and was
	-- showing through.
	local function PaintSide(this, width, height)
		draw.NoTexture()
		surface.SetDrawColor(8, 7, 4, 255)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(ColorAlpha(ix.fallout.GetPalette().color_background, 215))
		surface.DrawRect(0, 0, width, height)

		ix.fallout.DrawBrackets(width, height, nil, 0)
	end

	controlList.Paint = PaintSide
	infoPanel.Paint = PaintSide

	--[[
		Replace the carousel with a plain model panel.

		Helix's `ixCharMenuCarousel` renders through a stencil-clipped
		`cam.Start3D` with a transition between two ClientsideModels. It draws
		nothing here, and it is far more machinery than this screen needs.

		Phoenix uses a model panel (`nutCharacterPanel`, a DAdjustableModelPanel).
		Helix already ships the equivalent - `ixModelPanel` - and uses it in
		character creation, so it is known to work in this menu.
	]]
	carousel:SetVisible(false)

	local model = infoPanel:Add("ixModelPanel")

	model:Dock(FILL)
	model:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(4))
	model:SetFOV((ScrW() > ScrH() * 1.8) and 92 or 70)

	--[[
		Its Paint is deliberately NOT overridden.

		`DModelPanel:Paint` is what renders the entity - it runs LayoutEntity,
		opens `cam.Start3D`, sets up lighting and draws. Replacing it with a
		background fill draws no model at all, which is the same failure this
		panel is replacing the carousel to fix.

		The backdrop comes from infoPanel underneath instead.
	]]
	panel.ixModel = model

	--[[
		Header: "NAME >> FACTION" plus the description.

		Painted from `panel.character` every frame rather than pushed on
		selection - Helix already keeps that field current in
		OnCharacterButtonSelected.
	]]
	local header = infoPanel:Add("Panel")

	header:Dock(TOP)
	header:SetTall(Scaled(56))
	header:DockMargin(Scaled(8), Scaled(8), Scaled(8), 0)

	header.Paint = function(this, width, height)
		local palette = ix.fallout.GetPalette()
		local character = panel.character

		if (not character) then return end

		local faction = ix.faction.Get(character:GetFaction())
		local title = string.upper(character:GetName() or "")

		if (faction and faction.name) then
			title = title .. "  >>  " .. string.upper(faction.name)
		end

		draw.SimpleText(title, "UI_Bold", 0, 0,
			palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local description = character:GetDescription()

		if (description and description ~= "") then
			draw.SimpleText(description, "UI_Regular", 0, Scaled(30),
				palette.color_active, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		surface.SetDrawColor(palette.color_active)
		surface.DrawRect(0, height - 1, width, 1)
	end

	panel.ixHeader = header
end)

--[[
	Point the model panel at the selected character.

	`fo_ui_report` showed the entity loading correctly as
	`models/phoenix/humans/animations.mdl` while nothing appeared - because that
	model is the animation SKELETON and has no visible mesh. It is the same
	reason players were invisible in-world, which `libs/cl_bodyparts.lua` fixes
	by bone-merging a body and head onto them.

	The preview does the same: the body becomes the panel's entity, and the head
	is merged onto it. `ix.fallout.bodyParts` is shared with cl_bodyparts so both
	change together once races replace the hardcoded human male set.
]]
--[[
	Yaw the preview model is turned to.

	Helix's `ixModelPanel` uses a fixed `Angle(0, 45, 0)`, which works for the
	HL2 models its character creation was written against but shows the BACK of
	these Fallout bodies. Tunable rather than another guessed constant.
]]
--[[
	Yaw the preview model is turned to.

	The camera is placed on the +X side of the model (see the framing below), so
	a yaw of 0 points the model's forward axis straight at it. Helix's fixed
	`Angle(0, 45, 0)` is set for the HL2 models its character creation was
	written against and shows these Fallout bodies from behind.
]]
local cvarPreviewYaw = CreateClientConVar("fo_charpreview_yaw", "0", false, false,
	"Yaw the character-select preview model is turned to.")

--[[
	Framing knobs.

	How far back the camera sits and how high it rides, both as a multiple of
	the model's own height so they hold for any body size a race introduces.

	Convars rather than constants because framing is a judgement call about how
	the panel LOOKS, and the previous rounds of that were spent editing a
	constant, restarting, and taking another screenshot. These re-frame live.
]]
local cvarPreviewDist = CreateClientConVar("fo_charpreview_dist", "1.5", false, false,
	"Character preview camera distance, as a multiple of the model's height.")

local cvarPreviewRise = CreateClientConVar("fo_charpreview_rise", "-0.05", false, false,
	"Character preview camera offset from centre, as a multiple of the height. Negative looks up.")

--[[
	Aim the camera at the merged parts' bounds.

	Called every layout pass rather than once on model change, so changing the
	convars above updates the panel immediately. It is a handful of vector ops.
]]
--[[
	Hair tint brightness.

	Colour modulation MULTIPLIES the texture, and these hair textures are dark -
	measured reflectivity runs from 0.016 (female `fairytails`, which five other
	styles also use) up to 0.259 (`the_sophisticate`). A sixteen-fold spread
	means the same modulation colour lands very differently depending on which
	style is selected: on the darkest textures a light shade like blonde cannot
	come out light at all, because there is nothing to multiply up from.

	`render.SetColorModulation` accepts values above 1, so this scales the tint
	past unity to compensate. Default 1.0 keeps the current behaviour exactly -
	raise it if light hair colours read too dark.
]]
local cvarHairBoost = CreateClientConVar("fo_hair_boost", "1.0", false, false,
	"Brightness multiplier for hair and beard tinting. Above 1 lightens.")
local function FramePreview(modelPanel)
	if (not IsValid(modelPanel) or not modelPanel.ixMins) then return end

	local center = (modelPanel.ixMins + modelPanel.ixMaxs) * 0.5
	local height = modelPanel.ixMaxs.z - modelPanel.ixMins.z
	local rise = height * cvarPreviewRise:GetFloat()

	--[[
		`ixZoom` lets one panel sit closer than another without either having
		its own copy of this. Character creation frames tighter than character
		select: its column is narrower and taller, so the distance tuned for
		the select screen leaves the body small and marooned in it.
	]]
	local zoom = modelPanel.ixZoom or 1

	-- A function so a caller can hand over a convar and have it stay live,
	-- since this runs every layout pass rather than once on model change.
	if (isfunction(zoom)) then
		zoom = zoom()
	end

	local distance = height * cvarPreviewDist:GetFloat() / math.max(zoom, 0.1)

	modelPanel:SetCamPos(center + Vector(distance, 0, rise))
	modelPanel:SetLookAt(center + Vector(0, 0, rise * 0.5))

	modelPanel.ixBounds = height
end

--[[
	Point a model panel at a model, composing the body when it needs composing.

	Takes a MODEL PATH rather than a character, because character creation needs
	the identical treatment - its three model panels are handed the faction's
	model, which is the same meshless animation model - and there is no character
	to ask at that point.
]]
function ix.fallout.SetPreviewModel(modelPanel, model, skin, groups)
	if (not IsValid(modelPanel) or not model) then return end

	--[[
		Claim the composing flag for the whole call.

		`ComposeModelPanel` in cl_creation.lua overrides a panel's `SetModel` to
		route it here, and this function then calls `SetModel` itself - so
		without this, entering through the front door (Refresh, which calls this
		directly) runs the ENTIRE body twice and builds two of every part.

		Saved and restored rather than cleared, because the override may already
		have set it on the way in.
	]]
	local wasComposing = modelPanel.ixComposing

	modelPanel.ixComposing = true

	if (ix.fallout.CreateTrace) then
		ix.fallout.CreateTrace("compose: SetPreviewModel " .. tostring(model))
	end

	for _, part in ipairs(modelPanel.ixParts or {}) do
		if (IsValid(part)) then
			part:Remove()
		end
	end

	modelPanel.ixParts = {}

	-- Stale bounds would frame the new model against the old one's size.
	modelPanel.ixMins = nil

	--[[
		Which parts to compose.

		`ixPartsSource` is a function a panel can set to supply its own list -
		the customiser uses it to preview an appearance that no character has
		yet, straight out of the creation payload. Without one, the hardcoded
		fallback pair is used, which is what the character select screen wants
		for a character whose race is unknown.

		Entries may be a plain model path or a table
		{model = path, skin = index, hair = true} - the same shape
		`ix.fallout.GetBodyParts` returns, so one loop serves both.
	]]
	local parts = modelPanel.ixPartsSource and modelPanel.ixPartsSource()
		or ix.fallout.bodyParts

	--[[
		ANY race's carrier, not only the human one.

		This compared against `ix.fallout.animationModel`, which is the human
		carrier, so a super mutant's preview never took this path and showed the
		bare carrier instead of a body. `ix.fallout.IsAnimationModel` answers for
		every race - see `libs/cl_bodyparts.lua`, which had the same fault
		in-world.
	]]
	if (parts and ix.fallout.IsAnimationModel(model)) then
		--[[
			The ANIMATION MODEL stays the base entity, with the body and head
			merged onto it - exactly how `cl_bodyparts.lua` does it in-world.

			A first attempt made the body the base instead. That renders, but the
			body model carries almost no animation data, so it stood in a T-pose.
			The animation model is the one with the New Vegas set on it; it has no
			mesh of its own, which is why every visible part has to be merged.
		]]
		modelPanel:SetModel(model)

		local entity = modelPanel.Entity

		if (IsValid(entity)) then
			for i = 1, #parts do
				local entry = parts[i]
				local path = istable(entry) and entry.model or entry
				local part = path and ClientsideModel(path, RENDERGROUP_OPAQUE)

				if (IsValid(part)) then
					part:SetNoDraw(true)
					part:SetParent(entity)
					part:AddEffects(EF_BONEMERGE)

					if (istable(entry)) then
						ix.fallout.ApplyPartSkin(part, entry.skin)

						-- Hair and beard meshes are untinted; one model serves
						-- every colour.
						if (entry.hair and entry.color) then
							-- Read back in DrawModel; see the note there on why
							-- SetColor alone does nothing for these parts.
							part.ixColor = entry.color
							part.ixBoost = entry.boost
							part:SetColor(entry.color)
						end
					end

					modelPanel.ixParts[#modelPanel.ixParts + 1] = part

					if (ix.fallout.CreateTrace) then
						ix.fallout.CreateTrace("compose: merged " .. tostring(path)
							.. " skins=" .. tostring(part:SkinCount()))
					end
				end
			end

			--[[
				The sequence is `idle1`, not `idle`.

				`animations.mdl` carries idle1..idle4 plus the power-armour
				variants; there is no plain "idle", so looking that up returned
				nothing and the entity stayed on its reference pose - the T-pose.

				Helix's own SetModel does search for any sequence containing
				"idle", which should have caught idle1, so this sets it
				explicitly and records what the entity actually ended up on for
				`fo_ui_report`.
			]]
			for _, name in ipairs({"idle1", "idle", "idle_unarmed"}) do
				local sequence = entity:LookupSequence(name)

				if (sequence and sequence > 0) then
					entity:ResetSequence(sequence)
					break
				end
			end

			--[[
				Measure the whole body.

				Measured from the MERGED PARTS, not the entity. The entity is
				the animation model and has no mesh, so its render bounds are
				near-empty - framing off them put the camera far too close and
				cut the head off.

				FramePreview turns these into a camera position, every layout
				pass, so the framing convars take effect live.
			]]
			local mins, maxs

			for _, part in ipairs(modelPanel.ixParts) do
				if (IsValid(part)) then
					local partMins, partMaxs = part:GetRenderBounds()

					if (mins) then
						mins = Vector(math.min(mins.x, partMins.x),
							math.min(mins.y, partMins.y), math.min(mins.z, partMins.z))
						maxs = Vector(math.max(maxs.x, partMaxs.x),
							math.max(maxs.y, partMaxs.y), math.max(maxs.z, partMaxs.z))
					else
						mins, maxs = partMins, partMaxs
					end
				end
			end

			modelPanel.ixMins, modelPanel.ixMaxs = mins, maxs
		end
	else
		modelPanel:SetModel(model, skin or 0, groups)
	end

	--[[
		Draw the merged parts as well as the base entity.

		The base `DrawModel` is captured and CALLED rather than replaced:
		`ixModelPanel:DrawModel` sets up all of the model lighting before
		drawing, and replacing it outright leaves the preview flat and unlit.

		This overrides DrawModel, never Paint - Paint is the renderer.
	]]
	if (not modelPanel.ixDrawPatched) then
		local baseDrawModel = modelPanel.DrawModel

		modelPanel.DrawModel = function(this)
			baseDrawModel(this)

			for _, part in ipairs(this.ixParts or {}) do
				if (IsValid(part)) then
					--[[
						Hair and beard are tinted with COLOUR MODULATION, not
						`Entity:SetColor`.

						These parts are drawn by hand here rather than by the
						engine's render path, and `ixModelPanel:DrawModel` -
						which `baseDrawModel` just called - ends with
						`render.SetColorModulation(1, 1, 1)`. So an entity
						colour set on the part is simply never consulted, and
						every hair colour rendered identically.

						Reset afterwards, or the tint bleeds onto whatever draws
						next.
					]]
					local color = part.ixColor

					if (color) then
						-- The race's per-gender value, times the convar, which stays
						-- a global override for tuning.
						local boost = math.Clamp((part.ixBoost or 1)
							* cvarHairBoost:GetFloat(), 0.1, 16)

						render.SetColorModulation(color.r / 255 * boost,
							color.g / 255 * boost, color.b / 255 * boost)
						part:DrawModel()
						render.SetColorModulation(1, 1, 1)
					else
						part:DrawModel()
					end
				end
			end
		end

		-- Same for the angle: run Helix's layout, then face the model at us.
		local baseLayout = modelPanel.LayoutEntity

		modelPanel.LayoutEntity = function(this)
			baseLayout(this)

			FramePreview(this)

			if (IsValid(this.Entity)) then
				this.Entity:SetAngles(Angle(0, cvarPreviewYaw:GetFloat(), 0))
			end
		end

		modelPanel.ixDrawPatched = true
	end

	modelPanel.ixComposing = wasComposing
end

Wrap("ixCharMenuLoad", "OnCharacterButtonSelected", function(panel)
	local character = panel.character

	if (character) then
		ix.fallout.SetPreviewModel(panel.ixModel, character:GetModel(),
			character:GetData("skin", 0), character:GetData("groups"))
	end
end)

--[[
	Phoenix's load screen is two compact panels, not a full-screen split:

	    self.characters:SetPos(ScrW() * 0.1, ScrH() - (ScrH() * 0.2 + sH() * 0.45) - 24)
	    self.characters:SetSize(256, sH() * 0.45 + 24)
	    self.info:MoveRightOf(self.characters, 24)
	    self.info:SetSize(SW * 0.4, playerPanelTall)

	Helix docks its two halves to LEFT and FILL inside a full-screen subpanel,
	which is why this covered the whole window.

	Their literal 256 and `sH() * 0.45` (which is 486 fixed pixels - `sH()` with
	no argument returns 1080) are written scaled here, so the panel keeps its
	proportions instead of shrinking at 1440p.
]]
Wrap("ixCharMenuLoad", "PerformLayout", function(panel)
	local controlList = panel.ixControlList
	local infoPanel = panel.ixInfoPanel

	if (not IsValid(controlList) or not IsValid(infoPanel)) then return end

	local gap = Scaled(24)
	local listW = sW(256)
	local infoW = ScrW() * 0.4
	local height = sH(486) + gap
	--[[
		Centred vertically rather than sitting low.

		Phoenix anchors theirs near the bottom because their main menu column is
		elsewhere on screen; ours sits directly behind, so the load screen is
		centred and the main menu is hidden outright (see the slide hooks below)
		rather than being partly covered.
	]]
	local x = ScrW() * 0.1
	local y = (ScrH() - height) * 0.5

	-- Undock: docking re-runs every layout pass and would overwrite these.
	controlList:Dock(NODOCK)
	infoPanel:Dock(NODOCK)

	if (controlList:GetWide() ~= listW or controlList:GetTall() ~= height) then
		controlList:SetSize(listW, height)
	end

	if (infoPanel:GetWide() ~= infoW or infoPanel:GetTall() ~= height) then
		infoPanel:SetSize(infoW, height)
	end

	controlList:SetPos(x, y)
	infoPanel:SetPos(x + listW + gap, y)
end)

--[[
	Hide the main menu while the load screen is up.

	Helix only dims the main panel, so its button column and the schema title
	stayed visible behind the load screen - the column is slightly wider than
	the character list, so it showed as a sliver down the left edge, and the
	title read straight through the gap above.

	Phoenix's load screen replaces the main menu view entirely. Hiding is the
	equivalent here, and OnSlideUp/OnSlideDown are Helix's own transition hooks
	so nothing about the animation changes.
]]
local function SetMainMenuVisible(loadPanel, bVisible)
	local parent = loadPanel:GetParent()

	if (not IsValid(parent) or not IsValid(parent.mainPanel)) then return end

	local main = parent.mainPanel

	if (IsValid(main.mainButtonList)) then
		main.mainButtonList:SetVisible(bVisible)
	end

	if (IsValid(main.ixLogoPanel)) then
		main.ixLogoPanel:SetVisible(bVisible)
	end
end

Wrap("ixCharMenuLoad", "OnSlideUp", function(panel)
	SetMainMenuVisible(panel, false)
end)

Wrap("ixCharMenuLoad", "OnSlideDown", function(panel)
	SetMainMenuVisible(panel, true)
end)

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_panels.lua")

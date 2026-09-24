--[[
	Fallout UI - the F1 menu.

	This is a REPLACEMENT for Helix's `ixMenu`, not a restyle of it, and that is
	deliberate. Phoenix did the same thing - their `nutMenu_fallout` is its own
	panel rather than a patched NutScript menu, because the two layouts are not
	variations of each other:

	    Helix    a 25%-wide button column docked LEFT, content filling the rest
	    Phoenix  a centred 896x704 window, tabs in a horizontal strip inside it

	An earlier attempt bent Helix's docking into that shape by patching. It got
	the tabs horizontal and nothing else right - button widths came from Helix's
	32px text padding so the strip spanned the screen, the right-docked
	"return"/"characters" buttons collided with the last tab, and the subpanels
	kept their own geometry. Docking fights you when the layout disagrees with
	it, so everything here is positioned MANUALLY in PerformLayout.

	Phoenix's geometry, from their `derma/cl_menu.lua`:

	    menu:SetSize(sW(896), sH(704))
	    menu:SetPos(ScrW() * 0.5 - menu:GetWide() / 2,
	                (ScrH() * 0.5 - menu:GetTall() / 2) + 16)
	    tabs:Dock(TOP)  tabs:SetHeight(32)
	    buttons:SetPos(menu:GetWide() * 0.5 - buttons:GetWide() * 0.5, 0)
	    page:SetSize(menu:GetWide(), menu:GetTall() - 64)

	Tab CONTENT is still Helix's. Tabs are collected from the same
	`CreateMenuButtons` hook and populated the same way Helix does it:

	    if (istable(info) and info.Create) then info:Create(container)
	    elseif (isfunction(info)) then info(container) end

	so every tab any plugin registers keeps working, unmodified.
]]

--[[
	Declared here as well as in `cl_theme.lua`, so this file is true on
	its own. These are included in a fixed order by `sh_schema.lua` and
	the theme comes first - but a file that only works because of the
	order it happens to be listed in is one edit away from an error at
	file scope, and one of those takes a whole directory with it.
]]
ix.fallout = ix.fallout or {}

local PANEL = {}

--[[
	Helix reads all of these off ix.gui.menu, so this panel has to provide them
	or the framework breaks around it:

	    :Remove()                 sh_character, cl_information
	    :IsVisible()              sh_character
	    .bClosing                 cl_hooks, chatbox
	    .currentAlpha             chatbox fade
	    :GetActiveTab()           cl_hooks
	    :SetCharacterOverview()   cl_information ("you" tab)
]]
local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	Window size.

	Phoenix's window is sW(896) x sH(704) - 46.7% of screen width, 65.2% of its
	height. These defaults are exactly that.

	An earlier pass widened this to 0.70 x 0.80 believing Helix's tab content
	needed the room. It did not: what actually spilled outside the frame was the
	CLIPPED CORNERS on category panels (see CONTAINER_EDGE in cl_skin.lua), and
	widening the window only made the whole menu oversized.
]]
--[[
	NOT saved to config, deliberately.

	`CreateClientConVar(name, default, true, ...)` writes the value to
	client.cfg, and a saved value beats any later change to the default here.
	That is how a previous 0.70 kept the menu oversized after the default was
	corrected to Phoenix's 0.467 - the new default never applied.

	While these are still being tuned they stay session-only, so the code is the
	single source of truth. Flip the third argument to true once the numbers
	settle and players should keep their own.
]]
local cvarWidth = CreateClientConVar("fo_menu_width", "0.467", false, false,
	"F1 menu window width, as a fraction of the screen.")
local cvarHeight = CreateClientConVar("fo_menu_height", "0.652", false, false,
	"F1 menu window height, as a fraction of the screen.")

local function MenuSize()
	return math.Round(ScrW() * math.Clamp(cvarWidth:GetFloat(), 0.3, 0.95)),
		math.Round(ScrH() * math.Clamp(cvarHeight:GetFloat(), 0.3, 0.95))
end

function PANEL:Init()
	if (IsValid(ix.gui.menu)) then
		ix.gui.menu:Remove()
	end

	ix.gui.menu = self

	self.tabInfo = {}
	self.tabButtons = {}
	self.pages = {}
	self.activeTab = nil

	-- Read by Helix: the chatbox fades against currentAlpha, and several places
	-- check bClosing before acting on the menu.
	self.currentAlpha = 255
	self.bClosing = false
	self.bOverview = false

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	local windowW, windowH = MenuSize()

	self.window = self:Add("Panel")
	self.window:SetSize(windowW, windowH)
	--[[
		Phoenix's menu container paints NOTHING - `menu:SetPaintBackground(false)`.
		Their neutral dark look is plain translucent black on the page plus amber
		rules; there is no colour wash anywhere, and no scanlines.

		Two earlier attempts here added an opaque fill, a phosphor bloom and
		heavy scanlines to make it "more Pip-Boy". All three pushed it AWAY from
		the reference - the bloom is what turned the whole window olive.
	]]
	self.window.Paint = function(_, w, h)
		ix.fallout.DrawBrackets(w, h, ix.fallout.GetPalette().color_primary)
	end

	--[[
		The XP bar, under the whole window.

		Phoenix put this in the menu chrome rather than in any tab, and the
		Paint is theirs exactly:

		    surface.DrawRect(0, 0, w + 6, h)          -- 0,0,0,150
		    surface.DrawOutlinedRect(0, 0, w, h)      -- 0,0,0,200
		    surface.DrawRect(3, 3, (w - 6) * div, h - 6)   -- primary

		including the `w + 6` on the backing rect, which overhangs the outline
		by six pixels on the right. That is in their code and is kept - it is
		what makes the bar read as sitting under the frame rather than inside
		it.

		The label is TOTAL xp against the next level's total, not progress into
		the current level, which is also theirs: "9400 / 9608".
	]]
	--[[
		A DPanel, not a Panel. `SetPaintBackground` is a DPanel method - a bare
		`Panel` does not have it, and calling it there takes the whole menu
		down to the Helix fallback. Phoenix used a DPanel here for the same
		reason.
	]]
	self.xpBar = self:Add("DPanel")
	self.xpBar:SetPaintBackground(false)
	self.xpBar.Paint = function(_, w, h)
		local character = LocalPlayer():GetCharacter()

		if (not character or not ix.leveling or not character.GetLevel) then return end

		local level = character:GetLevel()
		local total = character:GetXP()
		local needed = ix.leveling.RequiredXP(level + 1)
		local _, _, fraction = ix.leveling.GetProgress(character)

		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, w + 6, h)

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawOutlinedRect(0, 0, w, h)

		surface.SetDrawColor(ix.fallout.GetPalette().color_primary)
		surface.DrawRect(3, 3, (w - 6) * fraction, h - 6)

		draw.SimpleTextOutlined(string.format("LEVEL %d    %d / %d", level,
			math.Round(total), needed), "UI_Bold", w * 0.5, h * 0.5,
			ix.fallout.GetPalette().color_background,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	self.strip = self.window:Add("Panel")
	--[[
		The bottom rule BREAKS around the active tab - that is what produces the
		bracketed look in Phoenix's screenshots, not a filled highlight box:

		    surface.DrawRect(0, 30, bX + 6 + b, 2)                  -- left of it
		    surface.DrawRect(s, 30, menu:GetWide() - s, 2)          -- right of it
	]]
	self.strip.Paint = function(_, w, h)
		local palette = ix.fallout.GetPalette()
		local t = math.max(Scaled(2), 1)
		local y = h - t
		local active

		for i = 1, #self.tabButtons do
			if (self.tabButtons[i]:GetActive()) then
				active = self.tabButtons[i]
				break
			end
		end

		surface.SetDrawColor(0, 0, 0, 255)

		if (IsValid(active)) then
			local ax = active:GetPos()
			local gap = Scaled(6)
			local right = ax + active:GetWide() + gap

			surface.DrawRect(1, y + 1, math.max(ax - gap, 0), t)
			surface.DrawRect(right + 1, y + 1, w - right, t)

			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, y, math.max(ax - gap, 0), t)
			surface.DrawRect(right, y, w - right, t)
		else
			surface.DrawRect(1, y + 1, w, t)
			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, y, w, t)
		end
	end

	--[[
		Phoenix's page:

		    surface.SetDrawColor(Color(0, 0, 0, 100))
		    surface.DrawRect(6, 6, w - 12, h - 12)
		    -- plus two corner ticks at the top

		Translucent black, inset by 6. That is the entire background treatment,
		and it is why their inventory area reads as neutral dark rather than
		tinted - you can see the blurred world faintly through it.
	]]
	self.page = self.window:Add("Panel")
	self.page.Paint = function(_, w, h)
		local palette = ix.fallout.GetPalette()
		local inset = Scaled(6)

		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(inset, inset, w - inset * 2, h - inset * 2)

		-- A very light scanline pass. Phoenix has none; this is subtle enough
		-- to read as a screen without tinting anything.
		if (ix.option.Get("falloutScanlines", true)) then
			surface.SetDrawColor(0, 0, 0, 16)

			for y = inset, h - inset, 3 do
				surface.DrawRect(inset, y, w - inset * 2, 1)
			end
		end

		local tick = Scaled(6)
		local t = math.max(Scaled(2), 1)

		surface.SetDrawColor(palette.color_primary)
		surface.DrawRect(0, 0, t, tick)
		surface.DrawRect(w - t, 0, t, tick)
	end

	self.side = self:Add("Panel")
	self.side.Paint = function(panel, w, h)
		surface.SetDrawColor(0, 0, 0, 170)
		surface.DrawRect(0, 0, w, h)

		ix.fallout.DrawBrackets(w, h, ix.fallout.GetPalette().color_primary)

		self:PaintMetaInfo(w, h)
	end

	self.info = self.window:Add("Panel")
	self.info.Paint = function(_, w, h)
		local t = math.max(Scaled(2), 1)

		surface.SetDrawColor(ix.fallout.GetPalette().color_primary)
		surface.DrawRect(0, 0, w, t)

		self:PaintInfoCells(w, h)
	end

	-- Lay out BEFORE populating: tab content is created against the page's
	-- size, and several of Helix's tabs read that size when they build. Without
	-- this they would be created against a zero-sized container.
	self:InvalidateLayout(true)

	self:PopulateTabs()
	self:BuildInfoBar()
	self:InvalidateLayout(true)

	self.openTime = CurTime() + 0.35
	self.bTabHeld = true

	self:MakePopup()
	gui.EnableScreenClicker(true)
end

--- A tab button sized to its own text, so the strip is only as wide as it needs.
--[[
	Tab button.

	Deliberately NOT an ixFOButton. Phoenix's tabs are plain DButtons with no
	background at all - the break in the rule underneath is the entire selection
	cue. An ixFOButton would fill solid and flip its text dark on hover, which
	is right for a normal button and wrong here: with no fill behind it, dark
	text on a dark page is invisible.

	So: amber text, dimmed when inactive, brightened on hover.
]]
function PANEL:AddTabButton(text, onClick)
	local button = self.strip:Add("DButton")
	local label = string.upper(text)

	button:SetText(label)
	button:SetFont("UI_Bold")
	button:SetContentAlignment(5)
	button:SetPaintBackground(false)
	button:SetExpensiveShadow(1, color_black)
	button:SetTall(Scaled(28))
	button.Paint = function() end

	surface.SetFont("UI_Bold")

	local textWidth = surface.GetTextSize(label)

	-- Helix's ixMenuButton pads 32px each side; that is what made the earlier
	-- patched strip span the whole screen. Sized to the text instead.
	button:SetWide(textWidth + Scaled(20))

	button.bActive = false

	button.SetActive = function(panel, bValue)
		panel.bActive = bValue
		panel:UpdateColour()
	end

	button.GetActive = function(panel)
		return panel.bActive
	end

	button.UpdateColour = function(panel)
		local palette = ix.fallout.GetPalette()

		panel:SetTextColor((panel.bActive or panel.Hovered)
			and palette.color_primary or palette.color_active)
	end

	button.OnCursorEntered = function(panel)
		ix.fallout.PlayUISound("hover")
		panel:UpdateColour()
	end

	button.OnCursorExited = function(panel)
		panel:UpdateColour()
	end

	button.DoClick = function()
		ix.fallout.PlayUISound("select")
		onClick()
	end

	button:UpdateColour()

	return button
end

function PANEL:PopulateTabs()
	local tabs = {}

	hook.Run("CreateMenuButtons", tabs)

	local default

	for name, info in SortedPairs(tabs) do
		local id = name
		local button = self:AddTabButton(L(name), function()
			self:SetActiveTab(id)
		end)

		button.tabID = id

		self.tabInfo[id] = info
		self.tabButtons[#self.tabButtons + 1] = button

		if (not default or (istable(info) and info.bDefault)) then
			default = id
		end
	end

	if (ix.gui.lastMenuTab and self.tabInfo[ix.gui.lastMenuTab]) then
		default = ix.gui.lastMenuTab
	end

	if (default) then
		self:SetActiveTab(default)
	end
end

--[[
	Info bar cells.

	Phoenix's bottom bar is a row of segmented readouts - health, caps, level,
	skill points, RESPEC. Ours carries the ones that have a system behind them
	today; the rest are one entry each once those land, which is why this is a
	table rather than hardcoded.

	A cell returning nil is skipped, same contract as the HUD providers.
]]
ix.fallout.menuCells = ix.fallout.menuCells or {
	{
		id = "health",
		Get = function(client)
			return string.format("%d/%d", client:Health(), client:GetMaxHealth())
		end
	},
	{
		id = "money",
		Get = function(client, character)
			if (not character.GetMoney) then return end

			return ix.currency.Get(character:GetMoney())
		end
	},
	{
		id = "name",
		Get = function(_, character)
			return character:GetName()
		end
	},
	{
		id = "faction",
		Get = function(_, character)
			local faction = ix.faction.Get(character:GetFaction())

			return faction and faction.name
		end
	}
	-- Level, Skill Points and RESPEC go here once progression exists.
}

--[[
	Meta Info side panel.

	Phoenix docks a readout to the right of the menu listing character and
	player state. Ours carries the rows that have data behind them today; theirs
	also shows karma, fear and resistances, which are one entry each here once
	those systems exist.

	A row is either {label, Get} or the string "-" for a separator.
]]
ix.fallout.menuMetaRows = ix.fallout.menuMetaRows or {
	{"Char Name", function(_, character) return character:GetName() end},
	{"SteamID", function(client) return client:SteamID() end},
	{"Faction", function(_, character)
		local faction = ix.faction.Get(character:GetFaction())

		return faction and faction.name
	end},
	{"Class", function(_, character)
		local class = ix.class.list[character:GetClass()]

		return class and class.name
	end},
	"-",
	{"Run Speed", function(client) return math.Round(client:GetRunSpeed()) end},
	{"Walk Speed", function(client) return math.Round(client:GetWalkSpeed()) end},
	{"Jump Power", function(client) return math.Round(client:GetJumpPower()) end},
	"-",

	--[[
		KARMA AND THE RESISTANCES, which the note here used to promise "once
		those systems exist". They exist.

		Karma is the one thing a player had no way of finding out about
		themselves: the title under a name is vague on purpose and gated on
		recognition, and `/karma` is a command nobody knows to type. Their own
		numbers are their own business to read.
	]]
	{"Karma", function(client, character)
		if (not ix.karma or not ix.config.Get("karmaEnabled", true)) then
			return nil
		end

		local good, bad = ix.karma.Of(character)

		if (good + bad <= 0) then return "Nothing yet" end

		local title, level = ix.karma.Describe(good, bad)

		return string.format("%s (%d)  +%d / -%d", title, level, good, bad)
	end},

	{"Damage Resist", function(client, character)
		if (not ix.armor or not ix.armor.GetBodyDR) then return nil end

		return string.format("body %d%%   head %d%%",
			math.Round(ix.armor.GetBodyDR(character) or 0),
			math.Round(ix.armor.GetHeadDR(character) or 0))
	end},

	{"Rad Resist", function(client, character)
		if (not ix.armor or not ix.armor.GetRadResistance) then return nil end

		return math.Round(ix.armor.GetRadResistance(character)) .. "%"
	end}
}

function PANEL:PaintMetaInfo(width, height)
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local palette = ix.fallout.GetPalette()
	local pad = Scaled(8)
	local y = pad + Scaled(20)

	surface.SetFont("UI_Small")

	local _, lineH = surface.GetTextSize("W")

	draw.SimpleText("Meta Info", "UI_Regular", pad, pad,
		palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	for i = 1, #ix.fallout.menuMetaRows do
		local row = ix.fallout.menuMetaRows[i]

		if (row == "-") then
			surface.SetDrawColor(palette.color_active)
			surface.DrawRect(pad, y + lineH * 0.5, width - pad * 2, 1)

			y = y + lineH
		else
			local ok, value = pcall(row[2], client, character)

			if (ok and value ~= nil) then
				draw.SimpleText(row[1] .. ": " .. tostring(value), "UI_Small",
					pad, y, palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				y = y + lineH + Scaled(2)
			end
		end
	end

	-- Measured during paint but consumed by PerformLayout, so the panel has to
	-- be told to lay out again when the content height actually changes -
	-- otherwise it sits at the fallback height forever.
	local measured = y + pad

	if (self.metaHeight ~= measured) then
		self.metaHeight = measured
		self:InvalidateLayout()
	end
end

function PANEL:PaintInfoCells(width, height)
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local palette = ix.fallout.GetPalette()
	local pad = Scaled(10)
	local x = pad

	surface.SetFont("UI_Regular")

	for i = 1, #ix.fallout.menuCells do
		local cell = ix.fallout.menuCells[i]
		local ok, text = pcall(cell.Get, client, character)

		if (ok and text) then
			text = tostring(text)

			local textW = surface.GetTextSize(text)
			local cellW = textW + pad * 2
			local cellH = height - Scaled(8)
			local cellY = Scaled(4)

			-- Phoenix boxes each readout rather than separating them with a
			-- rule, which is what makes their bar read as instrument panels.
			-- Matches the page's translucency rather than sitting as a black
			-- block against it.
			surface.SetDrawColor(0, 0, 0, 90)
			surface.DrawRect(x, cellY, cellW, cellH)

			surface.SetDrawColor(palette.color_active)
			surface.DrawOutlinedRect(x, cellY, cellW, cellH)

			draw.SimpleText(text, "UI_Regular", x + cellW * 0.5, height * 0.5,
				palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			x = x + cellW + Scaled(6)
		end
	end
end

function PANEL:BuildInfoBar()
	local close = self.info:Add("ixFOButton")

	close:SetText(string.upper(L("return")))
	close:SetContentAlignment(5)
	close.DoClick = function()
		self:Remove()
	end

	local characters = self.info:Add("ixFOButton")

	characters:SetText(string.upper(L("characters")))
	characters:SetContentAlignment(5)
	characters.DoClick = function()
		self:Remove()
		vgui.Create("ixCharMenu")
	end

	self.infoButtons = {close, characters}
end

--[[
	Populated lazily and cached, the way Helix does it - some tabs are expensive
	to build and most are never opened in a given session.
]]
function PANEL:GetPage(id)
	if (IsValid(self.pages[id])) then
		return self.pages[id]
	end

	local info = self.tabInfo[id]

	if (not info) then return end

	--[[
		Inset inside the page. Helix's tab content docks FILL, so without this
		the scoreboard's faction bars and the config category boxes run edge to
		edge and read as though they are touching the window frame.
	]]
	local inset = Scaled(12)
	local pageW, pageH = self.page:GetSize()

	local container = self.page:Add("Panel")

	container:SetSize(pageW - inset * 2, pageH - inset * 2)
	container:SetPos(inset, inset)
	container.Paint = function() end

	-- Exactly Helix's dispatch, so tabs registered by any plugin behave the
	-- same here as they do in Helix's own menu.
	if (istable(info) and info.Create) then
		info:Create(container)
	elseif (isfunction(info)) then
		info(container)
	end

	hook.Run("MenuSubpanelCreated", id, container)

	self.pages[id] = container

	return container
end

function PANEL:SetActiveTab(id)
	if (self.activeTab == id) then return end

	--[[
		`OnDeselected` AND `OnSelected`, which this menu never dispatched.

		Helix's own `SetActiveSubpanel` calls both, and a tab's `Create` is only
		half of its contract - the "you" tab fills itself in `OnSelected`:

		    OnSelected = function(info, container)
		        container.infoPanel:Update(LocalPlayer():GetCharacter())
		        ix.gui.menu:SetCharacterOverview(true)

		so without this the character page was built once with its rows empty
		and never updated, and the menu never stepped aside to show the
		character model either. Anything a plugin hangs off those two callbacks
		was equally dead.
	]]
	local previous = self.tabInfo[self.activeTab]
	local previousPage = self.pages[self.activeTab]

	if (istable(previous) and previous.OnDeselected and IsValid(previousPage)) then
		previous:OnDeselected(previousPage)
	end

	for otherID, page in pairs(self.pages) do
		if (IsValid(page)) then
			page:SetVisible(otherID == id)
		end
	end

	local page = self:GetPage(id)

	if (IsValid(page)) then
		page:SetVisible(true)
	end

	local info = self.tabInfo[id]

	if (istable(info) and info.OnSelected and IsValid(page)) then
		info:OnSelected(page)
	end

	for i = 1, #self.tabButtons do
		local button = self.tabButtons[i]

		button:SetActive(button.tabID == id)
	end

	self.activeTab = id
	ix.gui.lastMenuTab = id
end

function PANEL:GetActiveTab()
	return self.activeTab
end

--[[
	Helix's "you" tab calls this to get the menu out of the way so the character
	model is visible. Hiding the window rather than the whole panel keeps the
	blur and the input grab.
]]
function PANEL:SetCharacterOverview(bValue)
	self.bOverview = bValue and true or false

	if (IsValid(self.window)) then
		self.window:SetVisible(not self.bOverview)
	end
end

function PANEL:GetCharacterOverview()
	return self.bOverview
end

function PANEL:PerformLayout(width, height)
	local windowW, windowH = MenuSize()

	local windowX = (width - windowW) * 0.5
	local windowY = (height - windowH) * 0.5 + sH(16)

	self.window:SetSize(windowW, windowH)
	self.window:SetPos(windowX, windowY)

	--[[
		Six pixels below the window, matching their `y + 704 + 6`. Sized to the
		window rather than to a fixed 896 so it still lines up at any of the
		menu sizes `fo_menu_width` allows.
	]]
	self.xpBar:SetSize(windowW, Scaled(24))
	self.xpBar:SetPos(windowX, windowY + windowH + Scaled(6))

	local stripH = Scaled(36)
	local infoH = Scaled(34)

	-- Clearance between the window frame and the page. DrawBrackets draws just
	-- outside the panel bounds, so content flush to the page edge reads as
	-- touching the frame.
	local pad = Scaled(14)

	self.strip:SetPos(0, 0)
	self.strip:SetSize(windowW, stripH)

	self.info:SetPos(0, windowH - infoH)
	self.info:SetSize(windowW, infoH)

	self.page:SetPos(pad, stripH + pad)
	self.page:SetSize(windowW - pad * 2, windowH - stripH - infoH - pad * 2)

	local inset = Scaled(12)
	local pageW, pageH = self.page:GetSize()
	local contentW, contentH = pageW - inset * 2, pageH - inset * 2

	for _, page in pairs(self.pages) do
		-- Only resize when it actually changed. Setting the size unconditionally
		-- re-invalidates the inventory's tile layout every frame, which with a
		-- 70-slot grid is enough to cost real frames.
		if (IsValid(page) and (page:GetWide() ~= contentW or page:GetTall() ~= contentH)) then
			page:SetSize(contentW, contentH)
			page:SetPos(inset, inset)
		end
	end

	-- Meta Info sits to the right of the window, top-aligned with the page.
	local sideW = math.min(ScrW() * 0.15, Scaled(260))
	local windowX = (width - windowW) * 0.5
	local windowY = (height - windowH) * 0.5 + sH(16)

	self.side:SetSize(sideW, self.metaHeight or Scaled(220))
	self.side:SetPos(windowX + windowW + Scaled(14), windowY + stripH)
	self.side:SetVisible(windowX + windowW + Scaled(14) + sideW < width)

	-- Tabs, centred. Manual rather than docked: Helix's docking is what made
	-- the previous attempt spread them across the whole screen.
	--
	-- AND MADE TO FIT. Nine tabs in UI_Bold at Phoenix's 896 wide overran
	-- the window on both sides. The strip tries the bold font at three
	-- paddings, then the regular one, then the small, and keeps the first
	-- that fits between the brackets; a tab is never hidden.
	local gap = Scaled(10)
	local available = windowW - Scaled(16)
	local total = 0

	for _, attempt in ipairs({
		{"UI_Bold", Scaled(20)}, {"UI_Bold", Scaled(10)}, {"UI_Bold", Scaled(6)},
		{"UI_Regular", Scaled(12)}, {"UI_Regular", Scaled(6)},
		{"UI_Small", Scaled(8)}
	}) do
		surface.SetFont(attempt[1])
		total = 0

		for i = 1, #self.tabButtons do
			local button = self.tabButtons[i]

			button:SetFont(attempt[1])
			button:SetWide(surface.GetTextSize(button:GetText()) + attempt[2])
			total = total + button:GetWide() + gap
		end

		total = math.max(total - gap, 0)

		if (total <= available) then break end
	end

	local x = (windowW - total) * 0.5

	for i = 1, #self.tabButtons do
		local button = self.tabButtons[i]

		button:SetPos(x, (stripH - button:GetTall()) * 0.5)
		x = x + button:GetWide() + gap
	end

	-- Info bar buttons, right aligned.
	if (self.infoButtons) then
		local bx = windowW - pad

		for i = 1, #self.infoButtons do
			local button = self.infoButtons[i]

			button:SetTall(Scaled(26))
			surface.SetFont("UI_Bold")
			button:SetWide(surface.GetTextSize(button:GetText()) + Scaled(24))

			bx = bx - button:GetWide()
			button:SetPos(bx, (infoH - button:GetTall()) * 0.5)
			bx = bx - gap
		end
	end
end

function PANEL:Paint(width, height)
	--[[
		ORDER MATTERS. DrawBlur redraws the blurred world on top of whatever is
		already on the panel, so dimming first and blurring second undoes the
		dim - which is why the window was see-through. Blur, then dim over it.
	]]
	ix.util.DrawBlur(self, 10, nil, 255)

	surface.SetDrawColor(0, 0, 0, 195)
	surface.DrawRect(0, 0, width, height)

	-- No CRT out here. The tube is the WINDOW; tinting the whole viewport amber
	-- is what made this read as a sepia photograph instead of a screen.
end

function PANEL:OnRemove()
	self.bClosing = true

	gui.EnableScreenClicker(false)
	CloseDermaMenus()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

--[[
	Close on TAB.

	MakePopup gives the panel keyboard focus, which stops the +score bind from
	reaching the gamemode - so ScoreboardShow never fires a second time and the
	menu cannot be toggled shut with the same key that opened it. Helix has the
	same problem and expects you to click "return".

	input.IsKeyDown reads the physical key regardless of panel focus, so this
	polls it directly. The grace period stops the keypress that OPENED the menu
	from immediately closing it again.
]]
function PANEL:Think()
	local down = input.IsKeyDown(KEY_TAB)

	if (down and not self.bTabHeld and CurTime() > (self.openTime or 0)) then
		self:Remove()
	end

	self.bTabHeld = down
end

vgui.Register("ixFOMenu", PANEL, "EditablePanel")

--[[
	Open ours instead of Helix's.

	Returning a non-nil value from a Schema hook short-circuits Helix's own
	`GM:ScoreboardShow`, so its `vgui.Create("ixMenu")` never runs.

	`fo_menu_layout helix` falls back to Helix's menu - the Fallout menu is a
	whole panel that cannot be tested from here, and a broken F1 with no way
	back would be unusable.
]]
local cvarMenuLayout = CreateClientConVar("fo_menu_layout", "fallout", true, false,
	"F1 menu: 'fallout' for the Phoenix-style centred window, 'helix' for stock.")

--[[
	The automatic fallback is SESSION-ONLY, and this is why.

	It used to do `RunConsoleCommand("fo_menu_layout", "helix")`. That convar is
	FCVAR_ARCHIVE, so a single crash wrote "helix" into the player's config and
	kept it there - and because the check at the top of the function returns
	before anything is attempted, every later session silently used Helix's
	menu with NO error to explain why. A fixed bug looked exactly like a broken
	one, and the only way out was knowing to type the convar back.

	A flag instead. It resets on Lua refresh, map change and reconnect, so the
	fallback lasts exactly as long as the problem might.
]]
local bFallenBack = false

function Schema:ScoreboardShow()
	if (cvarMenuLayout:GetString():lower() == "helix") then return end
	if (bFallenBack) then return end
	if (not LocalPlayer():GetCharacter()) then return end

	if (IsValid(ix.gui.menu)) then
		ix.gui.menu:Remove()
		return true
	end

	local ok, err = pcall(vgui.Create, "ixFOMenu")

	if (not ok) then
		ErrorNoHalt("[falloutrp] Fallout menu failed, falling back to Helix's: "
			.. tostring(err) .. "\n")
		ErrorNoHalt("[falloutrp] It will be retried on the next Lua refresh, " ..
			"map change or reconnect.\n")

		bFallenBack = true

		return
	end

	return true
end

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_menu.lua")

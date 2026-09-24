--[[
	The loot configurer.

	A GECK equivalent, laid out around the thing the GECK could not show you:
	the TREE. Their editor gave one flat list per table and left the nesting in
	your head, so a drop that runs through four tables at 60%, 50%, 25% and 12%
	was a number nobody could state. Here every row carries the percentage of
	one container roll that actually reaches it.

	    LEFT     every table, with what it does under its name
	    CENTRE   TREE - the table expanded, with real odds on every branch
	             ENTRIES - the same entries as a flat editable list
	             PREVIEW - roll it a thousand times and total what came out
	             HELP - what each setting means, in words
	    RIGHT    the inspector: the selected table or entry, with an
	             explanation under every field, and the fields the current mode
	             ignores greyed out rather than silently doing nothing

	WHY EVERY FIELD CARRIES PROSE. This is an editor for probabilities, used
	occasionally, by people who did not write it. A label reading "WEIGHT" only
	means something to someone who already knows the model. The line under it
	costs a row of pixels and removes the guessing.

	NOTHING IS SIZED BY EYE. Row heights come from the measured height of the
	fonts in them, the right-hand columns from the measured width of the widest
	value they can hold, and any name too long for what is left is cut with an
	ellipsis rather than run under the column beside it. Text that does not fit
	is a bug, not a resolution.

	The client never touches storage. It sends the edited table to the server,
	which validates and persists.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	The menu fonts are shared, and built in `libs/cl_menufonts.lua`.

	They were defined here, privately, and created from this panel's `Init` -
	which meant the class name viewer, which uses the same five, drew with
	fonts that did not exist unless this window had been opened first.
]]
local ellipsisCache = {}


--[[
	Cleared when the fonts are rebuilt: every cached measurement was taken
	against the old sizes.
]]
hook.Add("OnScreenSizeChanged", "ixFOLootConfigFonts", function()
	ellipsisCache = {}
end)

--- Measured, never assumed. Every row height is built from these.
local function FontHeight(font)
	surface.SetFont(font)

	local _, height = surface.GetTextSize("Wg")

	return height
end

local function TextWidth(text, font)
	surface.SetFont(font)

	local width = surface.GetTextSize(text)

	return width
end

--[[
	Cut a string to fit the space it has, with an ellipsis.

	Binary search rather than trimming a character at a time: an item name is
	short, but a table name eight levels deep has very little room left, and
	the linear version does forty measurements to find that out.

	Memoised on top of that, because every row measures its own name every
	frame: sixty visible rows times eight measurements is five hundred text
	measurements a frame for an answer that changes only when the panel is
	resized. The cache is cleared with the fonts, which is the one thing that
	can invalidate it.
]]
local function Ellipsis(text, font, maxWidth)
	maxWidth = math.floor(maxWidth)

	local key = font .. "|" .. maxWidth .. "|" .. text
	local cached = ellipsisCache[key]

	if (cached) then return cached end

	surface.SetFont(font)

	if (maxWidth <= 0) then return "" end

	if (surface.GetTextSize(text) <= maxWidth) then
		ellipsisCache[key] = text

		return text
	end

	local low, high = 0, #text

	while (low < high) do
		local middle = math.floor((low + high + 1) * 0.5)

		if (surface.GetTextSize(string.sub(text, 1, middle) .. "...") <= maxWidth) then
			low = middle
		else
			high = middle - 1
		end
	end

	local result = string.sub(text, 1, low) .. "..."

	ellipsisCache[key] = result

	return result
end

--- Break text into lines that fit a width. Used by every explanation.
local function Wrap(text, font, maxWidth)
	surface.SetFont(font)

	local lines = {}
	local line = ""

	for word in string.gmatch(text, "%S+") do
		local candidate = line == "" and word or line .. " " .. word

		if (surface.GetTextSize(candidate) <= maxWidth) then
			line = candidate
		else
			if (line ~= "") then
				lines[#lines + 1] = line
			end

			line = word
		end
	end

	if (line ~= "") then
		lines[#lines + 1] = line
	end

	return lines
end

--[[
	A paragraph that sizes itself to whatever width it is given.

	Wrapping in `PerformLayout` rather than at creation is what makes the
	promise about text not being cut off keepable: a panel does not know how
	wide it is until it has been laid out, and a paragraph wrapped against a
	guess is wrong on every screen except the one it was guessed on.
]]
local function AddProse(parent, text, font, colour, topMargin)
	local prose = parent:Add("Panel")

	prose:Dock(TOP)
	prose:DockMargin(0, topMargin or 0, 0, 0)
	prose:SetTall(FontHeight(font))

	prose.lines = {}
	prose.cacheWidth = -1

	prose.SetProse = function(pnl, value)
		text = value or ""
		pnl.cacheWidth = -1
		pnl:InvalidateLayout()
	end

	prose.PerformLayout = function(pnl, width)
		if (pnl.cacheWidth == width or width < 1) then return end

		pnl.cacheWidth = width
		pnl.lines = Wrap(text, font, width)
		pnl:SetTall(math.max(#pnl.lines, 1) * (FontHeight(font) + Scaled(3)))
		pnl:InvalidateParent()
	end

	prose.Paint = function(pnl)
		local lineHeight = FontHeight(font) + Scaled(3)
		local resolved = isfunction(colour) and colour() or colour

		for index, line in ipairs(pnl.lines) do
			draw.SimpleText(line, font, 0, (index - 1) * lineHeight, resolved,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	return prose
end

--[[
	Mode colours.

	Fixed rather than themed, because they carry information: "which tables use
	every entry" is the question you ask most often of a tree, and it is
	answerable at a glance only if ALL is always the same colour.
]]
local MODE_COLOR = {
	all = Color(110, 205, 125),
	one = Color(235, 165, 70),
	rolls = Color(110, 175, 235),
	level = Color(195, 140, 230)
}

local COLOR_TABLE = Color(235, 185, 95)
local COLOR_ITEM = Color(214, 218, 222)
local COLOR_DIM = Color(134, 138, 146)
local COLOR_BAD = Color(232, 96, 96)
local COLOR_GOOD = Color(110, 205, 125)
local COLOR_PANEL = Color(28, 28, 34, 235)
local COLOR_ROW = Color(38, 38, 45, 255)
local COLOR_ROW_HOVER = Color(53, 53, 63, 255)
local COLOR_ROW_ACTIVE = Color(70, 58, 32, 255)
local COLOR_LINE = Color(58, 58, 68, 255)

--[[
	What every setting means, in one place.

	The inspector puts these under their fields, the HELP tab prints them as a
	reference, and the tree quotes them in its tooltips - so the wording is
	changed once rather than in three places that drift apart.
]]
local FIELD_HELP = {
	name = "What this table is called. Entries in other tables point at this " ..
		"name, so renaming a table that others reference will break them.",
	spawnChance = "How often this table produces anything at all. It is rolled " ..
		"before anything inside it is looked at, so at 60 four openings in ten " ..
		"skip this table and its whole branch. 100 means always.",
	mode = "How entries are chosen once the table fires. This is the setting " ..
		"that decides whether the entries below compete with each other or all " ..
		"happen together.",
	rolls = "How many independent picks to make. The same entry can come up " ..
		"twice. Only used by ROLL N TIMES.",
	weight = "How likely this entry is compared to the others, when only some " ..
		"get picked. Weight 10 against nine entries of weight 1 is picked half " ..
		"the time. It is relative, not a percentage, and weight 0 parks an entry " ..
		"without deleting it. Ignored by USE ALL ENTRIES.",
	chance = "A second gate, applied after this entry has been picked. At 25 the " ..
		"entry wins the pick and then produces nothing three times in four. Use " ..
		"it for 'rare, on top of everything else'.",
	count = "How many. Set MIN and MAX the same for a fixed amount, or apart for " ..
		"a range rolled evenly between them. For a sub-table this is how many " ..
		"times that table is rolled, not how many items it gives.",
	level = "The lowest looter level that can get this entry. Only used by BY " ..
		"LEVEL, where it is a floor rather than a band - a level 20 character " ..
		"still qualifies for level 1 entries, so common loot never stops.",
	lock = "Whether a container placed from here comes out LOCKED, and how "
		.. "hard it is. A locked one shows the lockpicking screen instead of "
		.. "its contents, costs bobby pins to open, and locks itself again "
		.. "when its loot respawns - so it is a lock every time somebody comes "
		.. "back, not only the first time. None is an ordinary container.",

	model = "The prop used for containers placed from this menu or with the " ..
		"tool. It changes nothing about the loot."
}

local MODE_HELP = {
	one = "One entry is chosen, by weight. With nine entries, eight of them " ..
		"produce nothing this time. The default, and what you want for 'a " ..
		"container gives one thing from this list'.",
	all = "Every entry is used, every time the table fires. Weights are ignored " ..
		"- an entry either happens or it does not, decided by its own chance. " ..
		"Use it for a table that is a checklist rather than a lottery.",
	rolls = "N separate picks by weight, each independent, so the same entry can " ..
		"come up more than once. Use it for 'three random things from this list'.",
	level = "One entry, by weight, from the ones the looter's level allows. " ..
		"Entries above their level are not candidates at all. Use it to keep " ..
		"high-end loot out of low-level hands."
}

--------------------------------------------------------------------------------
-- Small building blocks
--------------------------------------------------------------------------------

--- A flat, hoverable row. Used everywhere a list needs clickable lines.
local function AddRow(parent, height, bMargin)
	local row = parent:Add("DButton")

	row:Dock(TOP)
	row:SetTall(height)
	row:SetText("")

	if (bMargin ~= false) then
		row:DockMargin(0, 0, 0, Scaled(2))
	end

	row.bActive = false

	row.Paint = function(pnl, width, rowHeight)
		local colour = COLOR_ROW

		if (pnl.bActive) then
			colour = COLOR_ROW_ACTIVE
		elseif (pnl:IsHovered()) then
			colour = COLOR_ROW_HOVER
		end

		surface.SetDrawColor(colour)
		surface.DrawRect(0, 0, width, rowHeight)

		if (pnl.bActive) then
			surface.SetDrawColor(ix.fallout.GetPalette().color_primary)
			surface.DrawRect(0, 0, Scaled(3), rowHeight)
		end

		if (pnl.PaintRow) then
			pnl:PaintRow(width, rowHeight)
		end
	end

	row.OnCursorEntered = function()
		ix.fallout.PlayUISound("hover")
	end

	return row
end

--- A section heading: accent text with a hairline under it.
local function AddHeading(parent, text, topMargin)
	local heading = parent:Add("Panel")

	heading:Dock(TOP)
	heading:SetTall(FontHeight("ixLootHeader") + Scaled(10))
	heading:DockMargin(0, topMargin or Scaled(8), 0, Scaled(4))

	heading.SetHeading = function(pnl, value)
		text = value
	end

	heading.Paint = function(_, width, height)
		draw.SimpleText(text, "ixLootHeader", 0, height - Scaled(5),
			ix.fallout.GetPalette().color_primary,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		surface.SetDrawColor(COLOR_LINE)
		surface.DrawRect(0, height - 1, width, 1)
	end

	return heading
end

--[[
	A mode badge, drawn right-aligned inside a fixed column.

	The column is fixed and the badge is not: a badge that changed the layout
	around it would make the percentages jitter from row to row, and a column
	of numbers you cannot compare down the page is worth nothing.
]]
local function DrawBadge(text, colour, right, y, height)
	local width = TextWidth(text, "ixLootBadge") + Scaled(14)
	local x = right - width

	surface.SetDrawColor(colour.r * 0.24 + 16, colour.g * 0.24 + 16,
		colour.b * 0.24 + 16, 255)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(colour.r, colour.g, colour.b, 165)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	draw.SimpleText(text, "ixLootBadge", x + width * 0.5, y + height * 0.5,
		colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

--------------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------------

function PANEL:Init()
	if (IsValid(ix.gui.lootConfig)) then
		ix.gui.lootConfig:Remove()
	end

	ix.gui.lootConfig = self

	--[[
		Built here rather than at file scope, and rebuilt on every open: the
		sizes depend on the theme's scale, and re-running `surface.CreateFont`
		with the same arguments is free.
	]]
	ix.fallout.LoadMenuFonts()

	--[[
		Clamped to the screen as well as to a maximum. The maximum stops it
		being a wall on an ultrawide; the clamp stops it running off the bottom
		on a laptop, which is the failure that actually cuts text off.
	]]
	self:SetSize(
		math.min(ScrW() - Scaled(60), Scaled(1340)),
		math.min(ScrH() - Scaled(60), Scaled(820))
	)

	self:Center()
	self:MakePopup()
	self:SetTitle("LOOT CONFIGURER")

	--- The name of the saved table being edited, or nil for an unsaved one.
	self.selected = nil
	--- The editable copy. Everything the UI changes changes this.
	self.working = nil
	self.entryIndex = nil
	self.dirty = false
	self.page = "tree"
	self.previewLevel = 1
	self.filter = ""
	--- Which tree branches are open, keyed by path.
	self.expanded = {}

	self:BuildFooter()
	self:BuildTableColumn()
	self:BuildInspector()
	self:BuildCentre()

	self:RefreshAll()
end

function PANEL:Notify(text, bBad)
	self.hintText = text
	self.hintBad = bBad == true
	self.hintTime = RealTime()
end

--------------------------------------------------------------------------------
-- Footer
--------------------------------------------------------------------------------

function PANEL:BuildFooter()
	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(34))
	footer:DockMargin(0, Scaled(10), 0, 0)

	local function Button(text, width, tooltip, callback)
		local button = footer:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(Scaled(width))
		button:DockMargin(Scaled(6), 0, 0, 0)
		button:SetText(text)
		button:SetFont("ixLootHeader")
		button:SetContentAlignment(5)
		button:SetTooltip(tooltip)
		button.DoClick = callback

		return button
	end

	Button("CLOSE", 88, "Shut the configurer. Unsaved changes are lost.",
		function() self:Remove() end)

	Button("PLACE HERE", 128,
		"Drop one container where you are looking, using this table.", function()
		if (not self.working) then
			self:Notify("Pick a table first.", true)
			return
		end

		if (self.dirty) then
			self:Notify("Save the table before placing - a container uses the SAVED copy.", true)
			return
		end

		net.Start("ixLootPlace")
			net.WriteString(self.working.name)
			net.WriteString(self.modelValue or "")
			net.WriteUInt(self.lockValue or 0, 4)
		net.SendToServer()

		self:Notify(self.lockValue and self.lockValue > 0
			and ("Placed one container, locked (" ..
				ix.lockpick.Name(self.lockValue) .. ").")
			or "Placed one container.")
	end)

	--[[
		The tool is the fast path and this dialog is the slow one, so the
		dialog points at the tool rather than pretending to be the way to place
		a map's worth of containers.
	]]
	Button("ARM TOOL", 116,
		"Load this table onto the lootable tool and equip it, for placing many.",
		function()
			if (not self.working) then
				self:Notify("Pick a table first.", true)
				return
			end

			RunConsoleCommand("lootable_table", self.working.name)
			RunConsoleCommand("lootable_model", self.modelValue or "")
			RunConsoleCommand("lootable_lock", tostring(self.lockValue or 0))
			RunConsoleCommand("gmod_tool", "lootable")

			self:Notify("Tool armed with " .. self.working.name ..
				" - left click to place, reload to remove.")
		end)

	self.saveButton = Button("SAVE", 100, "Send this table to the server.",
		function() self:Save() end)

	--[[
		The hint line is painted rather than a label so it can carry a colour
		and a fade without a second panel. It is the only place errors from the
		editor appear, so it has the width left over rather than a fixed slice.
	]]
	local hint = footer:Add("Panel")

	hint:Dock(FILL)

	hint.Paint = function(_, width, height)
		if (not self.hintText) then return end

		local age = RealTime() - (self.hintTime or 0)
		local alpha = math.Clamp(255 - math.max(age - 8, 0) * 120, 0, 255)

		if (alpha < 1) then return end

		local colour = self.hintBad and COLOR_BAD or COLOR_DIM

		draw.SimpleText(Ellipsis(self.hintText, "ixLootRow", width - Scaled(8)),
			"ixLootRow", 0, height * 0.5, ColorAlpha(colour, alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

--------------------------------------------------------------------------------
-- Left column: the table list
--------------------------------------------------------------------------------

function PANEL:BuildTableColumn()
	local column = self:Add("Panel")

	column:Dock(LEFT)
	column:SetWide(Scaled(228))

	local heading = column:Add("Panel")

	heading:Dock(TOP)
	heading:SetTall(FontHeight("ixLootHeader") + Scaled(8))

	heading.Paint = function(_, width, height)
		draw.SimpleText("LOOT TABLES", "ixLootHeader", 0, height - Scaled(4),
			ix.fallout.GetPalette().color_primary,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		draw.SimpleText(#ix.loot.GetNames() .. " total", "ixLootSmall", width,
			height - Scaled(5), COLOR_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

		surface.SetDrawColor(COLOR_LINE)
		surface.DrawRect(0, height - 1, width, 1)
	end

	self.tableSearch = column:Add("ixFOTextEntry")
	self.tableSearch:Dock(TOP)
	self.tableSearch:SetTall(Scaled(26))
	self.tableSearch:DockMargin(0, Scaled(6), 0, Scaled(6))
	self.tableSearch:SetFont("ixLootRow")
	self.tableSearch:SetUpdateOnType(true)
	self.tableSearch:SetPlaceholderText("Search tables")
	self.tableSearch.OnValueChange = function(_, text)
		self.tableFilter = string.lower(string.Trim(text or ""))
		self:RefreshTableList()
	end

	local new = column:Add("ixFOButton")

	new:Dock(BOTTOM)
	new:SetTall(Scaled(28))
	new:DockMargin(0, Scaled(6), 0, 0)
	new:SetText("NEW TABLE")
	new:SetFont("ixLootHeader")
	new:SetContentAlignment(5)
	new:SetTooltip("Start an empty table. It does not exist until you save it.")
	new.DoClick = function()
		self:OpenTable(nil, ix.loot.Normalise(ix.loot.NewTable("New Table")))
		self:MarkDirty()
		self:Notify("Name it in the inspector, add entries, then SAVE.")
	end

	self.tableList = column:Add("ixFOScrollPanel")
	self.tableList:Dock(FILL)
end

function PANEL:RefreshTableList()
	self.tableList:Clear()

	local nameHeight = FontHeight("ixLootRow")
	local subHeight = FontHeight("ixLootSmall")
	local rowHeight = nameHeight + subHeight + Scaled(14)
	local shown = 0

	for _, name in ipairs(ix.loot.GetNames()) do
		if (self.tableFilter and self.tableFilter ~= ""
		and not string.find(string.lower(name), self.tableFilter, 1, true)) then
			continue
		end

		local lootTable = ix.loot.Get(name)
		local row = AddRow(self.tableList, rowHeight)

		shown = shown + 1
		row.bActive = self.selected == name
		row:SetTooltip(string.format(
			"%s\n%d entr%s, %s, fires %s of the time.\nClick to open it.",
			name, #(lootTable.items or {}),
			#(lootTable.items or {}) == 1 and "y" or "ies",
			ix.loot.modeNames[lootTable.mode or "one"],
			ix.loot.FormatChance(lootTable.spawnChance or 100)))

		row.PaintRow = function(pnl, width, height)
			local pad = Scaled(9)
			local badgeWidth = TextWidth("BY LEVEL", "ixLootBadge") + Scaled(14)

			draw.SimpleText(
				Ellipsis(name, "ixLootRow", width - pad * 2),
				"ixLootRow", pad, Scaled(6), COLOR_TABLE,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local mode = lootTable.mode or "one"
			local subtitle = string.format("%d entries  ·  %s",
				#(lootTable.items or {}),
				ix.loot.FormatChance(lootTable.spawnChance or 100))

			draw.SimpleText(
				Ellipsis(subtitle, "ixLootSmall", width - pad * 2 - badgeWidth - Scaled(6)),
				"ixLootSmall", pad, height - Scaled(6), COLOR_DIM,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			DrawBadge(ix.loot.ModeBadge(lootTable), MODE_COLOR[mode] or COLOR_DIM,
				width - pad, height - subHeight - Scaled(7),
				subHeight + Scaled(4))

			if (pnl.bActive and self.dirty) then
				draw.SimpleText("UNSAVED", "ixLootBadge", width - pad, Scaled(7),
					COLOR_BAD, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			end
		end

		row.DoClick = function()
			self:OpenTable(name)
		end
	end

	if (shown == 0) then
		local empty = self.tableList:Add("Panel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty.Paint = function(_, width, height)
			draw.SimpleText(#ix.loot.GetNames() == 0
				and "No tables yet - make one." or "Nothing matches that search.",
				"ixLootSmall", width * 0.5, height * 0.5, COLOR_DIM,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

--[[
	Open a table for editing.

	Always on a COPY, normalised. Without the copy, editing a table and
	clicking away would leave the client's mirror altered while the server
	still holds the original - and the mirror is what the tree, the tool and
	the preview all read.
]]
function PANEL:OpenTable(name, prepared)
	local function Load()
		if (prepared) then
			self.selected = nil
			self.working = prepared
		else
			local lootTable = ix.loot.Get(name)

			if (not lootTable) then return end

			self.selected = name
			self.working = ix.loot.Normalise(table.Copy(lootTable))
			self.dirty = false
		end

		self.entryIndex = nil
		self.previewResults = nil
		self.expanded = {[""] = true}

		--[[
			The first two levels open by default. All of it open is unreadable
			on a real table and none of it open makes you click to learn
			anything at all.
		]]
		for index = 1, #(self.working.items or {}) do
			self.expanded["/" .. index] = true
		end

		self:RefreshAll()
		ix.fallout.PlayUISound("select")
	end

	if (self.dirty and self.working) then
		Derma_Query(
			"'" .. self.working.name .. "' has changes that are not saved.\n" ..
			"Open another table and lose them?",
			"Unsaved changes",
			"Discard them", Load,
			"Go back", function() end)

		return
	end

	Load()
end

--------------------------------------------------------------------------------
-- Centre: the tabbed area
--------------------------------------------------------------------------------

function PANEL:BuildCentre()
	local column = self:Add("Panel")

	column:Dock(FILL)
	column:DockMargin(Scaled(10), 0, Scaled(10), 0)

	local tabs = column:Add("Panel")

	tabs:Dock(TOP)
	tabs:SetTall(Scaled(28))

	self.tabs = {}

	local function Tab(key, text, tooltip)
		local button = tabs:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(112))
		button:DockMargin(0, 0, Scaled(5), 0)
		button:SetText(text)
		button:SetFont("ixLootHeader")
		button:SetContentAlignment(5)
		button:SetTooltip(tooltip)
		button.DoClick = function()
			self.page = key
			self:RefreshCentre()
		end

		self.tabs[key] = button
	end

	Tab("tree", "TREE", "This table expanded, with the real odds on every branch.")
	Tab("entries", "ENTRIES", "The same entries as a flat list you can reorder.")
	Tab("preview", "PREVIEW", "Roll the table a thousand times and total the results.")
	Tab("help", "HELP", "What every setting means.")

	--[[
		The level box lives in the tab bar because both the tree and the
		preview depend on it, and a control that changes two pages does not
		belong inside either of them.
	]]
	local levelBox = tabs:Add("Panel")

	levelBox:Dock(RIGHT)
	levelBox:SetWide(Scaled(150))
	levelBox:SetTooltip(
		"Work the odds out as if the looter were this level.\n" ..
		"Only changes anything for tables using BY LEVEL.")

	--[[
		The label is MEASURED and the box docked past it, rather than the box
		being given a guessed reserve. A label drawn over its own field is the
		exact failure this menu is meant not to have.
	]]
	local levelLabel = "AT LEVEL"

	levelBox.Paint = function(_, _, height)
		draw.SimpleText(levelLabel, "ixLootSmall", 0, height * 0.5, COLOR_DIM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	self.levelEntry = self:NumberEntry(levelBox, 1, 100, false, function(value)
		self.previewLevel = value
		self:RefreshCentre()
	end)

	self.levelEntry:Dock(FILL)
	self.levelEntry:DockMargin(TextWidth(levelLabel, "ixLootSmall") + Scaled(8),
		0, 0, 0)
	self.levelEntry:SetValue("1")

	self.centre = column:Add("Panel")
	self.centre:Dock(FILL)
	self.centre:DockMargin(0, Scaled(8), 0, 0)

	self.centreScroll = self.centre:Add("ixFOScrollPanel")
	self.centreScroll:Dock(FILL)
end

function PANEL:RefreshCentre()
	for key, button in pairs(self.tabs) do
		button:SetActive(self.page == key)
	end

	self.centreScroll:Clear()

	if (self.page == "help") then
		self:BuildHelpPage()
		return
	end

	if (not self.working) then
		local empty = self.centreScroll:Add("Panel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(90))
		empty.Paint = function(_, width, height)
			draw.SimpleText("Pick a table on the left, or make a new one.",
				"ixLootRow", width * 0.5, height * 0.5 - Scaled(10), COLOR_DIM,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("The HELP tab explains what all of this does.",
				"ixLootSmall", width * 0.5, height * 0.5 + Scaled(12), COLOR_DIM,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return
	end

	if (self.page == "tree") then
		self:BuildTreePage()
	elseif (self.page == "entries") then
		self:BuildEntriesPage()
	else
		self:BuildPreviewPage()
	end
end

--[[
	Build the tree from the WORKING copy, not the saved one.

	`ix.loot.BuildTree` walks `ix.loot.tables` because a tree crosses table
	boundaries - it has to look up every sub-table by name. So the working copy
	is put in the mirror for the duration of the walk and taken straight back
	out. The alternative is a tree that shows what the server last saved, which
	is the wrong answer to "what does this do" while you are editing it.

	Restoring to `saved` puts a nil back for a table that does not exist yet,
	which removes the temporary entry rather than leaving an unsaved table in
	the mirror for the placer tool to offer.
]]
function PANEL:WithWorkingTable(callback)
	local name = self.working.name
	local saved = ix.loot.tables[name]

	ix.loot.tables[name] = self.working

	local a, b, c = callback()

	ix.loot.tables[name] = saved

	return a, b, c
end

--------------------------------------------------------------------------------
-- The tree
--------------------------------------------------------------------------------

--[[
	The expander triangle, drawn rather than typed.

	A glyph would be one character of Lua, and Roboto has no dependable
	triangle - the fallback would be a box on some machines and nothing on
	others. Two polygons always draw.
]]
local function DrawArrow(x, y, size, bOpen, colour)
	draw.NoTexture()
	surface.SetDrawColor(colour)

	if (bOpen) then
		surface.DrawPoly({
			{x = x, y = y - size * 0.35},
			{x = x + size, y = y - size * 0.35},
			{x = x + size * 0.5, y = y + size * 0.45}
		})
	else
		surface.DrawPoly({
			{x = x + size * 0.2, y = y - size * 0.55},
			{x = x + size * 0.2, y = y + size * 0.55},
			{x = x + size, y = y}
		})
	end
end

--- The count label for an entry: "x1", "x1-3", or nothing where it means nothing.
local function CountLabel(entry)
	if (not entry) then return "" end

	local minimum = entry.min or 1
	local maximum = entry.max or minimum

	if (minimum == maximum) then
		return "x" .. minimum
	end

	return string.format("x%d-%d", minimum, maximum)
end

--[[
	One line of explanation for a node, shown on hover.

	This is where the arithmetic gets shown rather than asserted. A row saying
	"3.55%" is a claim; the tooltip says which chances multiplied to make it,
	which is the difference between a number you trust and one you work around.
]]
function PANEL:DescribeNode(node)
	local lines = {}

	if (node.kind == "table") then
		lines[#lines + 1] = node.name
		lines[#lines + 1] = string.format("A table: %s, %d entr%s.",
			ix.loot.modeNames[node.mode or "one"] or node.mode,
			node.entryCount or 0, (node.entryCount or 0) == 1 and "y" or "ies")
		lines[#lines + 1] = string.format("It fires %s of the times it is reached.",
			ix.loot.FormatChance(node.spawnChance or 100))
	elseif (node.kind == "missing") then
		lines[#lines + 1] = node.name
		lines[#lines + 1] = "BROKEN: " .. (node.note or "cannot be resolved")
	else
		lines[#lines + 1] = node.label
		lines[#lines + 1] = "Item: " .. node.name
	end

	if (node.entry) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Weight " .. (node.entry.weight or 1) ..
			"   chance " .. ix.loot.FormatChance(node.entry.chance or 100) ..
			"   " .. CountLabel(node.entry) ..
			((node.entry.level or 1) > 1 and ("   level " .. node.entry.level) or "")
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = string.format(
		"%s of container openings reach this, at level %d.",
		ix.loot.FormatChance(node.chance), self.previewLevel)

	if (node.note and node.kind == "table") then
		lines[#lines + 1] = "NOTE: " .. node.note
	end

	if (node.kind == "table" and node.depth > 1) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Right click to open this table for editing."
	elseif (node.owned) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Click to edit this entry in the inspector."
	end

	return table.concat(lines, "\n")
end

function PANEL:BuildTreePage()
	local scroll = self.centreScroll

	--[[
		The legend is not decoration. Three of the four columns are things the
		reader has to be told the meaning of once, and a column of percentages
		with no statement of what they are a percentage OF is the single
		easiest way to mislead someone with this menu.
	]]
	local legend = scroll:Add("Panel")

	legend:Dock(TOP)
	legend:SetTall(FontHeight("ixLootSmall") * 2 + Scaled(16))
	legend:DockMargin(0, 0, 0, Scaled(6))

	legend.Paint = function(_, width, height)
		surface.SetDrawColor(COLOR_PANEL)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(COLOR_LINE)
		surface.DrawRect(0, height - 1, width, 1)

		draw.SimpleText(
			Ellipsis("Every percentage is the share of ONE container opening " ..
				"that reaches that row, with all its parents' odds applied.",
				"ixLootSmall", width - Scaled(16)),
			"ixLootSmall", Scaled(8), Scaled(6), COLOR_ITEM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(
			Ellipsis("Click a row to open or close it and to select it. " ..
				"Right click a sub-table to go and edit that table.",
				"ixLootSmall", width - Scaled(16)),
			"ixLootSmall", Scaled(8), height - Scaled(6), COLOR_DIM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	local tools = scroll:Add("Panel")

	tools:Dock(TOP)
	tools:SetTall(Scaled(26))
	tools:DockMargin(0, 0, 0, Scaled(6))

	local function ToolButton(text, tooltip, callback)
		local button = tools:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(112))
		button:DockMargin(0, 0, Scaled(5), 0)
		button:SetText(text)
		button:SetFont("ixLootSmall")
		button:SetContentAlignment(5)
		button:SetTooltip(tooltip)
		button.DoClick = callback
	end

	local root = self:WithWorkingTable(function()
		return ix.loot.BuildTree(self.working.name, self.previewLevel)
	end)

	--[[
		EXPAND ALL marks every path in the tree rather than setting a flag the
		drawing checks. A flag would be one line shorter and would collapse the
		whole tree the moment you clicked any row - because the first click
		would have to clear the flag, and nothing underneath it would then be
		recorded as open.
	]]
	ToolButton("EXPAND ALL", "Open every branch, as deep as it goes.", function()
		self:MarkExpanded(root, "")
		self:RefreshCentre()
	end)

	ToolButton("COLLAPSE ALL", "Close everything back to the root.", function()
		self.expanded = {[""] = true}
		self:RefreshCentre()
	end)

	self:AddTreeNode(root, "", 0)

	if (#root.children == 0) then
		local empty = scroll:Add("Panel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(64))
		empty.Paint = function(_, width, height)
			draw.SimpleText("This table has no entries yet.", "ixLootRow",
				width * 0.5, height * 0.5 - Scaled(9), COLOR_DIM,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Use ADD ITEM or ADD SUB-TABLE on the right.",
				"ixLootSmall", width * 0.5, height * 0.5 + Scaled(11), COLOR_DIM,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

--- Open every branch of a built tree, keyed the same way the rows are.
function PANEL:MarkExpanded(node, path)
	self.expanded[path] = true

	for _, child in ipairs(node.children or {}) do
		self:MarkExpanded(child, path .. "/" .. (child.index or 0))
	end
end

function PANEL:AddTreeNode(node, path, indentLevel)
	local scroll = self.centreScroll
	local rowHeight = FontHeight("ixLootRow") + Scaled(13)
	local row = AddRow(scroll, rowHeight, false)

	row:DockMargin(0, 0, 0, 1)

	local expandable = node.children and #node.children > 0
	local isOpen = self.expanded[path] == true

	row.bActive = node.owned and node.index == self.entryIndex
	row:SetTooltip(self:DescribeNode(node))

	--[[
		The right-hand columns are sized from the WIDEST value each can hold,
		measured, not guessed. That is what keeps the numbers in a straight
		line down the page and keeps a long item name from running underneath
		them - the name is cut instead, which is the loss you can afford.
	]]
	local percentWidth = math.max(
		TextWidth("100%", "ixLootRow"),
		TextWidth("0.00e-00%", "ixLootRow")) + Scaled(14)
	local countWidth = TextWidth("x99-99", "ixLootSmall") + Scaled(14)
	local badgeWidth = TextWidth("BY LEVEL", "ixLootBadge") + Scaled(24)
	local indentStep = Scaled(17)

	row.PaintRow = function(_, width, height)
		local pad = Scaled(8)
		local x = pad + indentLevel * indentStep

		--[[
			A hairline down each level the row sits under, so a leaf twenty
			rows below its table still reads as belonging to it. Drawn per row,
			which joins up into a continuous line because the rows touch.
		]]
		surface.SetDrawColor(COLOR_LINE)

		for level = 1, indentLevel do
			surface.DrawRect(pad + (level - 1) * indentStep + Scaled(5), 0, 1, height)
		end

		local colour = COLOR_ITEM

		if (node.kind == "table") then
			colour = COLOR_TABLE
		elseif (node.kind == "missing") then
			colour = COLOR_BAD
		end

		local marker = Scaled(11)

		if (expandable) then
			DrawArrow(x, height * 0.5, marker, isOpen, colour)
		elseif (node.kind == "table") then
			-- An empty table: a hollow marker, so "no children" is visible.
			surface.SetDrawColor(colour.r, colour.g, colour.b, 150)
			surface.DrawOutlinedRect(x + Scaled(3), height * 0.5 - Scaled(3),
				Scaled(6), Scaled(6), 1)
		else
			surface.SetDrawColor(colour.r, colour.g, colour.b, 130)
			surface.DrawRect(x + Scaled(3), height * 0.5 - Scaled(2),
				Scaled(4), Scaled(4))
		end

		x = x + marker + Scaled(7)

		local right = width - pad
		local reserved = percentWidth + countWidth + badgeWidth

		draw.SimpleText(
			Ellipsis(node.label, "ixLootRow", right - x - reserved),
			"ixLootRow", x, height * 0.5, colour,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(ix.loot.FormatChance(node.chance), "ixLootRow",
			right, height * 0.5,
			node.chance <= 0 and COLOR_BAD or ix.fallout.GetPalette().color_primary,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local countText = CountLabel(node.entry)

		if (countText ~= "") then
			draw.SimpleText(countText, "ixLootSmall",
				right - percentWidth, height * 0.5, COLOR_DIM,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		if (node.kind == "table" and node.badge) then
			DrawBadge(node.badge, MODE_COLOR[node.mode or "one"] or COLOR_DIM,
				right - percentWidth - countWidth, height * 0.5 - Scaled(8),
				Scaled(16))
		end

		if (node.cycle or (node.kind == "missing")) then
			draw.SimpleText("!", "ixLootBadge", pad * 0.5, height * 0.5,
				COLOR_BAD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	row.DoClick = function()
		--[[
			One click does both things it can sensibly do: it opens or closes
			the branch, and if the row is an entry of the table being edited it
			also selects it. Splitting them would mean an extra hit area on
			every row for no gain - selecting a row you cannot edit is the only
			case, and there the expand is what you wanted anyway.
		]]
		if (expandable) then
			self.expanded[path] = not self.expanded[path]
		end

		if (node.owned) then
			self.entryIndex = node.index
			self:RefreshInspector()
		end

		self:RefreshCentre()
		ix.fallout.PlayUISound("select")
	end

	row.DoRightClick = function()
		if (node.kind ~= "table" or node.depth == 1) then return end

		self:OpenTable(node.name)
	end

	if (expandable and isOpen) then
		for _, child in ipairs(node.children) do
			self:AddTreeNode(child, path .. "/" .. (child.index or 0), indentLevel + 1)
		end
	end
end

--------------------------------------------------------------------------------
-- Entries: the same data, flat and reorderable
--------------------------------------------------------------------------------

function PANEL:BuildEntriesPage()
	local scroll = self.centreScroll
	local working = self.working
	local picks = ix.loot.SelectionChances(working, self.previewLevel)
	local produces = ix.loot.EntryChances(working, self.previewLevel)

	local header = scroll:Add("Panel")

	header:Dock(TOP)
	header:SetTall(FontHeight("ixLootSmall") * 2 + Scaled(16))
	header:DockMargin(0, 0, 0, Scaled(6))

	header.Paint = function(_, width, height)
		surface.SetDrawColor(COLOR_PANEL)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(COLOR_LINE)
		surface.DrawRect(0, height - 1, width, 1)

		draw.SimpleText(
			Ellipsis("This table's own entries, in order. The arrows move an " ..
				"entry; order matters only for reading, not for the odds.",
				"ixLootSmall", width - Scaled(16)),
			"ixLootSmall", Scaled(8), Scaled(6), COLOR_ITEM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(
			Ellipsis("PICKED is how often this entry wins the selection; " ..
				"REACHED is that, times its own chance and its parents'.",
				"ixLootSmall", width - Scaled(16)),
			"ixLootSmall", Scaled(8), height - Scaled(6), COLOR_DIM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	if (#working.items == 0) then
		local empty = scroll:Add("Panel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(56))
		empty.Paint = function(_, width, height)
			draw.SimpleText("No entries. Add some from the inspector.",
				"ixLootRow", width * 0.5, height * 0.5, COLOR_DIM,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return
	end

	local nameHeight = FontHeight("ixLootRow")
	local subHeight = FontHeight("ixLootSmall")
	local rowHeight = nameHeight + subHeight + Scaled(14)

	for index, entry in ipairs(working.items) do
		local row = AddRow(scroll, rowHeight)
		local itemTable = entry.class and ix.item.list[entry.class]
		local isTable = entry.table ~= nil
		local broken = not isTable and not itemTable
		local label = isTable and entry.table
			or (itemTable and itemTable.name or entry.class)

		row.bActive = index == self.entryIndex
		row:SetTooltip("Click to edit this entry in the inspector.")

		--[[
			Move buttons are real panels rather than hit zones inside Paint,
			because they need their own hover state - a row where part of it
			does something different on click, with no sign of where, is worse
			than no reordering at all.
		]]
		local function MoveButton(text, offset, tooltip)
			local button = row:Add("ixFOButton")

			button:Dock(RIGHT)
			button:SetWide(Scaled(26))
			button:DockMargin(0, Scaled(4), Scaled(4), Scaled(4))
			button:SetText(text)
			button:SetFont("ixLootSmall")
			button:SetContentAlignment(5)
			button:SetTooltip(tooltip)
			button.DoClick = function()
				local target = index + offset

				if (target < 1 or target > #working.items) then return end

				working.items[index], working.items[target] =
					working.items[target], working.items[index]

				if (self.entryIndex == index) then
					self.entryIndex = target
				elseif (self.entryIndex == target) then
					self.entryIndex = index
				end

				self:MarkDirty()
				self:RefreshAll()
			end
		end

		MoveButton("v", 1, "Move this entry down.")
		MoveButton("^", -1, "Move this entry up.")

		row.PaintRow = function(_, width, height)
			local pad = Scaled(9)
			local reserved = Scaled(66) + Scaled(150)
			local colour = broken and COLOR_BAD
				or (isTable and COLOR_TABLE or COLOR_ITEM)

			draw.SimpleText(string.format("%2d", index), "ixLootSmall",
				pad, Scaled(7), COLOR_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			draw.SimpleText(
				Ellipsis(label, "ixLootRow", width - pad - Scaled(28) - reserved),
				"ixLootRow", pad + Scaled(28), Scaled(5), colour,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local detail = string.format(
				"%s   weight %s   chance %s   %s%s",
				isTable and "SUB-TABLE" or (broken and "MISSING ITEM" or "ITEM"),
				entry.weight or 1,
				ix.loot.FormatChance(entry.chance or 100),
				CountLabel(entry),
				(entry.level or 1) > 1 and ("   level " .. entry.level) or "")

			draw.SimpleText(
				Ellipsis(detail, "ixLootSmall", width - pad - Scaled(28) - reserved),
				"ixLootSmall", pad + Scaled(28), height - Scaled(6), COLOR_DIM,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			--[[
				Two different questions, and under ROLL N they are not one
				multiplication apart - see `ix.loot.EntryChances`. PICKED is
				how often the entry wins a draw; REACHED is how often it
				actually hands something over, table chance included.
			]]
			local picked = (picks[index] or 0) * 100
			local reached = (produces[index] or 0) * 100
				* (working.spawnChance or 100) / 100

			draw.SimpleText("PICKED " .. ix.loot.FormatChance(picked),
				"ixLootSmall", width - Scaled(70), Scaled(7), COLOR_DIM,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

			draw.SimpleText("REACHED " .. ix.loot.FormatChance(reached),
				"ixLootSmall", width - Scaled(70), height - Scaled(6),
				reached <= 0 and COLOR_BAD or ix.fallout.GetPalette().color_primary,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end

		row.DoClick = function()
			self.entryIndex = index
			self:RefreshInspector()
			self:RefreshCentre()
			ix.fallout.PlayUISound("select")
		end
	end
end

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------

--[[
	Preview rolls the copy being EDITED, not the copy on the server.

	The old version previewed the saved table and told you to save first, which
	is the wrong way round: preview is how you decide whether a change is right
	before committing it. Rolling the working copy is the whole value of having
	one.
]]
function PANEL:BuildPreviewPage()
	local scroll = self.centreScroll

	local bar = scroll:Add("Panel")

	bar:Dock(TOP)
	bar:SetTall(Scaled(30))
	bar:DockMargin(0, 0, 0, Scaled(6))

	local function RunButton(text, runs)
		local button = bar:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(104))
		button:DockMargin(0, 0, Scaled(5), 0)
		button:SetText(text)
		button:SetFont("ixLootHeader")
		button:SetContentAlignment(5)
		button:SetTooltip(string.format(
			"Open this container %d times and total what came out.", runs))
		button.DoClick = function()
			self.previewRuns = runs
			self:RunPreview()
		end
	end

	RunButton("RUN 100", 100)
	RunButton("RUN 1000", 1000)
	RunButton("RUN 10000", 10000)

	local explain = scroll:Add("Panel")

	explain:Dock(TOP)
	explain:SetTall(FontHeight("ixLootSmall") * 2 + Scaled(16))
	explain:DockMargin(0, 0, 0, Scaled(6))

	explain.Paint = function(_, width, height)
		surface.SetDrawColor(COLOR_PANEL)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(COLOR_LINE)
		surface.DrawRect(0, height - 1, width, 1)

		draw.SimpleText(
			Ellipsis("A simulation of the table as it is edited right now, " ..
				"including changes you have not saved.", "ixLootSmall",
				width - Scaled(16)),
			"ixLootSmall", Scaled(8), Scaled(6), COLOR_ITEM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(
			Ellipsis("SEEN is the share of openings that gave the item at all; " ..
				"PER OPEN is the average number across every opening, empty ones " ..
				"included.", "ixLootSmall", width - Scaled(16)),
			"ixLootSmall", Scaled(8), height - Scaled(6), COLOR_DIM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	self.previewHost = scroll:Add("Panel")
	self.previewHost:Dock(TOP)
	self.previewHost:SetTall(Scaled(40))

	self.previewHost.Paint = function(_, width, height)
		if (self.previewResults) then return end

		draw.SimpleText("Press one of the RUN buttons.", "ixLootRow",
			width * 0.5, height * 0.5, COLOR_DIM,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (self.previewResults) then
		self:DrawPreviewResults()
	end
end

function PANEL:RunPreview()
	local runs = self.previewRuns or 1000

	local totals, empty = self:WithWorkingTable(function()
		return ix.loot.Simulate(self.working.name, runs, self.previewLevel)
	end)

	local sorted = {}

	for uniqueID, record in pairs(totals) do
		sorted[#sorted + 1] = {uniqueID = uniqueID, record = record}
	end

	table.sort(sorted, function(a, b)
		return a.record.appearances > b.record.appearances
	end)

	self.previewResults = {runs = runs, empty = empty, sorted = sorted}
	self:RefreshCentre()
end

function PANEL:DrawPreviewResults()
	local results = self.previewResults
	local host = self.previewHost

	host:SetTall(0)

	local summary = self.centreScroll:Add("Panel")

	summary:Dock(TOP)
	summary:SetTall(FontHeight("ixLootHeader") + Scaled(16))
	summary:DockMargin(0, 0, 0, Scaled(6))

	summary.Paint = function(_, width, height)
		surface.SetDrawColor(COLOR_PANEL)
		surface.DrawRect(0, 0, width, height)

		local emptyShare = results.empty / results.runs * 100

		draw.SimpleText(string.format("%d openings  ·  %d different items",
			results.runs, #results.sorted), "ixLootHeader", Scaled(8),
			height * 0.5, COLOR_ITEM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		--[[
			The empty share is the number that decides whether a container is
			worth walking to, and it is the one a flat list of drop rates never
			tells you. It gets its own colour when it is high.
		]]
		draw.SimpleText(string.format("%s gave nothing",
			ix.loot.FormatChance(emptyShare)), "ixLootHeader",
			width - Scaled(8), height * 0.5,
			emptyShare > 50 and COLOR_BAD or COLOR_GOOD,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	if (#results.sorted == 0) then
		local none = self.centreScroll:Add("Panel")

		none:Dock(TOP)
		none:SetTall(Scaled(50))
		none.Paint = function(_, width, height)
			draw.SimpleText("Nothing dropped at all. Check the spawn chance, " ..
				"the weights, and the HELP tab.", "ixLootRow",
				width * 0.5, height * 0.5, COLOR_BAD,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return
	end

	local best = results.sorted[1].record.appearances
	local rowHeight = FontHeight("ixLootRow") + Scaled(13)

	for _, result in ipairs(results.sorted) do
		local itemTable = ix.item.list[result.uniqueID]
		local row = AddRow(self.centreScroll, rowHeight)
		local share = result.record.appearances / results.runs * 100
		local average = result.record.count / results.runs

		row:SetTooltip(string.format("%s\n%s\n%d appearances over %d openings.",
			itemTable and itemTable.name or result.uniqueID,
			result.uniqueID, result.record.appearances, results.runs))

		row.PaintRow = function(_, width, height)
			local pad = Scaled(9)
			local reserved = Scaled(190)

			--[[
				The bar is behind the text rather than beside it, so the list
				reads as a list and the shape is still visible down the page.
				Scaled against the commonest result, not against 100%, because
				a table where everything is rare would otherwise be a column of
				invisible slivers.
			]]
			local fraction = result.record.appearances / best

			surface.SetDrawColor(ColorAlpha(ix.fallout.GetPalette().color_primary, 34))
			surface.DrawRect(0, 0, (width - reserved) * fraction, height)

			draw.SimpleText(
				Ellipsis(itemTable and itemTable.name or result.uniqueID,
					"ixLootRow", width - pad - reserved),
				"ixLootRow", pad, height * 0.5,
				itemTable and COLOR_ITEM or COLOR_BAD,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("PER OPEN %.2f", average), "ixLootSmall",
				width - Scaled(9), height * 0.5, COLOR_DIM,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			draw.SimpleText("SEEN " .. ix.loot.FormatChance(share), "ixLootRow",
				width - Scaled(118), height * 0.5,
				ix.fallout.GetPalette().color_primary,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

--------------------------------------------------------------------------------
-- Help
--------------------------------------------------------------------------------

--[[
	The reference, in words.

	Written out rather than linked to a document, because the person who needs
	it is in the menu with a table half built. Every paragraph here is the same
	string the inspector shows under the matching field, so the two cannot
	disagree.
]]
function PANEL:BuildHelpPage()
	local scroll = self.centreScroll

	local function Section(title)
		AddHeading(scroll, title, Scaled(12))
	end

	local function Text(text, colour)
		AddProse(scroll, text, "ixLootSmall", colour or COLOR_ITEM, Scaled(4))
	end

	Section("WHAT A LOOT TABLE IS")
	Text("A loot table is a list of things a container can produce. An entry " ..
		"in it is either an ITEM or another TABLE - and it is the second kind " ..
		"that makes this worth having: a container points at one table, that " ..
		"table picks a category, the category picks a tier, and the tier picks " ..
		"an item. Each step narrows the odds, which is how a drop ends up at a " ..
		"hundredth of a percent without anybody typing that number.")
	Text("The TREE tab shows that whole chain for the table you have open, " ..
		"with the real percentage on every branch.")

	Section("THE ORDER THINGS HAPPEN IN")
	Text("1. SPAWN CHANCE decides whether the table does anything at all.")
	Text("2. MODE decides which of its entries are used.")
	Text("3. WEIGHT decides which one wins, where only one can.")
	Text("4. The entry's own CHANCE can still cancel it after it has won.")
	Text("5. MIN and MAX decide how many.")
	Text("6. If the entry is a sub-table, all of this happens again inside it.")

	Section("THE FOUR MODES")

	for _, mode in ipairs(ix.loot.modes) do
		Text(ix.loot.modeNames[mode] .. " - " .. MODE_HELP[mode],
			MODE_COLOR[mode])
	end

	Section("EVERY FIELD")

	local fields = {
		{"SPAWN CHANCE", FIELD_HELP.spawnChance},
		{"ROLLS", FIELD_HELP.rolls},
		{"WEIGHT", FIELD_HELP.weight},
		{"CHANCE", FIELD_HELP.chance},
		{"MIN and MAX", FIELD_HELP.count},
		{"LEVEL", FIELD_HELP.level},
		{"CONTAINER MODEL", FIELD_HELP.model}
	}

	for _, field in ipairs(fields) do
		Text(field[1] .. " - " .. field[2])
	end

	Section("WEIGHT IS NOT A PERCENTAGE")
	Text("This is the one that catches people. Weight only means anything " ..
		"next to the other weights in the SAME table. Three entries of weight " ..
		"1 are a third each; change one to 8 and it becomes eight tenths while " ..
		"the other two fall to a tenth each, without either of them being " ..
		"touched. If you want a fixed percentage that does not move when you " ..
		"add entries, use the entry's CHANCE instead.")

	Section("PLACING CONTAINERS")
	Text("PLACE HERE drops one container where you are looking. For a map's " ..
		"worth, press ARM TOOL: that loads this table onto the lootable tool " ..
		"and equips it, and then left click places, right click copies the " ..
		"settings off a container you point at, and reload removes one.")
	Text("Containers are saved per map and come back after a restart. Only " ..
		"deleting one with the tool removes it for good - a cleanup does not.")

	Section("WHEN SOMETHING LOOKS WRONG")
	Text("A row in red is broken: either the item's uniqueID does not exist " ..
		"or the sub-table it names has been deleted or renamed. A row at 0% is " ..
		"reachable by nothing - usually a weight of 0, a chance of 0, or a " ..
		"level above the one you are previewing at.")
	Text("PREVIEW is the check that matters. Weights and chances multiply " ..
		"through nested tables in ways nobody can do in their head, so roll it " ..
		"a thousand times and look at what actually came out.")
end

--------------------------------------------------------------------------------
-- Field building blocks
--------------------------------------------------------------------------------

--[[
	Methods rather than local functions, purely for ordering.

	A `local function` is only in scope for text below it, and these are used
	by `BuildCentre`, which is written above. Hanging them on the panel means
	the file can be read in the order it makes sense in rather than in
	dependency order.
]]

--[[
	Make a panel exactly as tall as its docked children.

	Needed because every explanation under a field wraps to a different number
	of lines depending on how wide the inspector is, so no field has a height
	that can be written down. The equality check is what stops it looping: it
	only resizes when the answer changed.
]]
function PANEL:AutoHeight(panel)
	panel.PerformLayout = function(pnl)
		local total = 0

		for _, child in ipairs(pnl:GetChildren()) do
			if (not child:IsVisible()) then continue end

			local _, top, _, bottom = child:GetDockMargin()

			total = total + child:GetTall() + top + bottom
		end

		if (pnl:GetTall() ~= total) then
			pnl:SetTall(total)
			pnl:InvalidateParent()
		end
	end
end

--[[
	A text box that only accepts a number, clamped when you leave it.

	Clamped on focus loss rather than per keystroke: clamping as you type makes
	10 impossible to reach from an empty box with a minimum of 1, because the
	"1" is already valid and the "0" then reads as 10 - fine - but a minimum of
	5 would snap the "1" to 5 before the second key arrives.
]]
function PANEL:NumberEntry(parent, minimum, maximum, bDecimal, callback)
	local entry = parent:Add("ixFOTextEntry")

	entry:SetFont("ixLootRow")
	entry:SetTall(Scaled(26))

	entry.Apply = function(pnl)
		local value = tonumber(string.Trim(pnl:GetValue() or ""))

		if (not value) then return end

		value = math.Clamp(bDecimal and value or math.floor(value), minimum, maximum)

		pnl:SetValue(tostring(value))
		callback(value)
	end

	entry.OnEnter = function(pnl)
		pnl:Apply()
	end

	entry.OnLoseFocus = function(pnl)
		pnl:Apply()
	end

	return entry
end

--[[
	A labelled field: a heading, a control, and a line saying what it does.

	The explanation is not optional. Every caller passes one.
]]
function PANEL:Field(parent, title, help, controlHeight, build)
	local block = parent:Add("Panel")

	block:Dock(TOP)
	block:DockMargin(0, Scaled(12), 0, 0)

	local heading = block:Add("Panel")

	heading:Dock(TOP)
	heading:SetTall(FontHeight("ixLootSmall") + Scaled(5))

	heading.title = title
	heading.dim = false

	heading.Paint = function(pnl, _, height)
		draw.SimpleText(pnl.title, "ixLootSmall", 0, height - Scaled(2),
			pnl.dim and COLOR_DIM or ix.fallout.GetPalette().color_primary,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	local control = build(block)

	control:Dock(TOP)
	control:SetTall(controlHeight)

	local prose = AddProse(block, help, "ixLootSmall", COLOR_DIM, Scaled(5))

	self:AutoHeight(block)

	block.heading = heading
	block.control = control
	block.prose = prose

	--[[
		Greying a field out rather than hiding it: a setting the current mode
		ignores still needs to be visible, because "why is this doing nothing"
		is exactly the question the greying answers.
	]]
	block.SetUsed = function(pnl, bUsed, reason)
		pnl.control:SetEnabled(bUsed)
		pnl.control:SetAlpha(bUsed and 255 or 90)
		pnl.heading.dim = not bUsed
		pnl.prose:SetProse(bUsed and help or (reason .. " " .. help))
	end

	return block
end

--- Set a text box without stealing what somebody is typing into it.
function PANEL:SetFieldText(entry, value)
	if (entry:HasFocus()) then return end

	entry:SetValue(value)
end

--------------------------------------------------------------------------------
-- Right column: the inspector
--------------------------------------------------------------------------------

function PANEL:BuildInspector()
	local column = self:Add("Panel")

	column:Dock(RIGHT)
	column:SetWide(Scaled(336))

	local scroll = column:Add("ixFOScrollPanel")

	scroll:Dock(FILL)

	self.inspector = scroll

	AddHeading(scroll, "THIS TABLE", 0)

	self.nameField = self:Field(scroll, "NAME", FIELD_HELP.name, Scaled(26),
		function(parent)
			local entry = parent:Add("ixFOTextEntry")

			entry:SetFont("ixLootRow")
			entry:SetUpdateOnType(true)
			entry.OnValueChange = function(_, value)
				if (not self.working) then return end

				self.working.name = string.Trim(value or "")
				self:MarkDirty()
				self:RefreshTableList()
			end

			return entry
		end)

	self.chanceField = self:Field(scroll, "SPAWN CHANCE (%)",
		FIELD_HELP.spawnChance, Scaled(26), function(parent)
			--[[
				Free text rather than a stepper, because their own data uses
				values as small as 0.000001 for the rarest drops and any
				integer control rounds those silently to zero.
			]]
			return self:NumberEntry(parent, 0, 100, true, function(value)
				if (not self.working) then return end

				self.working.spawnChance = value
				self:MarkDirty()
				self:RefreshAll()
			end)
		end)

	self.modeField = self:Field(scroll, "MODE", MODE_HELP.one, Scaled(28),
		function(parent)
			local button = parent:Add("ixFOButton")

			button:SetFont("ixLootHeader")
			button:SetContentAlignment(5)
			button:SetTooltip("Click to cycle through the four modes.")
			button.DoClick = function()
				if (not self.working) then return end

				local index = 1

				for i, mode in ipairs(ix.loot.modes) do
					if (mode == self.working.mode) then
						index = i
						break
					end
				end

				self.working.mode = ix.loot.modes[index % #ix.loot.modes + 1]
				self:MarkDirty()
				self:RefreshAll()
			end

			return button
		end)

	self.rollsField = self:Field(scroll, "ROLLS", FIELD_HELP.rolls, Scaled(26),
		function(parent)
			return self:NumberEntry(parent, 1, 50, false, function(value)
				if (not self.working) then return end

				self.working.rolls = value
				self:MarkDirty()
				self:RefreshAll()
			end)
		end)

	local add = scroll:Add("Panel")

	add:Dock(TOP)
	add:SetTall(Scaled(28))
	add:DockMargin(0, Scaled(14), 0, 0)

	local function AddButton(text, tooltip, callback)
		local button = add:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(158))
		button:DockMargin(0, 0, Scaled(6), 0)
		button:SetText(text)
		button:SetFont("ixLootHeader")
		button:SetContentAlignment(5)
		button:SetTooltip(tooltip)
		button.DoClick = callback
	end

	AddButton("ADD ITEM", "Put an item into this table.", function()
		self:OpenPicker("item")
	end)

	AddButton("ADD SUB-TABLE", "Point this table at another one.", function()
		self:OpenPicker("table")
	end)

	AddHeading(scroll, "SELECTED ENTRY", Scaled(16))

	--[[
		The entry section is built once and shown or hidden. Rebuilding it on
		every selection would be simpler and would also throw away the caret
		of anyone mid-way through typing a number, which is what the old
		version did.
	]]
	self.entrySection = {}

	self.entryTitle = scroll:Add("Panel")
	self.entryTitle:Dock(TOP)
	self.entryTitle:SetTall(FontHeight("ixLootRow") + FontHeight("ixLootSmall")
		+ Scaled(14))
	self.entryTitle:DockMargin(0, Scaled(4), 0, 0)

	self.entryTitle.Paint = function(_, width, height)
		local entry = self:GetSelectedEntry()

		if (not entry) then
			draw.SimpleText("Nothing selected. Click a row in TREE or ENTRIES.",
				"ixLootSmall", 0, height * 0.5, COLOR_DIM,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			return
		end

		surface.SetDrawColor(COLOR_PANEL)
		surface.DrawRect(0, 0, width, height)

		local isTable = entry.table ~= nil
		local itemTable = entry.class and ix.item.list[entry.class]
		local label = isTable and entry.table
			or (itemTable and itemTable.name or entry.class)

		draw.SimpleText(Ellipsis(label, "ixLootRow", width - Scaled(16)),
			"ixLootRow", Scaled(8), Scaled(6),
			isTable and COLOR_TABLE or (itemTable and COLOR_ITEM or COLOR_BAD),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local subtitle

		if (isTable) then
			subtitle = "A sub-table. Right click it in the tree to go and edit it."
		elseif (itemTable) then
			subtitle = entry.class
		else
			subtitle = "BROKEN - no item has this uniqueID."
		end

		draw.SimpleText(Ellipsis(subtitle, "ixLootSmall", width - Scaled(16)),
			"ixLootSmall", Scaled(8), height - Scaled(6),
			(itemTable or isTable) and COLOR_DIM or COLOR_BAD,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	self.weightField = self:Field(scroll, "WEIGHT", FIELD_HELP.weight, Scaled(26),
		function(parent)
			return self:NumberEntry(parent, 0, 100000, true, function(value)
				local entry = self:GetSelectedEntry()

				if (not entry) then return end

				entry.weight = value
				self:MarkDirty()
				self:RefreshAll()
			end)
		end)

	self.entryChanceField = self:Field(scroll, "CHANCE (%)", FIELD_HELP.chance,
		Scaled(26), function(parent)
			return self:NumberEntry(parent, 0, 100, true, function(value)
				local entry = self:GetSelectedEntry()

				if (not entry) then return end

				entry.chance = value
				self:MarkDirty()
				self:RefreshAll()
			end)
		end)

	self.countField = self:Field(scroll, "HOW MANY (MIN / MAX)", FIELD_HELP.count,
		Scaled(26), function(parent)
			local holder = parent:Add("Panel")

			self.minEntry = self:NumberEntry(holder, 0, 999, false, function(value)
				local entry = self:GetSelectedEntry()

				if (not entry) then return end

				entry.min = value
				entry.max = math.max(entry.max or value, value)
				self:MarkDirty()
				self:RefreshAll()
			end)

			self.minEntry:Dock(LEFT)
			self.minEntry:SetWide(Scaled(96))

			self.maxEntry = self:NumberEntry(holder, 0, 999, false, function(value)
				local entry = self:GetSelectedEntry()

				if (not entry) then return end

				--[[
					A max below the min is not an error to report, it is a
					value to refuse: the range would be empty and the entry
					would silently stop producing anything.
				]]
				entry.max = math.max(value, entry.min or 0)
				self:MarkDirty()
				self:RefreshAll()
			end)

			self.maxEntry:Dock(LEFT)
			self.maxEntry:SetWide(Scaled(96))
			self.maxEntry:DockMargin(Scaled(8), 0, 0, 0)

			return holder
		end)

	self.levelField = self:Field(scroll, "MINIMUM LEVEL", FIELD_HELP.level,
		Scaled(26), function(parent)
			return self:NumberEntry(parent, 1, 100, false, function(value)
				local entry = self:GetSelectedEntry()

				if (not entry) then return end

				entry.level = value
				self:MarkDirty()
				self:RefreshAll()
			end)
		end)

	self.removeButton = scroll:Add("ixFOButton")
	self.removeButton:Dock(TOP)
	self.removeButton:SetTall(Scaled(28))
	self.removeButton:DockMargin(0, Scaled(12), 0, 0)
	self.removeButton:SetText("REMOVE THIS ENTRY")
	self.removeButton:SetFont("ixLootHeader")
	self.removeButton:SetContentAlignment(5)
	self.removeButton:SetTooltip("Take this entry out of the table.")
	self.removeButton.DoClick = function()
		if (not self.working or not self.entryIndex) then return end

		table.remove(self.working.items, self.entryIndex)
		self.entryIndex = nil
		self:MarkDirty()
		self:RefreshAll()
	end

	AddHeading(scroll, "PLACING AND HOUSEKEEPING", Scaled(16))

	self.modelField = self:Field(scroll, "CONTAINER MODEL", FIELD_HELP.model,
		Scaled(26), function(parent)
			local entry = parent:Add("ixFOTextEntry")

			entry:SetFont("ixLootRow")
			entry:SetUpdateOnType(true)
			entry:SetValue("models/props_junk/wood_crate001a.mdl")
			entry.OnValueChange = function(_, value)
				self.modelValue = string.Trim(value or "")
			end

			return entry
		end)

	self.modelValue = "models/props_junk/wood_crate001a.mdl"

	--[[
		THE LOCK, for containers placed from here or from the tool.

		A row of buttons rather than a dropdown, because there are six of them
		and they are an ordered scale - the shape of the control should say
		that Very Hard is further along the same line than Easy, which a list
		you have to open does not.
	]]
	self.lockValue = 0

	self.lockField = self:Field(scroll, "LOCK", FIELD_HELP.lock, Scaled(52),
		function(parent)
			local holder = parent:Add("Panel")
			local buttons = {}

			local function Choose(level)
				self.lockValue = level

				for id, button in pairs(buttons) do
					button:SetActive(id == level)
				end
			end

			--[[
				Two rows of three so the names fit at any resolution. Docking
				each button LEFT inside its own row keeps them the same width
				whatever the panel does.
			]]
			local rows = {}

			for index = 1, 2 do
				rows[index] = holder:Add("Panel")
				rows[index]:Dock(TOP)
				rows[index]:SetTall(Scaled(24))
				rows[index]:DockMargin(0, 0, 0, Scaled(2))
			end

			local options = {{id = 0, name = "None"}}

			for _, level in ipairs(ix.lockpick.levels) do
				options[#options + 1] = level
			end

			for index, option in ipairs(options) do
				local button = rows[index <= 3 and 1 or 2]:Add("ixFOButton")

				button:Dock(LEFT)
				button:SetWide(Scaled(104))
				button:DockMargin(0, 0, Scaled(3), 0)
				button:SetText(string.upper(option.name))
				button:SetFont("ixLootSmall")
				button:SetContentAlignment(5)
				button:SetActive(option.id == self.lockValue)
				button.DoClick = function() Choose(option.id) end

				buttons[option.id] = button
			end

			return holder
		end)

	local housekeeping = scroll:Add("Panel")

	housekeeping:Dock(TOP)
	housekeeping:SetTall(Scaled(28))
	housekeeping:DockMargin(0, Scaled(12), 0, Scaled(12))

	local duplicate = housekeeping:Add("ixFOButton")

	duplicate:Dock(LEFT)
	duplicate:SetWide(Scaled(158))
	duplicate:DockMargin(0, 0, Scaled(6), 0)
	duplicate:SetText("DUPLICATE")
	duplicate:SetFont("ixLootHeader")
	duplicate:SetContentAlignment(5)
	duplicate:SetTooltip(
		"Copy this table under a new name.\nHow a tier gets made: copy the " ..
		"one below it, change three entries, save.")
	duplicate.DoClick = function() self:Duplicate() end

	local delete = housekeeping:Add("ixFOButton")

	delete:Dock(LEFT)
	delete:SetWide(Scaled(158))
	delete:SetText("DELETE")
	delete:SetFont("ixLootHeader")
	delete:SetContentAlignment(5)
	delete:SetTooltip("Delete this table from the server. Asks first.")
	delete.DoClick = function() self:Delete() end
end

function PANEL:GetSelectedEntry()
	return self.working and self.entryIndex and self.working.items[self.entryIndex]
end

function PANEL:RefreshInspector()
	local working = self.working
	local hasTable = working ~= nil

	for _, field in ipairs({self.nameField, self.chanceField, self.modeField,
	self.modelField}) do
		field:SetVisible(hasTable or field == self.modelField)
	end

	if (not hasTable) then
		self.rollsField:SetVisible(false)
		self.entryTitle:SetVisible(true)
		self:SetEntryFieldsVisible(false)
		self.saveButton:SetDisabled(true)

		return
	end

	self.saveButton:SetDisabled(false)
	self.saveButton:SetText(self.dirty and "SAVE *" or "SAVE")

	self:SetFieldText(self.nameField.control, working.name or "")
	self:SetFieldText(self.chanceField.control,
		tostring(working.spawnChance or 100))

	local mode = working.mode or "one"

	self.modeField.control:SetText(ix.loot.modeNames[mode] or mode)
	self.modeField.prose:SetProse(MODE_HELP[mode] or "")

	--[[
		The rolls box only exists for the mode that uses it. A control that
		does nothing is worse than one that is absent - and unlike weight and
		level, which are per-entry and worth greying so you can see them, this
		one has no meaning at all outside its mode.
	]]
	self.rollsField:SetVisible(mode == "rolls")
	self:SetFieldText(self.rollsField.control, tostring(working.rolls or 1))

	local entry = self:GetSelectedEntry()

	self:SetEntryFieldsVisible(entry ~= nil)

	if (not entry) then return end

	self:SetFieldText(self.weightField.control, tostring(entry.weight or 1))
	self:SetFieldText(self.entryChanceField.control, tostring(entry.chance or 100))
	self:SetFieldText(self.minEntry, tostring(entry.min or 1))
	self:SetFieldText(self.maxEntry, tostring(entry.max or entry.min or 1))
	self:SetFieldText(self.levelField.control, tostring(entry.level or 1))

	self.weightField:SetUsed(mode ~= "all",
		"NOT USED - this table uses USE ALL ENTRIES, where nothing competes.")
	self.levelField:SetUsed(mode == "level",
		"NOT USED - only BY LEVEL looks at this.")

	--[[
		The count label changes for a sub-table because the number means
		something else there: how many times to roll the table, not how many
		items to hand over.
	]]
	self.countField.heading.title = entry.table
		and "HOW MANY ROLLS OF IT (MIN / MAX)" or "HOW MANY (MIN / MAX)"
end

function PANEL:SetEntryFieldsVisible(bVisible)
	self.weightField:SetVisible(bVisible)
	self.entryChanceField:SetVisible(bVisible)
	self.countField:SetVisible(bVisible)
	self.levelField:SetVisible(bVisible)
	self.removeButton:SetVisible(bVisible)
end

--[[
	Record an edit.

	Clearing the preview is the point of routing every edit through here. A
	simulation is a statement about a specific table; leaving the last run on
	screen after a weight changed shows numbers that describe something that no
	longer exists, and there is no way for the reader to tell.
]]
function PANEL:MarkDirty()
	self.dirty = true
	self.previewResults = nil
end

function PANEL:RefreshAll()
	self:RefreshTableList()
	self:RefreshInspector()
	self:RefreshCentre()
end

--------------------------------------------------------------------------------
-- The picker
--------------------------------------------------------------------------------

--[[
	Adding an entry happens in an overlay rather than in a fourth column.

	There is one screen and four things that want it: the table list, the tree,
	the inspector and a searchable list of every item in the schema. The last
	of those is only wanted for a few seconds at a time, so it takes the whole
	window while it is up and gives it all back afterwards - which is how it
	gets room for the item name AND its category AND its uniqueID on one line.

	It stays open after an add, deliberately. Filling a tier table means adding
	eight things in a row, and a picker that closed each time would mean
	retyping the search eight times.
]]
function PANEL:BuildPicker()
	local picker = self:Add("Panel")

	picker:SetZPos(200)
	picker:SetVisible(false)

	picker.Paint = function(_, width, height)
		surface.SetDrawColor(12, 12, 16, 250)
		surface.DrawRect(0, 0, width, height)

		ix.fallout.DrawBrackets(width, height,
			ix.fallout.GetPalette().color_primary, 0, true)
	end

	local header = picker:Add("Panel")

	header:Dock(TOP)
	header:SetTall(FontHeight("ixLootHeader") + FontHeight("ixLootSmall")
		+ Scaled(18))
	header:DockMargin(Scaled(12), Scaled(10), Scaled(12), 0)

	header.Paint = function(_, width, height)
		draw.SimpleText(self.pickerMode == "table"
			and "ADD A SUB-TABLE" or "ADD AN ITEM", "ixLootHeader",
			0, Scaled(2), ix.fallout.GetPalette().color_primary,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local subtitle = self.pickerMode == "table"
			and "The chosen table is rolled as part of this one. Its own spawn " ..
				"chance still applies."
			or "Click to add. The picker stays open so you can add several."

		draw.SimpleText(Ellipsis(subtitle, "ixLootSmall", width - Scaled(140)),
			"ixLootSmall", 0, height - Scaled(4), COLOR_DIM,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		if ((self.pickerAdded or 0) > 0) then
			draw.SimpleText(self.pickerAdded .. " added", "ixLootHeader",
				width, height - Scaled(4), COLOR_GOOD,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	local close = header:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(90))
	close:SetText("DONE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:ClosePicker() end

	self.pickerSearch = picker:Add("ixFOTextEntry")
	self.pickerSearch:Dock(TOP)
	self.pickerSearch:SetTall(Scaled(28))
	self.pickerSearch:DockMargin(Scaled(12), Scaled(8), Scaled(12), Scaled(8))
	self.pickerSearch:SetFont("ixLootRow")
	self.pickerSearch:SetUpdateOnType(true)
	self.pickerSearch:SetPlaceholderText("Search by name or uniqueID")
	self.pickerSearch.OnValueChange = function(_, text)
		self.pickerFilter = string.lower(string.Trim(text or ""))
		self:RefreshPicker()
	end

	self.pickerList = picker:Add("ixFOScrollPanel")
	self.pickerList:Dock(FILL)
	self.pickerList:DockMargin(Scaled(12), 0, Scaled(12), Scaled(12))

	self.picker = picker
end

function PANEL:OpenPicker(mode)
	if (not self.working) then
		self:Notify("Open or create a table first.", true)
		return
	end

	if (not IsValid(self.picker)) then
		self:BuildPicker()
	end

	self.pickerMode = mode
	self.pickerAdded = 0
	self.pickerFilter = ""

	self.pickerSearch:SetValue("")
	self.picker:SetPos(Scaled(14), Scaled(48))
	self.picker:SetSize(self:GetWide() - Scaled(28), self:GetTall() - Scaled(104))
	self.picker:SetVisible(true)
	self.picker:MoveToFront()
	self.pickerSearch:RequestFocus()

	self:RefreshPicker()
end

function PANEL:ClosePicker()
	if (IsValid(self.picker)) then
		self.picker:SetVisible(false)
	end

	self:RefreshAll()
end

function PANEL:AddEntry(build)
	local entry = ix.loot.NewEntry()

	build(entry)

	self.working.items[#self.working.items + 1] = entry
	self.entryIndex = #self.working.items
	self.pickerAdded = (self.pickerAdded or 0) + 1
	self:MarkDirty()

	--[[
		The new entry is opened in the tree straight away, so adding a
		sub-table shows you what is inside it rather than one more collapsed
		row you have to go and find.
	]]
	self.expanded["/" .. self.entryIndex] = true

	ix.fallout.PlayUISound("select")
end

function PANEL:RefreshPicker()
	self.pickerList:Clear()

	local nameHeight = FontHeight("ixLootRow")
	local subHeight = FontHeight("ixLootSmall")
	local rowHeight = nameHeight + subHeight + Scaled(14)
	local filter = self.pickerFilter or ""

	local function Row(label, subtitle, colour, tooltip, callback)
		local row = AddRow(self.pickerList, rowHeight)

		row:SetTooltip(tooltip)

		row.PaintRow = function(_, width, height)
			local pad = Scaled(10)

			draw.SimpleText(Ellipsis(label, "ixLootRow", width - pad * 2),
				"ixLootRow", pad, Scaled(6), colour,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			draw.SimpleText(Ellipsis(subtitle, "ixLootSmall", width - pad * 2),
				"ixLootSmall", pad, height - Scaled(6), COLOR_DIM,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end

		row.DoClick = callback
	end

	if (self.pickerMode == "table") then
		local shown = 0

		for _, name in ipairs(ix.loot.GetNames()) do
			--[[
				The table being edited is left out. `Validate` refuses a
				self-reference anyway, and offering something the save will
				reject is worse than not offering it.
			]]
			if (name == self.working.name) then continue end
			if (filter ~= ""
			and not string.find(string.lower(name), filter, 1, true)) then continue end

			local lootTable = ix.loot.Get(name)

			shown = shown + 1

			Row(name, string.format("%d entries  ·  %s  ·  fires %s",
				#(lootTable.items or {}),
				ix.loot.modeNames[lootTable.mode or "one"],
				ix.loot.FormatChance(lootTable.spawnChance or 100)),
				COLOR_TABLE,
				"Add " .. name .. " as a sub-table of " .. self.working.name .. ".",
				function()
					self:AddEntry(function(entry) entry.table = name end)
					self:RefreshPicker()
				end)
		end

		if (shown == 0) then
			local empty = self.pickerList:Add("Panel")

			empty:Dock(TOP)
			empty:SetTall(Scaled(46))
			empty.Paint = function(_, width, height)
				draw.SimpleText("No other tables to nest.", "ixLootRow",
					width * 0.5, height * 0.5, COLOR_DIM,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		return
	end

	local matches = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (itemTable.isBase) then continue end

		local name = string.lower(itemTable.name or uniqueID)

		if (filter == ""
		or string.find(name, filter, 1, true)
		or string.find(string.lower(uniqueID), filter, 1, true)) then
			matches[#matches + 1] = {uniqueID = uniqueID, item = itemTable}
		end
	end

	table.sort(matches, function(a, b)
		return (a.item.name or a.uniqueID) < (b.item.name or b.uniqueID)
	end)

	--[[
		Capped, because this rebuilds on every keystroke over a couple of
		thousand items - the same problem the dev terminal hit. The count of
		what is not shown is printed, so a narrow search is an obvious move
		rather than a guess.
	]]
	local limit = 80

	for index = 1, math.min(#matches, limit) do
		local match = matches[index]

		Row(match.item.name or match.uniqueID,
			(match.item.category or "no category") .. "  ·  " .. match.uniqueID,
			COLOR_ITEM,
			"Add " .. (match.item.name or match.uniqueID) .. " to this table.",
			function()
				self:AddEntry(function(entry) entry.class = match.uniqueID end)
				self:RefreshPicker()
			end)
	end

	local footer = self.pickerList:Add("Panel")

	footer:Dock(TOP)
	footer:SetTall(Scaled(34))

	footer.Paint = function(_, width, height)
		draw.SimpleText(#matches > limit
			and string.format("Showing %d of %d - search to narrow it down",
				limit, #matches)
			or string.format("%d item%s", #matches, #matches == 1 and "" or "s"),
			"ixLootSmall", width * 0.5, height * 0.5, COLOR_DIM,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------

--[[
	Validated here before it is sent.

	The server validates too, and its answer is the one that counts - but it
	answers with a notification in the corner, several steps away from the
	field that was wrong. Checking the same rules here puts the reason on the
	hint line under the editor, where the mistake is.
]]
function PANEL:Save()
	if (not self.working) then
		self:Notify("Nothing to save.", true)
		return
	end

	self.working.name = string.Trim(self.working.name or "")

	local ok, reason = ix.loot.Validate(self.working)

	if (not ok) then
		self:Notify("Cannot save: " .. reason, true)

		return
	end

	net.Start("ixLootSaveTable")
		net.WriteTable(self.working)
		net.WriteString(self.selected or "")
	net.SendToServer()

	self.selected = self.working.name
	self.dirty = false

	self:Notify("Saved " .. self.working.name .. ".")
	self:RefreshAll()
	ix.fallout.PlayUISound("select")
end

--[[
	Duplicating is how a tier gets made: copy `Looter_Ammo_Tier1`, change three
	entries, save it as Tier2. Without it every tier is authored from nothing.
]]
function PANEL:Duplicate()
	if (not self.working) then
		self:Notify("Nothing to duplicate.", true)
		return
	end

	self.working = table.Copy(self.working)
	self.working.name = self.working.name .. " Copy"
	self.selected = nil
	self.entryIndex = nil
	self:MarkDirty()

	self:Notify("Duplicated. It does not exist until you SAVE it.")
	self:RefreshAll()
end

function PANEL:Delete()
	if (not self.selected) then
		self:Notify("This table has never been saved - there is nothing to delete.",
			true)

		return
	end

	local name = self.selected

	--[[
		Containers already pointing at this table are not deleted with it: they
		stay on the map with a table that no longer resolves, which the tree
		shows in red. That is deliberate - deleting somebody's crates because
		they deleted a table is a much bigger action than the one they asked
		for.
	]]
	Derma_Query(
		"Delete the loot table '" .. name .. "'?\n\n" ..
		"Containers using it will stop producing anything, and any table that " ..
		"nests it will show a broken row.",
		"Delete loot table",
		"Delete it", function()
			net.Start("ixLootDeleteTable")
				net.WriteString(name)
			net.SendToServer()

			self.selected = nil
			self.working = nil
			self.entryIndex = nil
			self.dirty = false

			self:Notify("Deleted " .. name .. ".")
			self:RefreshAll()
		end,
		"Keep it", function() end)
end

function PANEL:OnKeyCodePressed(key)
	if (key ~= KEY_ESCAPE) then return end

	--[[
		Escape closes the picker before it closes the menu. Closing the whole
		editor because somebody dismissed a search box would throw away
		everything unsaved.
	]]
	if (IsValid(self.picker) and self.picker:IsVisible()) then
		self:ClosePicker()
		return
	end

	if (self.dirty) then
		self:Notify("Unsaved changes - press SAVE, or CLOSE to discard them.", true)
		return
	end

	self:Remove()
end

vgui.Register("ixFOLootConfig", PANEL, "ixFOFrame")

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

--[[
	The server is the source of truth; this is a mirror kept for the editor and
	the placer tool so both can list without a round trip per keystroke.
]]
net.Receive("ixLootSync", function()
	ix.loot.tables = net.ReadTable()

	for _, data in pairs(ix.loot.tables) do
		ix.loot.Normalise(data)
	end

	local panel = ix.gui.lootConfig

	if (IsValid(panel)) then
		--[[
			The working copy is left alone. A sync arrives after every save,
			including somebody else's, and replacing what is being edited with
			what the server holds would silently discard their work.
		]]
		panel:RefreshTableList()
		panel:RefreshCentre()
	end
end)

net.Receive("ixLootConfigOpen", function()
	vgui.Create("ixFOLootConfig")
end)

concommand.Add("fo_loot_config", function()
	RunConsoleCommand("say", "/lootconfig")
end)

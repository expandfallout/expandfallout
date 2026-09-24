--[[
	The class name viewer.

	Phoenix's `classnameviewer` plugin, which is a searchable window listing
	factions, classes and items by their print name and their uniqueID. It
	exists because every admin command takes a uniqueID and nothing in the game
	ever shows you one - you cannot `/charsetfaction` somebody into the
	Followers without knowing they are `foa`.

	THIS ADDS RACES, which theirs does not have because their races were never
	addressable by name from a command. Forty-four races is exactly the case
	the window is for.

	Built on the schema's own widgets rather than `DPropertySheet` and
	`SearchableListView` as theirs is, so it matches everything else and so the
	search works the same way the loot picker's does.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	Cut a note to fit its column.

	The third column holds a model filename, which for a race can be longer
	than the space between it and the class name beside it.
]]
local function Ellipsis(text, font, maxWidth)
	surface.SetFont(font)

	if (maxWidth <= 0) then return "" end
	if (surface.GetTextSize(text) <= maxWidth) then return text end

	while (#text > 1) do
		text = string.sub(text, 1, #text - 1)

		if (surface.GetTextSize(text .. "...") <= maxWidth) then
			return text .. "..."
		end
	end

	return text
end

--[[
	The four things that have uniqueIDs worth looking up.

	Each returns a list of `{name, id, note}`. `note` is the third column and
	is whatever is most useful for telling two similar entries apart - a
	faction's colour means nothing in a list, but a race's model tells you
	immediately whether it is the one you meant.
]]
local SOURCES = {
	{
		name = "FACTIONS",
		Get = function()
			local out = {}

			for id, faction in pairs(ix.faction.teams) do
				out[#out + 1] = {
					name = faction.name,
					id = id,
					note = faction.isDefault and "default" or ""
				}
			end

			return out
		end
	},
	{
		name = "RACES",
		Get = function()
			local out = {}

			for id, race in pairs(ix.races and ix.races.list or {}) do
				--[[
					The default model is the note because a race with no
					installed models is one that will not work, and this is
					the fastest place to notice.
				]]
				local model = race.defaultModels
					and (race.defaultModels.male or race.defaultModels.female)

				out[#out + 1] = {
					name = race.name,
					id = id,
					note = model and string.GetFileFromFilename(model) or "NO MODEL"
				}
			end

			return out
		end
	},
	{
		name = "CLASSES",
		Get = function()
			local out = {}

			for _, class in ipairs(ix.class.list) do
				local faction = ix.faction.indices[class.faction]

				out[#out + 1] = {
					name = class.name,
					id = class.uniqueID,
					note = faction and faction.name or ""
				}
			end

			return out
		end
	},
	{
		name = "ITEMS",
		Get = function()
			local out = {}

			for id, item in pairs(ix.item.list) do
				if (item.isBase) then continue end

				out[#out + 1] = {
					name = item.name or id,
					id = id,
					note = item.category or ""
				}
			end

			return out
		end
	}
}

function PANEL:Init()
	if (IsValid(ix.gui.classNames)) then
		ix.gui.classNames:Remove()
	end

	ix.gui.classNames = self

	--[[
		The menu fonts, which this window does not own. They live in
		`libs/cl_menufonts.lua` because the loot configurer uses them too, and
		this window drawing with a font that had never been created was one
		error per row per frame.
	]]
	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(760)),
		math.min(ScrH() - Scaled(80), Scaled(620)))
	self:Center()
	self:MakePopup()
	self:SetTitle("CLASS NAMES")

	self.source = 1
	self.filter = ""

	local tabs = self:Add("Panel")

	tabs:Dock(TOP)
	tabs:SetTall(Scaled(28))

	self.tabs = {}

	for index, source in ipairs(SOURCES) do
		local button = tabs:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(120))
		button:DockMargin(0, 0, Scaled(5), 0)
		button:SetText(source.name)
		button:SetContentAlignment(5)
		button.DoClick = function()
			self.source = index
			self:Refresh()
		end

		self.tabs[index] = button
	end

	self.search = self:Add("ixFOTextEntry")
	self.search:Dock(TOP)
	self.search:SetTall(Scaled(28))
	self.search:DockMargin(0, Scaled(8), 0, Scaled(8))
	self.search:SetUpdateOnType(true)
	self.search:SetPlaceholderText("Search by name or class name")
	self.search.OnValueChange = function(_, text)
		self.filter = string.lower(string.Trim(text or ""))
		self:Refresh()
	end

	--[[
		A footer with a close button.

		`ixFOFrame` calls `ShowCloseButton(false)` in its own Init - the frame
		draws its title into a gap in the top rule and has nowhere to put one -
		so every window built on it has to provide its own way out. Escape
		works too, but a window with no visible exit is one people get stuck
		in.
	]]
	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("Click a row to copy its class name.")

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	self:Refresh()
end

function PANEL:Refresh()
	for index, button in ipairs(self.tabs) do
		button:SetActive(index == self.source)
	end

	self.list:Clear()

	local entries = SOURCES[self.source].Get()

	table.sort(entries, function(a, b) return a.name < b.name end)

	local rowHeight = Scaled(24)
	local shown = 0

	for _, entry in ipairs(entries) do
		if (self.filter ~= ""
		and not string.find(string.lower(entry.name), self.filter, 1, true)
		and not string.find(string.lower(entry.id), self.filter, 1, true)) then
			continue
		end

		shown = shown + 1

		--[[
			A plain DButton, NOT `ixFOButton`.

			`ixFOButton` inverts on hover - it fills solid with the palette
			colour and flips its text dark - which is right for a button with a
			label and wrong for a row whose text this file draws itself: the
			fill went amber, the text stayed amber, and the row became
			unreadable exactly when the cursor was on it.

			So the row paints its own background and its own text, and both
			know about the hover state.
		]]
		local row = self.list:Add("DButton")

		row:Dock(TOP)
		row:SetTall(rowHeight)
		row:DockMargin(0, 0, 0, Scaled(2))
		row:SetText("")
		row:SetTooltip("Click to copy '" .. entry.id .. "' to your clipboard.")

		row.DoClick = function()
			--[[
				Copying the ID is the whole point of the window - it is going
				to be typed into a command either way, and typing
				`feralghoul_armored` correctly from memory is not something to
				ask of anybody.
			]]
			SetClipboardText(entry.id)
			ix.fallout.PlayUISound("select")

			if (IsValid(self.hint)) then
				self.hint:SetText("Copied '" .. entry.id .. "'.")
			end
		end

		row.Paint = function(pnl, width, height)
			local palette = ix.fallout.GetPalette()
			local hovered = pnl:IsHovered()

			--[[
				A dark fill on hover rather than a bright one. The text is the
				content here; the highlight only has to say which row the
				cursor is on, and it must not compete with what it is
				highlighting.
			]]
			surface.SetDrawColor(hovered and Color(56, 52, 40, 255)
				or Color(30, 30, 36, 200))
			surface.DrawRect(0, 0, width, height)

			if (hovered) then
				surface.SetDrawColor(palette.color_primary)
				surface.DrawRect(0, 0, Scaled(3), height)
			end

			draw.SimpleText(entry.name, "ixLootRow", Scaled(10), height * 0.5,
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(entry.id, "ixLootRow", width * 0.52, height * 0.5,
				palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (entry.note ~= "") then
				draw.SimpleText(Ellipsis(entry.note, "ixLootSmall",
					width * 0.44 - Scaled(20)), "ixLootSmall",
					width - Scaled(10), height * 0.5,
					ColorAlpha(palette.color_primary, 170),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	if (shown == 0) then
		local empty = self.list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(30))
		empty:SetContentAlignment(5)
		empty:SetText("Nothing matches that.")
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOClassNames", PANEL, "ixFOFrame")

net.Receive("ixClassNamesOpen", function()
	vgui.Create("ixFOClassNames")
end)

concommand.Add("fo_classnames", function()
	RunConsoleCommand("say", "/classnameviewer")
end)

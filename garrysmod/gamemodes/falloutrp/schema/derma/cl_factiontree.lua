--[[
	The sub-faction configurer.

	`/factionlink` and `/factionunlink` do the same job in one line each, and
	they need you to already know both uniqueIDs and which way round they go.
	With forty-five factions that is the wrong tool for setting up a hierarchy;
	this is the one where you can see what exists and what it currently looks
	like while you change it.

	    LEFT     every faction, with what it is under
	    RIGHT    the tree as it stands

	Click a faction on the left to pick it up, then click the faction you want
	it under. Clicking it again puts it down. That is one gesture for a
	relationship that has two halves, and it means the second click is always
	"under what", so it cannot be given backwards.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	Rows paint themselves rather than using `ixFOButton`.

	`ixFOButton` inverts on hover - solid palette fill, dark text - which makes
	a row whose text this file draws unreadable exactly when the cursor is on
	it. The class name viewer had the same fault.
]]
local function Row(parent, height)
	local row = parent:Add("DButton")

	row:Dock(TOP)
	row:SetTall(height)
	row:DockMargin(0, 0, 0, Scaled(2))
	row:SetText("")

	row.selected = false

	row.Paint = function(pnl, width, tall)
		local palette = ix.fallout.GetPalette()
		local colour = Color(30, 30, 36, 200)

		if (pnl.selected) then
			colour = Color(70, 58, 32, 255)
		elseif (pnl:IsHovered()) then
			colour = Color(56, 52, 40, 255)
		end

		surface.SetDrawColor(colour)
		surface.DrawRect(0, 0, width, tall)

		if (pnl.selected or pnl:IsHovered()) then
			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, 0, Scaled(3), tall)
		end

		if (pnl.PaintRow) then
			pnl:PaintRow(width, tall)
		end
	end

	return row
end

function PANEL:Init()
	if (IsValid(ix.gui.factionTree)) then
		ix.gui.factionTree:Remove()
	end

	ix.gui.factionTree = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(900)),
		math.min(ScrH() - Scaled(80), Scaled(640)))
	self:Center()
	self:MakePopup()
	self:SetTitle("FACTION HIERARCHY")

	--- The faction picked up and waiting for somewhere to go.
	self.held = nil

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

	--[[
		Two columns. The left is the whole roster and is where you act; the
		right is the consequence, and is read-only on purpose - a tree you can
		edit in two places is a tree with two ideas about what a click means.
	]]
	local right = self:Add("Panel")

	right:Dock(RIGHT)
	right:SetWide(Scaled(330))

	local rightTitle = right:Add("ixFOLabel")

	rightTitle:Dock(TOP)
	rightTitle:SetTall(Scaled(24))
	rightTitle:SetFont("ixLootHeader")
	rightTitle:SetText("AS IT STANDS")

	self.tree = right:Add("ixFOScrollPanel")
	self.tree:Dock(FILL)

	local left = self:Add("Panel")

	left:Dock(FILL)
	left:DockMargin(0, 0, Scaled(10), 0)

	self.search = left:Add("ixFOTextEntry")
	self.search:Dock(TOP)
	self.search:SetTall(Scaled(26))
	self.search:DockMargin(0, 0, 0, Scaled(6))
	self.search:SetUpdateOnType(true)
	self.search:SetPlaceholderText("Search factions")
	self.search.OnValueChange = function(_, text)
		self.filter = string.lower(string.Trim(text or ""))
		self:RefreshList()
	end

	self.list = left:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	self:Refresh()
end

function PANEL:Say(text)
	if (not IsValid(self.hint)) then return end

	self.hint:SetText(text)
	self.saidAt = RealTime()
end

function PANEL:Refresh()
	self:RefreshList()
	self:RefreshTree()

	--[[
		The idle hint does not stamp on something just said.

		A click sends the command, the server broadcasts the new tree, and that
		lands here within the same second - so without this the message telling
		you what you just did is replaced by the instructions before you have
		read it.
	]]
	if (not self.held and RealTime() - (self.saidAt or 0) > 4) then
		self:Say("Click a faction, then click what it should sit under.")
	end
end

function PANEL:RefreshList()
	self.list:Clear()

	local names = {}

	for id, faction in pairs(ix.faction.teams) do
		names[#names + 1] = {id = id, name = faction.name, colour = faction.color}
	end

	table.sort(names, function(a, b) return a.name < b.name end)

	local height = Scaled(26)

	for _, entry in ipairs(names) do
		if (self.filter and self.filter ~= ""
		and not string.find(string.lower(entry.name), self.filter, 1, true)
		and not string.find(entry.id, self.filter, 1, true)) then
			continue
		end

		local row = Row(self.list, height)
		local parent = ix.faction.GetParent(entry.id)

		row.selected = self.held == entry.id

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()

			--[[
				The faction's own colour as a chip. Forty-five names in one
				list are hard to tell apart; the colour is the thing people
				already associate with a faction.
			]]
			surface.SetDrawColor(entry.colour or palette.color_primary)
			surface.DrawRect(Scaled(9), tall * 0.5 - Scaled(5), Scaled(10), Scaled(10))

			draw.SimpleText(entry.name, "ixLootRow", Scaled(26), tall * 0.5,
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(entry.id, "ixLootSmall", width * 0.52, tall * 0.5,
				ColorAlpha(palette.color_primary, 170),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (parent) then
				draw.SimpleText("under " .. parent, "ixLootSmall",
					width - Scaled(10), tall * 0.5,
					ColorAlpha(palette.color_primary, 190),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		row.DoClick = function()
			self:Clicked(entry.id, entry.name)
		end

		row.DoRightClick = function()
			if (not ix.faction.GetParent(entry.id)) then
				self:Say(entry.name .. " is not under anything.")
				return
			end

			ix.command.Send("factionunlink", entry.id)
			self:Say("Detaching " .. entry.name .. "...")
		end
	end
end

--[[
	One click picks up, the second says where it goes.

	Both halves are the same gesture on the same list, so the second click is
	always "under what" and the relationship cannot be entered backwards.
]]
function PANEL:Clicked(id, name)
	if (not self.held) then
		self.held = id

		self:Say("Holding " .. name ..
			" - click what it goes under, or click it again to drop it. " ..
			"Right click a sub-faction to detach it.")
		self:RefreshList()

		return
	end

	if (self.held == id) then
		self.held = nil

		self:Say("Put " .. name .. " back down.")
		self:RefreshList()

		return
	end

	--[[
		Sent as the existing command rather than a net message of its own.

		`/factionlink` already validates all of this on the server - one level
		only, no self-parenting, both factions must exist - and its answers are
		the reasons this could fail. A second path to the same change would be
		a second place for those rules to live, and the admin-only check with
		it.

		`ix.command.Send` and not a `say` concommand: it takes the arguments as
		values, so a faction whose uniqueID ever contains a space or a quote
		cannot be misread, and it does not put the click in everyone's chat.
	]]
	ix.command.Send("factionlink", self.held, id)

	self:Say(string.format("Asked for %s under %s - the tree on the right is "
		.. "what actually happened.", self.held, name))
	self.held = nil
end

function PANEL:RefreshTree()
	self.tree:Clear()

	local roots = ix.faction.GetRoots()

	if (#roots == 0) then
		local empty = self.tree:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText("Nothing is grouped yet.")

		return
	end

	for _, root in ipairs(roots) do
		local team = ix.faction.teams[root]
		local header = self.tree:Add("Panel")

		header:Dock(TOP)
		header:SetTall(Scaled(24))

		header.Paint = function(_, width, tall)
			draw.SimpleText(team and team.name or root, "ixLootHeader",
				Scaled(4), tall * 0.5,
				team and team.color or ix.fallout.GetPalette().color_primary,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		for _, child in ipairs(ix.faction.GetChildren(root)) do
			local sub = ix.faction.teams[child]
			local line = self.tree:Add("Panel")

			line:Dock(TOP)
			line:SetTall(Scaled(20))

			line.Paint = function(_, width, tall)
				local palette = ix.fallout.GetPalette()

				surface.SetDrawColor(ColorAlpha(palette.color_primary, 90))
				surface.DrawRect(Scaled(12), 0, 1, tall)

				draw.SimpleText(sub and sub.name or child, "ixLootSmall",
					Scaled(22), tall * 0.5,
					sub and sub.color or palette.text_primary,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		local gap = self.tree:Add("Panel")

		gap:Dock(TOP)
		gap:SetTall(Scaled(8))
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key ~= KEY_ESCAPE) then return end

	--[[
		Escape drops what is held before it closes the window. Closing while
		holding something loses the half-made link with no sign of it.
	]]
	if (self.held) then
		self.held = nil

		self:Say("Put it back down.")
		self:RefreshList()

		return
	end

	self:Remove()
end

vgui.Register("ixFOFactionTree", PANEL, "ixFOFrame")

--[[
	Rebuilt whenever the server sends a new tree, which it does after every
	link and unlink - so the window updates itself rather than needing to be
	reopened to see what a click did.
]]
hook.Add("FactionTreeChanged", "ixFOFactionTree", function()
	if (IsValid(ix.gui.factionTree)) then
		ix.gui.factionTree:Refresh()
	end
end)

net.Receive("ixFactionTreeOpen", function()
	vgui.Create("ixFOFactionTree")
end)

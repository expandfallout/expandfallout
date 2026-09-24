--[[
	Your faction's log, searched.

	One kind at a time - the shop, or storage - a search box, and the last
	two hundred matching lines newest first. Reached from the magnifier on
	the faction shop's tab bar and on an open faction storage. The server
	answers only with the faction the asker is in.

	`derma/` loads before `sh_schema.lua`: nothing from `ix.fallout` or
	`ix.factionlog` is read at file scope here.
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

	self:SetSize(Scaled(760), Scaled(560))
	self:Center()
	self:MakePopup()
	self:SetTitle("FACTION LOG")

	self.kind = ""

	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(Scaled(8), Scaled(28), Scaled(8), Scaled(8))

	local close = self:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(30))
	close:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(8))
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	local bar = self.content:Add("Panel")

	bar:Dock(TOP)
	bar:SetTall(Scaled(30))
	bar:DockMargin(0, 0, 0, Scaled(8))

	self.kinds = {}

	local function Kind(id, text)
		local button = bar:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(100))
		button:DockMargin(0, 0, Scaled(6), 0)
		button:SetText(text)
		button:SetFont("ixLootBadge")
		button:SetContentAlignment(5)
		button.DoClick = function() self:SetKind(id) end

		self.kinds[id] = button
	end

	Kind("shop", "SHOP")
	Kind("storage", "STORAGE")
	Kind("", "ALL")

	--- Two hundred lines a page, newest first; OLDER and NEWER turn them.
	for _, turn in ipairs({{"OLDER", 1}, {"NEWER", -1}}) do
		local button = bar:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(Scaled(80))
		button:DockMargin(Scaled(6), 0, 0, 0)
		button:SetText(turn[1])
		button:SetFont("ixLootBadge")
		button:SetContentAlignment(5)
		button.DoClick = function() self:Turn(turn[2]) end
	end

	self.search = bar:Add("DTextEntry")
	self.search:Dock(FILL)
	self.search:DockMargin(Scaled(6), 0, 0, 0)
	self.search:SetFont("ixLootRow")
	self.search:SetPlaceholderText("Search a name or an item, then Enter")
	self.search.OnEnter = function()
		self.page = 0
		self:Refresh()
	end

	self.note = self.content:Add("ixFOLabel")
	self.note:Dock(TOP)
	self.note:SetTall(Scaled(18))
	self.note:SetFont("ixLootBadge")
	self.note:SetTextColor(NOTE)
	self.note:SetText("What your faction's people did with its shop and its "
		.. "storage. Newest first.")

	self.list = self.content:Add("DScrollPanel")
	self.list:Dock(FILL)
	self.list:DockMargin(0, Scaled(6), 0, 0)

	ix.gui.factionLogs = self
end

function PANEL:SetKind(kind)
	self.kind = kind or ""
	self.page = 0

	for id, button in pairs(self.kinds) do
		button:SetAlpha(id == self.kind and 255 or 170)
	end

	self:Refresh()
end

function PANEL:Refresh()
	ix.factionlog.Ask(self.kind, self.search:GetValue(), self.page or 0)
end

function PANEL:Turn(step)
	local page = (self.page or 0) + step

	if (page < 0 or (step > 0 and not self.more)) then return end

	self.page = page
	self:Refresh()
end

function PANEL:Receive(kind, rows, more, page, total)
	if (kind ~= self.kind) then return end

	self.more = more
	self.page = page or self.page or 0
	total = total or #rows

	local first = #rows > 0 and (self.page * 200 + 1) or 0

	self.note:SetText(string.format("What your faction's people did with its shop "
		.. "and its storage, newest first. Showing %d-%d of %d - page %d of %d%s.",
		first, self.page * 200 + #rows, total, self.page + 1,
		math.max(1, math.ceil(total / 200)), more and ", OLDER for the next" or ""))

	self.list:Clear()

	if (#rows == 0) then
		local empty = self.list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(24))
		empty:SetFont("ixLootRow")
		empty:SetTextColor(NOTE)
		empty:SetText("Nothing matches.")

		return
	end

	for _, entry in ipairs(rows) do
		local row = self.list:Add("Panel")

		row:Dock(TOP)
		row:SetTall(Scaled(28))
		row:DockMargin(0, 0, 0, Scaled(3))

		row.Paint = function(_, w, h)
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)
		end

		local when = row:Add("ixFOLabel")

		when:Dock(LEFT)
		when:SetWide(Scaled(120))
		when:DockMargin(Scaled(8), 0, 0, 0)
		when:SetFont("ixLootBadge")
		when:SetTextColor(NOTE)
		when:SetText(os.date("%d %b %H:%M", entry.time or 0))

		local kindLabel = row:Add("ixFOLabel")

		kindLabel:Dock(LEFT)
		kindLabel:SetWide(Scaled(70))
		kindLabel:SetFont("ixLootBadge")
		kindLabel:SetTextColor(NOTE)
		kindLabel:SetText(string.upper(entry.kind or ""))

		local text = row:Add("ixFOLabel")

		text:Dock(FILL)
		text:SetFont("ixLootBadge")
		text:SetTextColor(color_white)
		text:SetText(entry.text or "")
	end
end

vgui.Register("ixFOFactionLogs", PANEL, "ixFOFrame")

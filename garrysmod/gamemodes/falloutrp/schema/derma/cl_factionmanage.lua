--[[
	The faction management window. `/fm`, and `/afm` for an admin.

	    MEMBERS      everyone in the faction, online or not, with what you may
	                 do to each of them
	    DEPLOYABLES   the faction's storages, and where they are

	OPEN TO EVERYONE IN THE FACTION, and it shows what you can do rather than
	refusing you at the door. An enlisted member opening this sees the roster
	and no buttons; that is worth more than being told they are not allowed,
	because knowing who is above you is the point of a roster.

	Deployables are Lead only, so the page is not offered below that - an empty
	page you are allowed to open is a worse answer than a page that is not
	there.

	`/afm` IS THE SAME WINDOW WITH A COLUMN OF FACTIONS DOWN THE SIDE.
	Superadmin, and it manages any of them: their roster, their ranks and their
	property. It is a list rather than an argument because there are forty-five
	uniqueIDs and nobody remembers them - and because the useful question when
	you open it is usually "which faction has people in it", which a list can
	answer and a text field cannot.
]]

if (not CLIENT) then return end

ix.factionManage = ix.factionManage or {}
ix.factionManage.members = ix.factionManage.members or {}
ix.factionManage.storages = ix.factionManage.storages or {}

--- `[uniqueID] = {members, storages}`, for the admin column only.
ix.factionManage.factions = ix.factionManage.factions or {}

--[[
	Storage records arrive here and are written into `ix.factionStorage.list`,
	which `sh_factionstorage.lua` already reads through `ix.factionStorage.Get`
	- the entity tooltip uses that, and defining a second copy of the getter
	here would be two functions answering one question.
]]

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--- Rows paint themselves; `ixFOButton` inverts on hover and eats the text.
local function Row(parent, height)
	local row = parent:Add("DButton")

	row:Dock(TOP)
	row:SetTall(height)
	row:DockMargin(0, 0, 0, Scaled(2))
	row:SetText("")

	row.Paint = function(pnl, width, tall)
		local palette = ix.fallout.GetPalette()

		surface.SetDrawColor(pnl:IsHovered() and Color(56, 52, 40, 255)
			or Color(30, 30, 36, 200))
		surface.DrawRect(0, 0, width, tall)

		if (pnl:IsHovered()) then
			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, 0, Scaled(3), tall)
		end

		if (pnl.PaintRow) then
			pnl:PaintRow(width, tall)
		end
	end

	return row
end

--[[
	A row button wide enough for what is written on it.

	`ixFOButton` uses `UI_Bold`, which is the HUD's font and is sized for a
	title rather than for three buttons sharing a 34-pixel row - "SET CLASS"
	came out as "SET CL...". Measuring is the only way to be right about this:
	the font scale is the player's setting, so a width that fits at one scale
	is cut off at another.
]]
local function FitButton(parent, text, minimum)
	local button = parent:Add("ixFOButton")

	button:SetFont("ixLootSmall")
	button:SetText(text)
	button:SetContentAlignment(5)

	surface.SetFont("ixLootSmall")

	local width = surface.GetTextSize(text)

	button:SetWide(math.max(width + Scaled(16), Scaled(minimum or 40)))

	return button
end

local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.factionManage)) then
		ix.gui.factionManage:Remove()
	end

	ix.gui.factionManage = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(940)),
		math.min(ScrH() - Scaled(80), Scaled(640)))
	self:Center()
	self:MakePopup()
	self:SetTitle("FACTION MANAGEMENT")

	self.faction = nil
	self.admin = false
	self.page = "members"
	self.filter = ""

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
		The faction column, built empty and only shown for `/afm`. Created here
		rather than in `Refresh` because docking order is creation order, and a
		column that appeared later would dock inside the tabs above it.
	]]
	self.factionColumn = self:Add("Panel")
	self.factionColumn:Dock(LEFT)
	self.factionColumn:SetWide(Scaled(210))
	self.factionColumn:DockMargin(0, 0, Scaled(10), 0)
	self.factionColumn:SetVisible(false)

	local columnTitle = self.factionColumn:Add("ixFOLabel")

	columnTitle:Dock(TOP)
	columnTitle:SetTall(Scaled(22))
	columnTitle:SetFont("ixLootHeader")
	columnTitle:SetText("FACTIONS")

	self.factionList = self.factionColumn:Add("ixFOScrollPanel")
	self.factionList:Dock(FILL)

	self.tabs = self:Add("Panel")
	self.tabs:Dock(TOP)
	self.tabs:SetTall(Scaled(30))
	self.tabs:DockMargin(0, 0, 0, Scaled(6))

	self.search = self:Add("ixFOTextEntry")
	self.search:Dock(TOP)
	self.search:SetTall(Scaled(26))
	self.search:DockMargin(0, 0, 0, Scaled(6))
	self.search:SetUpdateOnType(true)
	self.search:SetPlaceholderText("Search")
	self.search.OnValueChange = function(_, text)
		self.filter = string.lower(string.Trim(text or ""))

		self:Refresh()
	end

	self.canvas = self:Add("ixFOScrollPanel")
	self.canvas:Dock(FILL)
end

function PANEL:Say(text)
	if (IsValid(self.hint)) then
		self.hint:SetText(text)
	end
end

--- My rank in the faction being shown, or 0 if it is not mine.
function PANEL:MyRank()
	local character = LocalPlayer():GetCharacter()

	if (not character) then return 0 end

	local own = ix.faction.indices[character:GetFaction()]

	if (not own or own.uniqueID ~= self.faction) then return 0 end

	local info = ix.class.list[character:GetClass()]

	return info and (info.rank or 1) or 0
end

function PANEL:Refresh()
	if (not self.faction) then return end

	local faction = ix.faction.teams[self.faction]

	self:SetTitle(string.upper(faction and faction.name or self.faction)
		.. (self.admin and " (ADMIN)" or ""))

	local rank = self:MyRank()
	local canDeploy = self.admin or rank >= 4

	self.factionColumn:SetVisible(self.admin)

	if (self.admin) then
		self:RefreshFactions()
	end

	self.tabs:Clear()

	local pages = {{"members", "MEMBERS"}}

	if (canDeploy) then
		pages[#pages + 1] = {"deployables", "DEPLOYABLES"}
	end

	if (not canDeploy and self.page == "deployables") then
		self.page = "members"
	end

	for _, page in ipairs(pages) do
		local tab = self.tabs:Add("ixFOButton")

		tab:Dock(LEFT)
		tab:SetText(page[2])
		tab:SizeToContentsX(Scaled(20))
		tab:DockMargin(0, 0, Scaled(4), 0)
		tab:SetContentAlignment(5)
		tab.bActive = self.page == page[1]

		tab.DoClick = function()
			self.page = page[1]

			self:Refresh()
		end
	end

	if (self.page == "members") then
		self:BuildMembers(rank)
	else
		self:BuildStorages()
	end
end

--[[
	Every faction, with how many characters and storages it has.

	Sorted by whether it has anybody in it, then by name - forty-five names is
	a long list to scroll and the ones with members are the ones anybody
	opening this is looking for. Same reasoning as the shop configurer's.
]]
function PANEL:RefreshFactions()
	self.factionList:Clear()

	local names = {}

	for id, faction in pairs(ix.faction.teams) do
		local counts = ix.factionManage.factions[id] or {}

		names[#names + 1] = {
			id = id,
			name = faction.name,
			colour = faction.color,
			members = counts.members or 0,
			storages = counts.storages or 0
		}
	end

	table.sort(names, function(a, b)
		if ((a.members > 0) ~= (b.members > 0)) then
			return a.members > 0
		end

		return a.name < b.name
	end)

	for _, entry in ipairs(names) do
		local row = Row(self.factionList, Scaled(28))

		row.selected = self.faction == entry.id

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()

			if (entry.id == self.faction) then
				surface.SetDrawColor(ColorAlpha(palette.color_primary, 40))
				surface.DrawRect(0, 0, width, tall)
			end

			surface.SetDrawColor(entry.colour or palette.color_primary)
			surface.DrawRect(Scaled(9), tall * 0.5 - Scaled(5),
				Scaled(10), Scaled(10))

			draw.SimpleText(entry.name, "ixLootRow", Scaled(26), Scaled(3),
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			draw.SimpleText(string.format("%d member%s%s", entry.members,
				entry.members == 1 and "" or "s",
				entry.storages > 0
					and (", " .. entry.storages .. " storage") or ""),
				"ixLootSmall", Scaled(26), Scaled(16),
				ColorAlpha(palette.color_primary, 180),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		row.DoClick = function()
			if (entry.id == self.faction) then return end

			--[[
				The server is asked for the new faction rather than the window
				switching to data it does not have. It answers with an
				`ixFMOpen` that sets `faction` here, so one path sets it and
				the permission that comes with it.
			]]
			net.Start("ixFMOpen")
				net.WriteString(entry.id)
				net.WriteBool(true)
			net.SendToServer()

			self:Say("Loading " .. entry.name .. "...")
		end
	end
end

function PANEL:BuildMembers(rank)
	self.canvas:Clear()

	local members = ix.factionManage.members[self.faction] or {}
	local online = 0

	for _, member in ipairs(members) do
		if (member.online) then online = online + 1 end
	end

	--[[
		WHAT THE FACTION IS KNOWN FOR, above its roster.

		The band and the percentage together, because the band is the label
		people use and the percentage is the thing that moves - "Wasteland
		Heroes" on its own gives nobody any idea how close they are to being
		something else.
	]]
	local good, bad = ix.karma.FactionKarma(self.faction)
	local band, colour = ix.karma.Band(good, bad)
	local karma = ""

	if (good + bad > 0) then
		karma = string.format("  %s (%d%%) - %d good, %d bad.", band.name,
			math.Round(ix.karma.Ratio(good, bad) * 100), good, bad)
	end

	self:Say(string.format("%d member%s, %d online.%s  %s",
		#members, #members == 1 and "" or "s", online, karma,
		self.admin and "As a superadmin you may manage any of them."
			or "You may manage anyone below your own rank."))

	--[[
		The band's colour is the one thing a sentence cannot carry. `self.hint`
		is the label `Say` writes into - it is reached directly here rather
		than through `Say`, which only takes text.
	]]
	if (IsValid(self.hint)) then
		self.hint:SetTextColor(good + bad > 0 and colour
			or ix.fallout.GetPalette().text_primary)
	end

	for _, member in ipairs(members) do
		if (self.filter ~= ""
		and not string.find(string.lower(member.name), self.filter, 1, true)) then
			continue
		end

		self:AddMemberRow(member, rank)
	end
end

function PANEL:AddMemberRow(member, rank)
	--[[
		STRICTLY BELOW, which is the rule everywhere else too: two officers
		cannot act on each other, and nobody can act on themselves.
	]]
	local canAct = self.admin or rank > member.rank

	local row = Row(self.canvas, Scaled(34))

	row.PaintRow = function(_, width, tall)
		local palette = ix.fallout.GetPalette()

		--[[
			A dot for whether they are here. The roster is mostly people who
			are not, so the useful signal is which of them you could also
			simply talk to.
		]]
		surface.SetDrawColor(member.online and Color(90, 210, 90)
			or Color(90, 90, 100))
		surface.DrawRect(Scaled(10), tall * 0.5 - Scaled(4),
			Scaled(8), Scaled(8))

		draw.SimpleText(member.name, "ixLootRow", Scaled(26), Scaled(4),
			palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(member.className or "No class", "ixLootSmall",
			Scaled(26), Scaled(19),
			ColorAlpha(palette.color_primary, 200),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		--[[
			THEIR KARMA, on the right of their own row.

			The faction's total is the sum of what these people have done, so
			the roster is the one place where "who is dragging us down" has an
			answer. Drawn from the far right INWARDS, clear of the buttons,
			which are docked from the right and never reach this far.
		]]
		if ((member.good or 0) + (member.bad or 0) > 0) then
			local title, level, colour = ix.karma.Describe(member.good,
				member.bad)

			draw.SimpleText(title, "ixLootSmall", width - Scaled(210),
				Scaled(4), colour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

			draw.SimpleText(string.format("Karma %d - %d good, %d bad",
				level, member.good, member.bad), "ixLootSmall",
				width - Scaled(210), Scaled(19),
				ColorAlpha(palette.text_primary, 150),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end
	end

	if (not canAct) then return end

	--[[
		Buttons are added right to left, so they read kick / class / rename in
		the order the docking produces - the destructive one furthest from the
		text, where a misclick is least likely.
	]]
	local kick = FitButton(row, "KICK")

	kick:Dock(RIGHT)
	kick:DockMargin(Scaled(4), Scaled(5), Scaled(6), Scaled(5))

	kick.DoClick = function()
		Derma_Query(string.format("Remove %s from the faction?", member.name),
			"Faction", "Remove", function()
				self:Act("kick", member.id, "")
			end, "Cancel", function() end)
	end

	local class = FitButton(row, "SET CLASS")

	class:Dock(RIGHT)
	class:DockMargin(Scaled(4), Scaled(5), 0, Scaled(5))
	class.DoClick = function() self:OpenClassPicker(member, rank) end

	local rename = FitButton(row, "RENAME")

	rename:Dock(RIGHT)
	rename:DockMargin(Scaled(4), Scaled(5), 0, Scaled(5))

	rename.DoClick = function()
		Derma_StringRequest("Rename", "A new name for " .. member.name,
			member.name, function(text)
				self:Act("rename", member.id, text)
			end)
	end
end

function PANEL:OpenClassPicker(member, rank)
	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(360), Scaled(420))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("SET CLASS")

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetText("CANCEL")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local caption = frame:Add("ixFOLabel")

	caption:Dock(TOP)
	caption:SetTall(Scaled(22))
	caption:SetFont("ixLootSmall")
	caption:SetText(member.name)

	local list = frame:Add("ixFOScrollPanel")

	list:Dock(FILL)

	local team = ix.faction.teams[self.faction]
	local shown = 0

	for _, info in ipairs(ix.class.list) do
		if (not team or info.faction ~= team.index) then continue end

		--[[
			Only ranks below your own, unless you are an admin. Somebody has to
			be able to appoint a faction's first lead and nobody inside it can.
		]]
		if (not self.admin and (info.rank or 1) >= rank) then continue end

		local option = Row(list, Scaled(26))

		shown = shown + 1

		option.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()

			draw.SimpleText(info.name, "ixLootRow", Scaled(10), tall * 0.5,
				info.uniqueID == member.class and palette.color_primary
				or palette.text_primary,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText("rank " .. (info.rank or 1), "ixLootSmall",
				width - Scaled(8), tall * 0.5,
				ColorAlpha(palette.color_primary, 180),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		option.DoClick = function()
			self:Act("setclass", member.id, info.uniqueID)

			frame:Remove()
		end
	end

	if (shown == 0) then
		local empty = list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText("Nothing below your own rank to give.")
	end
end

function PANEL:BuildStorages()
	self.canvas:Clear()

	local records = ix.factionManage.storages[self.faction] or {}

	--[[
		Making one is a superadmin's job, so the button is only here for them -
		and it is at the top of the list rather than in a menu, because on an
		empty page it is the only thing there is to do.
	]]
	if (self.admin) then
		local new = FitButton(self.canvas, "NEW STORAGE", 120)

		new:Dock(TOP)
		new:SetTall(Scaled(28))
		new:DockMargin(0, 0, 0, Scaled(6))
		new.DoClick = function() self:OpenStorageCreator() end
	end

	self:Say(#records == 0
		and (self.admin and "This faction has no storages. NEW STORAGE makes "
			.. "one." or "Your faction has no storages. An admin makes them.")
		or "Deploy puts one down where you are aiming. Stow picks it up with "
		.. "everything still in it.")

	for _, record in ipairs(records) do
		self:AddStorageRow(record)
	end
end

--[[
	Making a storage for the faction being viewed.

	Size is two numbers rather than a list of presets: "however big you want"
	was the requirement, and Helix registers an inventory type per size on
	demand, so there is nothing to choose from.
]]
function PANEL:OpenStorageCreator()
	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(320), Scaled(300))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("NEW STORAGE")

	local function Field(label, value, numeric)
		local caption = frame:Add("ixFOLabel")

		caption:Dock(TOP)
		caption:SetTall(Scaled(18))
		caption:SetFont("ixLootSmall")
		caption:SetText(label)

		local entry = frame:Add("ixFOTextEntry")

		entry:Dock(TOP)
		entry:SetTall(Scaled(24))
		entry:DockMargin(0, 0, 0, Scaled(6))
		entry:SetText(tostring(value))
		entry:SetNumeric(numeric or false)

		return entry
	end

	local name = Field("Name", "Faction Storage")
	local width = Field("Width, in slots", 8, true)
	local height = Field("Height, in slots", 6, true)

	local rankCaption = frame:Add("ixFOLabel")

	rankCaption:Dock(TOP)
	rankCaption:SetTall(Scaled(18))
	rankCaption:SetFont("ixLootSmall")
	rankCaption:SetText("Lowest rank that may open it")

	local rank = frame:Add("DComboBox")

	rank:Dock(TOP)
	rank:SetTall(Scaled(24))
	rank:SetSortItems(false)

	for _, value in ipairs(ix.class.GetRanks(self.faction)) do
		rank:AddChoice(string.format("%d - %s", value,
			ix.class.GetRankName(self.faction, value)), value, value == 1)
	end

	local cancel = frame:Add("ixFOButton")

	cancel:Dock(BOTTOM)
	cancel:SetText("CANCEL")
	cancel:SetContentAlignment(5)
	cancel.DoClick = function() frame:Remove() end

	local confirm = frame:Add("ixFOButton")

	confirm:Dock(BOTTOM)
	confirm:DockMargin(0, 0, 0, Scaled(4))
	confirm:SetText("CREATE")
	confirm:SetContentAlignment(5)

	confirm.DoClick = function()
		local _, chosen = rank:GetSelected()

		net.Start("ixFMStorages")
			net.WriteString(self.faction)
			net.WriteString("create")
			net.WriteUInt(0, 16)
			net.WriteBool(self.admin)
			net.WriteString(string.Trim(name:GetValue()))
			net.WriteUInt(math.Clamp(
				tonumber(width:GetValue()) or 8, 1, 20), 6)
			net.WriteUInt(math.Clamp(
				tonumber(height:GetValue()) or 6, 1, 20), 6)
			net.WriteUInt(math.Clamp(chosen or 1, 1, 4), 3)
		net.SendToServer()

		self:Say("Creating...")
		frame:Remove()
	end
end

function PANEL:AddStorageRow(record)
	local row = Row(self.canvas, Scaled(40))

	row.PaintRow = function(_, width, tall)
		local palette = ix.fallout.GetPalette()

		draw.SimpleText(record.name, "ixLootRow", Scaled(12), Scaled(5),
			palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local state

		if (record.placed and not record.thisMap) then
			--[[
				Placed, but on a different map. Saying "deployed" would be a
				lie here and saying "stowed" would be another - it is out
				there, just not anywhere reachable from this one.
			]]
			state = "deployed on another map"
		elseif (record.placed) then
			state = "deployed"
		else
			state = "stowed"
		end

		draw.SimpleText(string.format("%dx%d  -  %s or above  -  %s",
			record.width, record.height,
			ix.class.GetRankName(self.faction, record.minRank), state),
			"ixLootSmall", Scaled(12), Scaled(21),
			ColorAlpha(palette.color_primary, 200),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local deployed = record.placed and record.thisMap

	--[[
		Destroy and open are admin-only, and open is here because a stowed
		storage is otherwise unreachable - its contents exist and nothing in
		the world points at them, so somebody has to be able to look inside
		without making the faction put it down first.
	]]
	if (self.admin) then
		local destroy = FitButton(row, "DESTROY")

		destroy:Dock(RIGHT)
		destroy:DockMargin(Scaled(4), Scaled(6), Scaled(6), Scaled(6))

		destroy.DoClick = function()
			Derma_Query(string.format(
				"Destroy %s and everything in it? This cannot be undone.",
				record.name), "Faction Storage", "Destroy", function()
					self:Storage("destroy", record.id)
				end, "Cancel", function() end)
		end

		local view = FitButton(row, "OPEN")

		view:Dock(RIGHT)
		view:DockMargin(Scaled(4), Scaled(6), 0, Scaled(6))

		view.DoClick = function()
			self:Storage("view", record.id)
			self:Remove()
		end
	end

	local button = FitButton(row, deployed and "STOW" or "DEPLOY", 80)

	button:Dock(RIGHT)
	button:DockMargin(Scaled(4), Scaled(6),
		self.admin and 0 or Scaled(6), Scaled(6))

	button.DoClick = function()
		if (deployed) then
			self:Storage("stow", record.id)

			return
		end

		--[[
			The window closes to place it. The ghost follows your aim and the
			menu is in the way of both looking and clicking.
		]]
		local id = record.id
		local admin = self.admin

		self:Remove()

		ix.deploy.Begin(ix.factionStorage.model, function(position, angles)
			net.Start("ixFactionStorageDeploy")
				net.WriteUInt(id, 16)
				net.WriteVector(position)
				net.WriteAngle(angles)

				--[[
					Which window this came from. The server re-checks it
					against `IsSuperAdmin`, so sending it grants nothing on its
					own - it only says whether to ask for Lead of that faction
					or not.
				]]
				net.WriteBool(admin)
			net.SendToServer()
		end)
	end
end

--[[
	Stow, destroy and open, which differ only in the word.

	`create` is not routed through this - it carries four more fields - but
	everything else is one id and one verb.
]]
function PANEL:Storage(action, id)
	net.Start("ixFMStorages")
		net.WriteString(self.faction)
		net.WriteString(action)
		net.WriteUInt(id, 16)
		net.WriteBool(self.admin)
	net.SendToServer()
end

function PANEL:Act(action, charID, value)
	net.Start("ixFMAction")
		net.WriteString(action)
		net.WriteString(self.faction)
		net.WriteUInt(charID, 32)
		net.WriteString(value or "")
		net.WriteBool(self.admin)
	net.SendToServer()

	self:Say("Sent...")
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOFactionManage", PANEL, "ixFOFrame")

--------------------------------------------------------------------------------

net.Receive("ixFMOpen", function()
	local faction = net.ReadString()
	local admin = net.ReadBool()

	local panel = IsValid(ix.gui.factionManage) and ix.gui.factionManage
		or vgui.Create("ixFOFactionManage")

	if (not IsValid(panel)) then return end

	panel.faction = faction
	panel.admin = admin

	panel:Refresh()

	--[[
		The counts are asked for separately, and only by the admin window. They
		need a query per open and the ordinary `/fm` never shows them.
	]]
	if (admin) then
		net.Start("ixFMFactions")
		net.SendToServer()
	end
end)

net.Receive("ixFMFactions", function()
	local count = net.ReadUInt(8)

	ix.factionManage.factions = {}

	for _ = 1, count do
		local id = net.ReadString()

		ix.factionManage.factions[id] = {
			members = net.ReadUInt(16),
			storages = net.ReadUInt(8)
		}
	end

	if (IsValid(ix.gui.factionManage)) then
		ix.gui.factionManage:Refresh()
	end
end)

net.Receive("ixFMMembers", function()
	local faction = net.ReadString()
	local admin = net.ReadBool()
	local count = net.ReadUInt(16)
	local out = {}

	for _ = 1, count do
		local member = {
			id = net.ReadUInt(32),
			name = net.ReadString(),
			class = net.ReadString(),
			rank = net.ReadUInt(3),
			online = net.ReadBool(),
			good = net.ReadUInt(32),
			bad = net.ReadUInt(32)
		}

		--[[
			The class NAME is looked up here rather than sent. The client has
			the whole class list already, so sending it would be sending
			something both ends already know.
		]]
		for _, info in ipairs(ix.class.list) do
			if (info.uniqueID == member.class) then
				member.className = info.name

				break
			end
		end

		out[#out + 1] = member
	end

	ix.factionManage.members[faction] = out

	if (IsValid(ix.gui.factionManage)) then
		ix.gui.factionManage.admin = admin

		ix.gui.factionManage:Refresh()
	end
end)

net.Receive("ixFMStorages", function()
	local faction = net.ReadString()
	local count = net.ReadUInt(8)
	local out = {}

	for _ = 1, count do
		local record = {
			id = net.ReadUInt(16),
			faction = faction,
			name = net.ReadString(),
			width = net.ReadUInt(6),
			height = net.ReadUInt(6),
			minRank = net.ReadUInt(3),
			placed = net.ReadBool(),
			thisMap = net.ReadBool()
		}

		out[#out + 1] = record

		--- Kept by id as well, for the entity tooltip.
		ix.factionStorage.list[record.id] = record
	end

	ix.factionManage.storages[faction] = out

	if (IsValid(ix.gui.factionManage)) then
		ix.gui.factionManage:Refresh()
	end
end)

--[[
	`/raidstats` - who won, and by how much.

	Phoenix show a bar split between the two sides. This one has THREE
	segments, because this schema lets a third faction skirmish and leaving
	them off the bar would credit their kills to nobody - the server owner
	asked for them to be on it.

	WHAT "WON" MEANS HERE: kills, weighed against deaths.

	    share = kills / (everybody's kills)

	which is a k/d in the only form that adds up to a whole - a side's share of
	the killing. The raw kills and deaths are underneath for anybody who wants
	to argue with it, and clicking a faction's icon opens the people who
	fought, sorted by their own ratio.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

local SIDES = {
	{id = "attackers", name = "ATTACKERS", colour = Color(225, 105, 80)},
	{id = "defenders", name = "DEFENDERS", colour = Color(90, 160, 230)},
	{id = "skirmishers", name = "SKIRMISHERS", colour = Color(230, 180, 60)}
}

function PANEL:Init()
	self:SetSize(Scaled(900), Scaled(620))
	self:Center()
	self:MakePopup()
	self:SetTitle("CONFLICT REPORT")

	--[[
		EVERYTHING IS BUILT INSIDE THIS, and never into the frame itself.

		`self:Clear()` on a DFrame removes ITS OWN CHILDREN - the title label
		and the close button included - and both are then used every frame by
		code that assumes they exist:

		    dframe.lua:246                self.btnClose:SetPos(...)
		    fallout_ui/cl_widgets.lua:286 self.lblTitle:GetContentSize()

		which is thousands of "Tried to use a NULL Panel" a second and a report
		with no chrome. A content panel is the fix: clearing it throws away
		exactly what this file made and nothing else.
	]]
	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(Scaled(8), Scaled(28), Scaled(8), Scaled(8))

	--[[
		A CLOSE BUTTON OF ITS OWN, because `ixFOFrame` hides DFrame's.

		`fallout_ui/cl_widgets.lua` calls `ShowCloseButton(false)` on every
		frame in this schema - the theme has no window chrome - so a panel that
		does not draw its own way out is a panel you leave with the console.
		Every other window here does the same thing at the bottom.
	]]
	local close = self:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(30))
	close:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(8))
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	ix.gui.raidStats = self
end

--[[
	ESCAPE CLOSES IT TOO. It is a report rather than a form, and a window with
	nothing to fill in should shut the way every other one in the game does.
]]
function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

--------------------------------------------------------------------------------
-- The arithmetic
--------------------------------------------------------------------------------

--[[
	Every faction on one side, with its scoreline.

	The two principals are included in their own sides, which is why this reads
	`attacker`/`defender` as well as the assist lists: they are the conflict,
	not assistants to it.
]]
function PANEL:Factions(side)
	local stats = self.stats
	local out = {}

	if (side == "attackers" and stats.attacker) then
		out[#out + 1] = stats.attacker
	end

	if (side == "defenders" and stats.defender) then
		out[#out + 1] = stats.defender
	end

	--- Assists under the principal, in a fixed order - see `cl_raid.lua`.
	local helping = {}

	for faction in pairs(stats[side] or {}) do
		helping[#helping + 1] = tonumber(faction)
	end

	table.sort(helping)

	for _, faction in ipairs(helping) do
		out[#out + 1] = faction
	end

	return out
end

function PANEL:SideScore(side)
	local kills, deaths = 0, 0

	for _, faction in ipairs(self:Factions(side)) do
		local score = self.stats.kills[faction]

		if (score) then
			kills = kills + (score.kills or 0)
			deaths = deaths + (score.deaths or 0)
		end
	end

	return kills, deaths
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

function PANEL:Setup(stats)
	self.stats = stats
	self.stats.kills = stats.kills or {}

	self:Build()
end

function PANEL:Build()
	self.content:Clear()

	local stats = self.stats
	local info = ix.raid.types[stats.type]
	local attacker = ix.faction.indices[stats.attacker]
	local defender = ix.faction.indices[stats.defender]

	local header = self.content:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(34))
	header:SetFont("UI_Bold")
	header:SetContentAlignment(5)
	header:SetText(string.format("%s   -   %s vs %s",
		string.upper(info and info.name or stats.type or "CONFLICT"),
		attacker and attacker.name or "?", defender and defender.name or "?"))

	local subtitle = self.content:Add("ixFOLabel")

	subtitle:Dock(TOP)
	subtitle:SetTall(Scaled(20))
	subtitle:SetFont("ixLootSmall")
	subtitle:SetContentAlignment(5)
	subtitle:SetTextColor(Color(160, 160, 150))
	subtitle:SetText(string.format("%d minutes of fighting%s",
		math.max(math.floor(((stats.endTime or 0)
			- (stats.startTime or 0)) / 60), 0),
		stats.forced and ", called off early" or ""))

	self:BuildBar()
	self:BuildColumns()
end

--[[
	THE BAR. One segment per side, in proportion to its share of the killing.

	A side that killed nobody gets no segment rather than a sliver, and a
	conflict where nobody died at all is drawn as one grey block - which is an
	honest way to say "nothing happened" and better than three equal thirds,
	which would read as a draw between people who never met.
]]
function PANEL:BuildBar()
	local bar = self.content:Add("ixFOPanelBracketed")

	bar:Dock(TOP)
	bar:SetTall(Scaled(46))
	bar:DockMargin(0, Scaled(8), 0, Scaled(4))
	bar:DockPadding(Scaled(4), Scaled(4), Scaled(4), Scaled(4))
	bar:SetNoOverdraw(true)

	local totals = {}
	local grand = 0

	for _, side in ipairs(SIDES) do
		local kills = self:SideScore(side.id)

		totals[side.id] = kills
		grand = grand + kills
	end

	bar.Paint = function(_, width, height)
		if (grand <= 0) then
			surface.SetDrawColor(70, 70, 66)
			surface.DrawRect(0, 0, width, height)

			draw.SimpleText("NOBODY DIED", "ixLootRow", width * 0.5,
				height * 0.5, color_white, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			return
		end

		local x = 0

		for _, side in ipairs(SIDES) do
			local share = totals[side.id] / grand

			if (share <= 0) then continue end

			local segment = width * share

			surface.SetDrawColor(side.colour)
			surface.DrawRect(x, 0, segment, height)

			--- The percentage goes inside its own segment, if it fits.
			if (segment > Scaled(46)) then
				draw.SimpleText(string.format("%d%%", math.Round(share * 100)),
					"ixLootRow", x + segment * 0.5, height * 0.5, color_black,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			x = x + segment
		end
	end
end

--- One column per side, each a list of the factions that fought on it.
function PANEL:BuildColumns()
	local body = self.content:Add("Panel")

	body:Dock(FILL)
	body:DockMargin(0, Scaled(4), 0, 0)

	self.detail = body:Add("ixFOScrollPanel")

	self.detail:Dock(BOTTOM)
	self.detail:SetTall(Scaled(260))
	self.detail:DockMargin(0, Scaled(8), 0, 0)

	self:ShowPeople(nil)

	for _, side in ipairs(SIDES) do
		local column = body:Add("Panel")

		column:Dock(LEFT)
		column:SetWide(Scaled(292))
		column:DockMargin(0, 0, Scaled(8), 0)

		local title = column:Add("ixFOLabel")

		title:Dock(TOP)
		title:SetTall(Scaled(22))
		title:SetFont("ixLootRow")
		title:SetTextColor(side.colour)
		title:SetContentAlignment(5)

		local kills, deaths = self:SideScore(side.id)

		title:SetText(string.format("%s   %d / %d", side.name, kills, deaths))

		local list = column:Add("ixFOScrollPanel")

		list:Dock(FILL)

		for _, faction in ipairs(self:Factions(side.id)) do
			self:AddFaction(list, faction, side)
		end
	end
end

--[[
	One faction, with its icon.

	THE ICON IS THE FACTION'S OWN, which is what makes this readable at a
	glance - `FACTION.icon` is set for every faction in this schema from the
	`phoenix_faction_icons` pack. Clicking it opens the people who fought for
	it.
]]
function PANEL:AddFaction(parent, index, side)
	local data = ix.faction.indices[index]

	if (not data) then return end

	local score = self.stats.kills[index] or {kills = 0, deaths = 0}

	local row = parent:Add("ixFOButton")

	row:Dock(TOP)
	row:SetTall(Scaled(44))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:SetText("")
	row.DoClick = function() self:ShowPeople(index) end

	local icon = data.icon and Material(data.icon) or nil

	row.PaintOver = function(_, width, height)
		if (icon) then
			surface.SetDrawColor(color_white)
			surface.SetMaterial(icon)
			surface.DrawTexturedRect(Scaled(4), Scaled(4), Scaled(36),
				Scaled(36))
		end

		draw.SimpleText(data.name, "ixLootRow", Scaled(48), height * 0.32,
			data.color or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("%d kills   %d deaths   %s",
			score.kills or 0, score.deaths or 0,
			(score.deaths or 0) > 0
				and string.format("%.2f", (score.kills or 0) / score.deaths)
				or "-"),
			"ixLootSmall", Scaled(48), height * 0.68, Color(170, 170, 160),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		--- A stripe in the side's colour, so a column is readable when scrolled.
		surface.SetDrawColor(side.colour)
		surface.DrawRect(0, 0, Scaled(2), height)
	end
end

--[[
	The people, for one faction or the instruction to pick one.

	Sorted by kills and then by deaths ascending, which puts "killed four, died
	none" above "killed four, died six" - the ratio without the division by
	zero.
]]
function PANEL:ShowPeople(index)
	self.detail:Clear()

	local heading = self.detail:Add("ixFOLabel")

	heading:Dock(TOP)
	heading:SetTall(Scaled(26))
	heading:SetFont("UI_Bold")

	if (not index) then
		heading:SetText("Click a faction to see who fought for it.")
		heading:SetTextColor(Color(160, 160, 150))

		return
	end

	local data = ix.faction.indices[index]
	local score = self.stats.kills[index] or {players = {}}

	heading:SetText(string.upper(data and data.name or "?"))
	heading:SetTextColor(data and data.color or color_white)

	local people = {}

	for id, entry in pairs(score.players or {}) do
		people[#people + 1] = {
			id = id,
			name = entry.name or id,
			kills = entry.kills or 0,
			deaths = entry.deaths or 0
		}
	end

	if (#people == 0) then
		local empty = self.detail:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(24))
		empty:SetFont("ixLootRow")
		empty:SetTextColor(Color(160, 160, 150))
		empty:SetText("Nobody from this faction fired a shot that landed.")

		return
	end

	table.sort(people, function(a, b)
		if (a.kills == b.kills) then return a.deaths < b.deaths end

		return a.kills > b.kills
	end)

	--[[
		THE NAME IN THE FACTION'S OWN COLOUR, which is the whole point of
		opening one of these: the list is read while somebody is arguing about
		which side a name was on, and the colour answers that before the eye
		reaches the numbers.

		`DockMargin` leaves room on the RIGHT for the scrollbar. A list of
		thirty people is a list that scrolls, and rows drawn under the bar put
		their k/d behind it.
	]]
	local colour = data and data.color or color_white

	for _, person in ipairs(people) do
		local row = self.detail:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(28))
		row:DockMargin(0, 0, Scaled(18), Scaled(3))
		row:SetNoOverdraw(true)

		row.Paint = function(_, width, height)
			draw.SimpleText(person.name, "ixLootRow", Scaled(8), height * 0.5,
				colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("%d / %d", person.kills,
				person.deaths), "ixLootRow", width - Scaled(76), height * 0.5,
				Color(220, 220, 210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			draw.SimpleText(person.deaths > 0
				and string.format("%.2f", person.kills / person.deaths)
				or "-", "ixLootRow", width - Scaled(8), height * 0.5,
				Color(170, 170, 160), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

function PANEL:OnRemove()
	if (ix.gui.raidStats == self) then ix.gui.raidStats = nil end
end

vgui.Register("ixFORaidStats", PANEL, "ixFOFrame")

--[[
	`/ticketstats` - who has actually been answering them.

	Four numbers per staff member, and the fourth is the one that matters:

	    CLAIMED    how many they took
	    CLOSED     how many they finished
	    AVERAGE    how long the reporter waited before they took it
	    LAST       when they last took one

	CLAIMED AND CLOSED ARE SEPARATE ON PURPOSE. Somebody who claims eleven and
	closes two is either being pulled away constantly or is hoarding the queue,
	and one number that added them together would hide both. The gap is the
	interesting part.

	AVERAGE IS A WAIT, NOT A DURATION. It is measured from the moment the
	player pressed enter to the moment somebody claimed it - not to the moment
	it was closed - because that is the number the player experiences, and
	because a long conversation afterwards is good work rather than a delay.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

--- Seconds as something a person reads. `ix.ambush.Time` says the same thing.
local function Time(seconds)
	seconds = math.floor(seconds or 0)

	if (seconds < 60) then return seconds .. "s" end
	if (seconds < 3600) then
		return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
	end

	return string.format("%dh %dm", math.floor(seconds / 3600),
		math.floor(seconds % 3600 / 60))
end

--- How long ago, from a `os.time` stamp. Nil is somebody who never has.
local function Ago(stamp)
	if (not stamp or stamp <= 0) then return "never" end

	return Time(os.time() - stamp) .. " ago"
end

function PANEL:Init()
	self:SetSize(Scaled(760), Scaled(560))
	self:Center()
	self:MakePopup()
	self:SetTitle("TICKET STATISTICS")

	--[[
		BUILT INSIDE A CONTENT PANEL, never into the frame.

		`self:Clear()` on a DFrame removes ITS OWN CHILDREN - `lblTitle` and
		`btnClose` included - and both are then used every frame by code that
		assumes they exist, which is thousands of "Tried to use a NULL Panel" a
		second. `derma/cl_raidstats.lua` learned this the hard way and says so
		at length.
	]]
	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(Scaled(8), Scaled(28), Scaled(8), Scaled(8))

	--- `ixFOFrame` hides DFrame's close button, so every window here draws one.
	local close = self:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(30))
	close:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(8))
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	ix.gui.ticketStats = self
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local COLUMNS = {
	{name = "STAFF", width = 0.34, align = TEXT_ALIGN_LEFT},
	{name = "CLAIMED", width = 0.13, align = TEXT_ALIGN_CENTER},
	{name = "CLOSED", width = 0.13, align = TEXT_ALIGN_CENTER},
	{name = "AVERAGE WAIT", width = 0.2, align = TEXT_ALIGN_CENTER},
	{name = "LAST CLAIM", width = 0.2, align = TEXT_ALIGN_CENTER}
}

local function DrawRow(panel, width, height, values, font, colour)
	local x = 0

	for index, column in ipairs(COLUMNS) do
		local columnWidth = width * column.width
		local textX = x + Scaled(6)

		if (column.align == TEXT_ALIGN_CENTER) then
			textX = x + columnWidth * 0.5
		end

		draw.SimpleText(values[index] or "", font, textX, height * 0.5,
			colour, column.align, TEXT_ALIGN_CENTER)

		x = x + columnWidth
	end
end

function PANEL:Setup(stats)
	self.content:Clear()

	--------------------------------------------------------------- header ---

	local header = self.content:Add("Panel")

	header:Dock(TOP)
	header:SetTall(Scaled(26))

	header.Paint = function(panel, width, height)
		local palette = ix.fallout.GetPalette()
		local names = {}

		for index, column in ipairs(COLUMNS) do names[index] = column.name end

		DrawRow(panel, width, height, names, "ixLootHeader",
			palette.color_primary)
	end

	------------------------------------------------------------- the rows ---

	--[[
		SORTED BY WHO IS DOING THE WORK. Claims descending is the order this
		list is opened to see, and a table sorted by name would bury it.
	]]
	local rows = {}

	for steamID, row in pairs(stats) do
		rows[#rows + 1] = {
			steamID = steamID,
			name = row.name or steamID,
			claims = row.claims or 0,
			closes = row.closes or 0,
			respond = row.respond or 0,
			last = row.last
		}
	end

	table.sort(rows, function(a, b)
		if (a.claims ~= b.claims) then return a.claims > b.claims end

		return a.closes > b.closes
	end)

	local scroll = self.content:Add("ixFOScrollPanel")

	scroll:Dock(FILL)
	scroll:DockMargin(0, Scaled(4), 0, 0)

	local totalClaims, totalCloses, totalWait = 0, 0, 0

	for index, row in ipairs(rows) do
		local panel = scroll:Add("Panel")

		panel:Dock(TOP)
		panel:SetTall(Scaled(24))

		totalClaims = totalClaims + row.claims
		totalCloses = totalCloses + row.closes
		totalWait = totalWait + row.respond

		--[[
			DIVIDED HERE AND NOWHERE ELSE. The server keeps the TOTAL wait
			because totals can be added to and averages cannot - a running
			average would have to be re-weighted on every claim, and one of
			those arithmetic mistakes is a statistic nobody can ever check.
		]]
		local average = row.claims > 0 and (row.respond / row.claims) or 0

		local values = {
			row.name, tostring(row.claims), tostring(row.closes),
			row.claims > 0 and Time(average) or "-", Ago(row.last)
		}

		panel.Paint = function(self2, width, height)
			if (index % 2 == 0) then
				surface.SetDrawColor(255, 255, 255, 8)
				surface.DrawRect(0, 0, width, height)
			end

			--[[
				SOMEBODY WHO CLAIMS AND DOES NOT CLOSE IS PICKED OUT. It is the
				one thing on this screen that is a problem rather than a
				number, and a person reading a table of forty rows will not
				find it by subtracting columns in their head.
			]]
			local colour = color_white

			if (row.claims > 3 and row.closes < row.claims * 0.5) then
				colour = Color(235, 170, 90)
			end

			DrawRow(self2, width, height, values, "ixLootRow", colour)
		end
	end

	-------------------------------------------------------------- the sum ---

	local footer = self.content:Add("ixFOLabel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(24))
	footer:DockMargin(0, Scaled(4), 0, 0)
	footer:SetFont("ixLootRow")
	footer:SetTextColor(ix.fallout.GetPalette().color_primary)
	footer:SetText(string.format(
		"%d staff  -  %d claimed  -  %d closed  -  %s average wait overall",
		#rows, totalClaims, totalCloses,
		totalClaims > 0 and Time(totalWait / totalClaims) or "-"))
end

vgui.Register("ixFOTicketStats", PANEL, "ixFOFrame")

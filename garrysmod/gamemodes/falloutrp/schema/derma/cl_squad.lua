--[[
	The squad window: `/squad`, or `fo_squad_menu` on a key.

	Everything the commands do, as buttons, plus the one thing they cannot:
	acting on somebody who is offline. Rows are people; what a row offers
	depends on who is looking - a leader sees promote, demote, hand-over and
	kick, an officer sees kick on members, a member sees the list.

	Every button sends `ix.squad.Act` and the server decides. The window
	itself is rebuilt from `ix.squad.mine` whenever the server sends a new
	one (`SquadUpdated`), so it is never showing a state that has changed.

	`derma/` loads before `sh_schema.lua`: nothing from `ix.fallout` or
	`ix.squad` is read at file scope here.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

local NOTE = Color(190, 190, 180)
local DIM = Color(140, 140, 140)

function PANEL:Init()
	if (ix.fallout and ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(Scaled(600), Scaled(460))
	self:Center()
	self:MakePopup()
	self:SetTitle("SQUAD")

	--- Built inside a content panel, never into the frame; see cl_ticketstats.
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

	self:Rebuild()

	ix.gui.squad = self
end

--- A label, in one line, because there are a lot of them.
local function Label(parent, text, font, color)
	local label = parent:Add("ixFOLabel")

	label:SetText(text)
	label:SetFont(font or "ixLootRow")
	label:SetTextColor(color or color_white)
	label:SizeToContents()

	return label
end

--- A bottom-bar button that sends one action and closes nothing.
local function Button(parent, text, callback)
	local button = parent:Add("ixFOButton")

	button:Dock(LEFT)
	button:SetWide(Scaled(112))
	button:DockMargin(0, 0, Scaled(6), 0)
	button:SetText(text)
	button:SetFont("ixLootBadge")
	button:SetContentAlignment(5)
	button.DoClick = callback

	return button
end

--------------------------------------------------------------------------------
-- Not in one
--------------------------------------------------------------------------------

function PANEL:BuildEmpty()
	local content = self.content

	Label(content, "You are not in a squad.", "ixLootHeader"):Dock(TOP)

	local note = Label(content, "Name one to form it. Whoever you invite "
		.. "joins it; hold E on them, or /squadinvite.", "ixLootBadge", NOTE)

	note:Dock(TOP)
	note:DockMargin(0, Scaled(4), 0, Scaled(12))

	local entry = content:Add("DTextEntry")

	entry:Dock(TOP)
	entry:SetTall(Scaled(30))
	entry:SetFont("ixLootRow")
	entry:SetPlaceholderText("Squad name")

	local bar = content:Add("Panel")

	bar:Dock(TOP)
	bar:SetTall(Scaled(30))
	bar:DockMargin(0, Scaled(8), 0, 0)

	Button(bar, "CREATE", function()
		ix.squad.Act("create", 0, entry:GetValue())
	end)

	if (ix.squad.invite) then
		local invite = ix.squad.invite

		local who = Label(content, (invite.from or "Somebody")
			.. " has invited you to '" .. (invite.squad or "?") .. "'.",
			"ixLootRow")

		who:Dock(TOP)
		who:DockMargin(0, Scaled(20), 0, Scaled(6))

		local answer = content:Add("Panel")

		answer:Dock(TOP)
		answer:SetTall(Scaled(30))

		Button(answer, "ACCEPT", function() ix.squad.Act("accept") end)
		Button(answer, "DECLINE", function() ix.squad.Act("decline") end)
	end
end

--------------------------------------------------------------------------------
-- In one
--------------------------------------------------------------------------------

function PANEL:BuildRow(list, entry, mine, myRank)
	local row = list:Add("Panel")

	row:Dock(TOP)
	row:SetTall(Scaled(34))
	row:DockMargin(0, 0, 0, Scaled(4))

	local color = ix.squad.ColorOf(mine)

	row.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(color.r, color.g, color.b,
			entry.online and 255 or 90)
		surface.DrawRect(0, 0, Scaled(4), h)
	end

	local mark = ix.squad.rankMarks[entry.rank]
	local name = Label(row, (mark and (mark .. " ") or "") .. entry.name,
		"ixLootRow", entry.online and color_white or DIM)

	name:Dock(LEFT)
	name:DockMargin(Scaled(10), 0, 0, 0)
	name:SetWide(Scaled(200))

	local status = Label(row, string.format("%s  ·  Lv %d  ·  %s",
		ix.squad.rankNames[entry.rank] or "?", entry.level or 1,
		entry.online and "online" or "offline"), "ixLootBadge", NOTE)

	status:Dock(LEFT)
	status:SetWide(Scaled(150))

	local me = LocalPlayer():GetNetVar("char")

	if (entry.id == me) then return end

	--- Right-docked, so they are added last-first.
	local function Action(text, action, tip)
		local button = row:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(Scaled(74))
		button:DockMargin(Scaled(4), Scaled(5), 0, Scaled(5))
		button:SetText(text)
		button:SetFont("ixLootBadge")
		button:SetContentAlignment(5)
		button:SetTooltip(tip)
		button.DoClick = function() ix.squad.Act(action, entry.id) end
	end

	if (myRank == ix.squad.LEADER) then
		Action("KICK", "kick", "Remove them from the squad.")

		if (entry.rank == ix.squad.OFFICER) then
			Action("DEMOTE", "demote", "Make them a member again.")
			Action("LEADER", "leader", "Hand the squad to them.")
		else
			Action("PROMOTE", "promote", "Make them an officer.")
		end
	elseif (myRank == ix.squad.OFFICER and entry.rank == ix.squad.MEMBER) then
		Action("KICK", "kick", "Remove them from the squad.")
	end
end

function PANEL:BuildSquad(mine)
	local content = self.content
	local me = LocalPlayer():GetNetVar("char")
	local myRank = ix.squad.RankIn(mine, me)
	local color = ix.squad.ColorOf(mine)

	local title = Label(content, mine.name, "ixLootHeader", color)

	title:Dock(TOP)

	local leader

	for _, entry in ipairs(mine.roster or {}) do
		if (entry.rank == ix.squad.LEADER) then leader = entry.name end
	end

	local note = Label(content, string.format("%d in the squad  ·  led by %s"
		.. "  ·  you are %s", #(mine.roster or {}), leader or "nobody",
		string.lower(ix.squad.rankNames[myRank] or "in it")), "ixLootBadge",
		NOTE)

	note:Dock(TOP)
	note:DockMargin(0, Scaled(2), 0, Scaled(10))

	--- The bottom bar first, so the list takes what is left.
	local bar = content:Add("Panel")

	bar:Dock(BOTTOM)
	bar:SetTall(Scaled(30))
	bar:DockMargin(0, Scaled(8), 0, 0)

	if (myRank >= ix.squad.OFFICER) then
		Button(bar, "INVITE", function()
			Derma_StringRequest("Invite", "Who? Their name, or part of it.",
				"", function(text)
					ix.squad.Act("invite", 0, text)
				end)
		end)
	end

	if (myRank == ix.squad.LEADER) then
		Button(bar, "RENAME", function()
			Derma_StringRequest("Rename", "What is the squad called now?",
				mine.name, function(text)
					ix.squad.Act("rename", 0, text)
				end)
		end)

		local swatch = ix.squad.palette[mine.color or 1]

		Button(bar, "COLOUR: " .. string.upper(swatch and swatch.name or "?"),
			function()
				ix.squad.Act("color", (mine.color % #ix.squad.palette) + 1)
			end):SetWide(Scaled(150))

		Button(bar, "DISBAND", function()
			Derma_Query("Disband '" .. mine.name .. "'? Everybody is out.",
				"Disband", "Disband", function() ix.squad.Act("disband") end,
				"Keep it")
		end)
	end

	Button(bar, "LEAVE", function()
		Derma_Query("Leave '" .. mine.name .. "'?", "Leave", "Leave",
			function() ix.squad.Act("leave") end, "Stay")
	end)

	local list = content:Add("DScrollPanel")

	list:Dock(FILL)

	for _, entry in ipairs(mine.roster or {}) do
		self:BuildRow(list, entry, mine, myRank)
	end
end

function PANEL:Rebuild()
	self.content:Clear()

	local mine = ix.squad.mine

	if (mine) then
		self:BuildSquad(mine)
	else
		self:BuildEmpty()
	end
end

hook.Add("SquadUpdated", "ixSquadWindow", function()
	if (IsValid(ix.gui.squad)) then ix.gui.squad:Rebuild() end
end)

vgui.Register("ixFOSquad", PANEL, "ixFOFrame")

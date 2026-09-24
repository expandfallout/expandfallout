--[[
	One ticket, as a card in the corner.

	Phoenix's shape, and the admin-popup addon's before that: who, what they
	said, and a column of buttons that does the four things staff do next.

	THE BUTTONS RUN THIS SCHEMA'S OWN COMMANDS. The addon this is modelled on
	shells out to `ulx goto`; going through `ix.command.Send` means a click
	obeys the same rank overrides, the same immunity check and the same audit
	log as typing it, and there is still exactly one place where "may I
	teleport to this person" is decided.

	YOU HAVE TO ASK FOR THE MOUSE, and that is not a bug in this file.

	Garry's Mod only gives a panel mouse input while the cursor is visible, and
	the cursor is only visible for a POPUP - which takes the mouse away from the
	game for as long as it exists. A ticket card that did that would stop you
	playing until you closed it. So the cards are drawn without one and they
	become clickable when you ask:

	    ix_tickets        toggle the cursor on and off - bind a key to it
	    ix_ticket_claim   claim the oldest one without a cursor at all
	    !ticketclose <n>  the same for closing

	The addon this came from shipped `adminpopups_claimtop` for exactly this
	reason and never explained why. The cards are also clickable for free
	whenever the cursor is already up for something else - the inventory, the
	scoreboard, any menu.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

local UNCLAIMED = Color(255, 150, 0)
local MINE = Color(60, 170, 100)
local THEIRS = Color(200, 60, 50)

--------------------------------------------------------------------------------
-- Building it
--------------------------------------------------------------------------------

--[[
	SMALL ENOUGH TO IGNORE, big enough to read.

	The first version was 400x176 at 1080p and took a fifth of the screen with
	four of them up. A ticket card is glanced at, not studied - the name, the
	line, and whether anybody has it - and everything on it is one font size
	down from a window because a window is a thing you opened on purpose.
]]
function PANEL:Init()
	self:SetSize(Scaled(290), Scaled(122))
	self:SetMouseInputEnabled(true)

	self.head = self:Add("Panel")
	self.head:Dock(TOP)
	self.head:SetTall(Scaled(32))

	self.title = self.head:Add("ixFOLabel")
	self.title:Dock(TOP)
	self.title:SetTall(Scaled(18))
	self.title:DockMargin(Scaled(5), Scaled(2), Scaled(18), 0)
	self.title:SetFont("ixLootRow")
	self.title:SetTextColor(color_white)

	self.subtitle = self.head:Add("ixFOLabel")
	self.subtitle:Dock(TOP)
	self.subtitle:SetTall(Scaled(12))
	self.subtitle:DockMargin(Scaled(5), 0, Scaled(5), 0)
	self.subtitle:SetFont("ixLootBadge")
	self.subtitle:SetTextColor(Color(200, 200, 190))

	--[[
		DISMISSING IS NOT CLOSING. This takes the card off one screen and
		leaves the ticket open for everybody else - somebody has to be able to
		clear their corner without answering for the whole team, and `!tickets`
		brings them all back.
	]]
	local dismiss = self:Add("ixFOButton")

	dismiss:SetSize(Scaled(14), Scaled(14))
	dismiss:SetPos(self:GetWide() - Scaled(16), Scaled(2))
	dismiss:SetText("x")
	dismiss:SetFont("ixLootBadge")
	dismiss:SetContentAlignment(5)
	dismiss:SetTooltip("Hide this one. It stays open for everybody else.")
	dismiss.DoClick = function()
		ix.ticket.Remove(self.ticket and self.ticket.id or 0)
	end

	----------------------------------------------------------------- body ---

	self.body = self:Add("Panel")
	self.body:Dock(FILL)
	self.body:DockMargin(Scaled(5), 0, Scaled(5), Scaled(5))

	self.buttons = self.body:Add("Panel")
	self.buttons:Dock(RIGHT)
	self.buttons:SetWide(Scaled(90))

	self.scroll = self.body:Add("ixFOScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(0, 0, Scaled(5), 0)

	self.text = self.scroll:Add("ixFOLabel")
	self.text:Dock(TOP)
	self.text:SetFont("ixLootSmall")
	self.text:SetTextColor(color_white)
	self.text:SetWrap(true)
	self.text:SetAutoStretchVertical(true)
end

--[[
	The header carries the claim, in colour.

	Green is mine, red is somebody else's, orange is nobody's - which is the
	one piece of information a staff member needs before deciding whether to
	read the rest, and the addon this came from used the same three.
]]
function PANEL:Paint(width, height)
	local palette = ix.fallout.GetPalette()
	local ticket = self.ticket

	surface.SetDrawColor(0, 0, 0, 225)
	surface.DrawRect(0, 0, width, height)

	local bar = UNCLAIMED

	if (ticket and ticket.claimer ~= "") then
		bar = ticket.claimer == LocalPlayer():SteamID64() and MINE or THEIRS
	end

	surface.SetDrawColor(bar)
	surface.DrawRect(0, 0, width, Scaled(2))

	surface.SetDrawColor(palette.color_primary)
	surface.DrawOutlinedRect(0, 0, width, height, 1)
end

--------------------------------------------------------------------------------
-- The buttons
--------------------------------------------------------------------------------

--[[
	Every button is the same four lines, so they are written once.

	`Send` names a command and its arguments; the target is always the
	reporter's SteamID, because `ix.util.FindPlayer` reads `STEAM_0:` directly
	and a character NAME would find the wrong person the moment two people are
	called Doc.
]]
function PANEL:AddButton(text, tooltip, callback)
	local button = self.buttons:Add("ixFOButton")

	button:Dock(TOP)
	button:SetTall(Scaled(13))
	button:DockMargin(0, 0, 0, Scaled(1))
	button:SetText(text)
	button:SetFont("ixLootBadge")
	button:SetContentAlignment(5)
	button:SetTooltip(tooltip)
	button.DoClick = callback

	return button
end

function PANEL:BuildButtons()
	self.buttons:Clear()

	local ticket = self.ticket
	local steamID = ticket.steamID

	self:AddButton("GOTO", "Teleport to them.", function()
		ix.command.Send("plygoto", steamID)
	end)

	self:AddButton("BRING", "Teleport them to you.", function()
		ix.command.Send("plybring", steamID)
	end)

	self:AddButton("RETURN", "Send them back where they were.", function()
		ix.command.Send("return", steamID)
	end)

	--[[
		FREEZE TOGGLES, because unfreezing is the half people forget. The
		button remembers what it did rather than asking the server, which would
		mean a round trip for a label.
	]]
	local frozen = false
	local freeze

	freeze = self:AddButton("FREEZE", "Freeze them where they stand.",
		function()
			ix.command.Send(frozen and "unfreeze" or "freeze", steamID)

			frozen = not frozen

			freeze:SetText(frozen and "UNFREEZE" or "FREEZE")
		end)

	--[[
		REPLY OPENS A REAL POPUP, which is the only kind of panel you can type
		into - see the note at the top of this file. It also means the answer
		can be written without walking anywhere, which is most of them.
	]]
	self:AddButton("REPLY", "Answer them without going there.", function()
		Derma_StringRequest("REPLY TO " .. string.upper(ticket.name),
			table.concat(ticket.lines or {}, "\n"), "",
			function(answer)
				answer = string.Trim(answer or "")

				if (answer == "") then return end

				net.Start("ixTicketReply")
					net.WriteUInt(ticket.id, 16)
					net.WriteString(answer)
				net.SendToServer()
			end, function() end, "SEND", "CANCEL")
	end)

	--- One button for the two ends of a ticket's life, because it is one job.
	if (ticket.claimer == "") then
		self:AddButton("CLAIM", "Take this one. Nobody else can then.",
			function()
				net.Start("ixTicketAct")
					net.WriteUInt(ticket.id, 16)
					net.WriteString("claim")
				net.SendToServer()
			end)
	else
		self:AddButton("CLOSE", "Mark this one dealt with.", function()
			net.Start("ixTicketAct")
				net.WriteUInt(ticket.id, 16)
				net.WriteString("close")
			net.SendToServer()
		end)
	end
end

--------------------------------------------------------------------------------
-- Filling it in
--------------------------------------------------------------------------------

--[[
	Called again every time the ticket changes, so a second line from the
	reporter appears on the card that is already there rather than as a second
	card. `cl_ticket.lua` decides which of those it is.
]]
function PANEL:Setup(ticket)
	self.ticket = ticket

	self.title:SetText(string.format("#%d  %s", ticket.id, ticket.name))

	local claim = ticket.claimer ~= ""
		and ("claimed by " .. ticket.claimerName) or "unclaimed"

	self.subtitle:SetText(string.format("%s  -  %s", ticket.character, claim))

	--[[
		EVERY LINE THEY HAVE SAID, oldest first and numbered by nothing. A
		ticket that grows is a person adding detail, and showing only the
		newest would throw away the sentence the detail was attached to.
	]]
	self.text:SetText(table.concat(ticket.lines or {}, "\n"))
	self.text:SizeToContentsY()

	self:BuildButtons()
end

vgui.Register("ixFOTicket", PANEL, "Panel")

--------------------------------------------------------------------------------
-- Reaching them without a cursor
--------------------------------------------------------------------------------

--[[
	The cursor, on and off.

	`gui.EnableScreenClicker` is the one way to make a panel that is NOT a
	popup clickable, which is the whole trick that lets these cards sit on
	screen without taking the game away. Bind a key to it.
]]
concommand.Add("ix_tickets", function()
	ix.ticket.cursor = not ix.ticket.cursor

	gui.EnableScreenClicker(ix.ticket.cursor)
end)

--[[
	Claim the oldest without any of that.

	Directly equivalent to the `adminpopups_claimtop` the reference addon
	shipped: one key, and the ticket at the top of the column is yours.
]]
concommand.Add("ix_ticket_claim", function()
	local panels = ix.ticket.Ordered()

	for _, panel in ipairs(panels) do
		if (panel.ticket and panel.ticket.claimer == "") then
			net.Start("ixTicketAct")
				net.WriteUInt(panel.ticket.id, 16)
				net.WriteString("claim")
			net.SendToServer()

			return
		end
	end

	chat.AddText(UNCLAIMED, "[TICKET] ", color_white,
		"Nothing unclaimed to take.")
end)

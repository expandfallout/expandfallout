--[[
	Tickets, client side: the stack in the corner.

	`ix.ticket` IS DECLARED HERE TOO, and the colours are literals rather than
	reads of `ix.ticket.chatColour`. `libs/` is included alphabetically and
	`file.Find` puts every `cl_` file before every `sh_` one, so this runs
	BEFORE `sh_ticket.lua` - see gotcha 26. Anything this file reads from that
	one at FILE SCOPE is nil; anything it reads inside a function is fine,
	because the functions run long afterwards.

	THE STACK IS TOP LEFT because the conflict panel is top right. Two systems
	that both want a corner is a solvable problem exactly once.
]]

if (not CLIENT) then return end

ix.ticket = ix.ticket or {}

--- `[id] = panel`, so a ticket that gains a line updates rather than stacks.
ix.ticket.panels = ix.ticket.panels or {}

local COLOUR = Color(255, 150, 0)
local ANSWER = Color(90, 210, 130)

--[[
	POPUPS ARE A CHOICE, per person, and the alternative is not silence.

	A staff member who is playing rather than moderating still wants to know a
	ticket came in; what they do not want is a panel over their inventory. 0
	puts the same information in chat and nothing on the screen.
]]
CreateClientConVar("ix_ticket_popups", "1", true, false,
	"Show ticket popups. 0 puts them in chat instead.", 0, 1)

--------------------------------------------------------------------------------
-- The stack
--------------------------------------------------------------------------------

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

--[[
	Put them back in a column after one is removed.

	Rebuilt from the list rather than moved by an offset: a panel that animates
	to "where it was minus one" is a panel that ends up in the wrong place the
	moment two are closed in the same frame.
]]
function ix.ticket.Layout()
	local y = Scaled(16)

	for _, panel in ipairs(ix.ticket.Ordered()) do
		panel:MoveTo(Scaled(16), y, 0.15, 0, 1)

		y = y + panel:GetTall() + Scaled(6)
	end
end

--- Oldest at the top, which is the order they should be answered in.
function ix.ticket.Ordered()
	local out = {}

	for _, panel in pairs(ix.ticket.panels) do
		if (IsValid(panel)) then out[#out + 1] = panel end
	end

	table.sort(out, function(a, b)
		return (a.ticket and a.ticket.id or 0) < (b.ticket and b.ticket.id or 0)
	end)

	return out
end

function ix.ticket.Remove(id)
	local panel = ix.ticket.panels[id]

	ix.ticket.panels[id] = nil

	if (IsValid(panel)) then panel:Remove() end

	ix.ticket.Layout()

	--[[
		AND THE CURSOR GOES BACK when the last card does.

		`ix_tickets` turns on the screen clicker so the cards can be clicked
		(see `derma/cl_ticket.lua` for why that is necessary at all), and
		somebody who claims the only ticket and then walks away would be left
		unable to turn their head with nothing on screen explaining it. The
		toggle is only released if WE turned it on.
	]]
	if (ix.ticket.cursor and not next(ix.ticket.panels)) then
		ix.ticket.cursor = false

		gui.EnableScreenClicker(false)
	end
end

--------------------------------------------------------------------------------
-- What the server says
--------------------------------------------------------------------------------

net.Receive("ixTicketOpen", function()
	local ticket = net.ReadTable()

	if (not ticket or not ticket.id) then return end

	--[[
		CHAT INSTEAD, for anybody who turned the panels off - and the whole
		ticket, not a "you have a ticket" that they then cannot read.
	]]
	if (not GetConVar("ix_ticket_popups"):GetBool()) then
		chat.AddText(COLOUR, string.format("[TICKET #%d] %s: ", ticket.id,
			ticket.name), color_white,
			table.concat(ticket.lines or {}, " / "))

		return
	end

	local panel = ix.ticket.panels[ticket.id]

	if (IsValid(panel)) then
		panel:Setup(ticket)

		return
	end

	panel = vgui.Create("ixFOTicket")

	if (not IsValid(panel)) then return end

	panel:Setup(ticket)

	ix.ticket.panels[ticket.id] = panel

	--[[
		OFF THE LEFT EDGE, then slid in. The movement is what makes a new
		ticket noticeable without a sound loud enough to be turned off, and it
		is the same entrance Phoenix's popups make.
	]]
	panel:SetPos(-panel:GetWide(), Scaled(16))

	ix.ticket.Layout()

	surface.PlaySound("phoenix/ui/nv/ui_popup_messagewindow.mp3")
end)

net.Receive("ixTicketClose", function()
	ix.ticket.Remove(net.ReadUInt(16))
end)

--[[
	A line of chat about a ticket. `bAnswer` is set when it is addressed to the
	person reading it rather than being staff talking about somebody.
]]
net.Receive("ixTicketSaid", function()
	local text = net.ReadString()
	local bAnswer = net.ReadBool()

	chat.AddText(bAnswer and ANSWER or COLOUR, "[TICKET] ", color_white, text)

	if (bAnswer) then
		surface.PlaySound("phoenix/ui/nv/ui_popup_messagewindow.mp3")
	end
end)

net.Receive("ixTicketStats", function()
	local stats = net.ReadTable()

	if (IsValid(ix.gui.ticketStats)) then ix.gui.ticketStats:Remove() end

	local panel = vgui.Create("ixFOTicketStats")

	if (IsValid(panel)) then panel:Setup(stats) end
end)

--[[
	Admin chat, and the tickets that come out of it.

	Two things that are really one thing, which is why they share a file. A
	player types `@` and it becomes a ticket; a staff member types `@` and it
	becomes admin chat. Both are "say something to the people running the
	server", and the difference is only whether you are one of them.

	    !a  /asay  @<text>       staff talking to staff
	    !report  !help  /report  a player asking for one

	WHY `@` FORKS RATHER THAN BEING TWO KEYS. Every admin mod in this game
	binds `@` to admin chat and every player who has run one types `@` when
	they want help. Two systems on one key is the behaviour SAM ships and
	everybody already expects; the alternative is a player typing `@help me`
	into a channel they cannot see the answers in.

	THE POPUP IS PHOENIX'S SHAPE, and the buttons on it are this schema's own
	commands - `!goto`, `!bring`, `!return`, `!freeze` - rather than a second
	set of teleports. The addon this was modelled on shells out to `ulx goto`;
	going through `ix.command.Send` means the rank overrides, the immunity
	check and the audit log all still apply to a button, which is the whole
	reason not to reimplement them.

	CLAIMING IS THE POINT OF THE WHOLE SYSTEM. Three staff answering the same
	ticket while four others go untouched is the failure a ticket queue exists
	to prevent, so a claim is exclusive, it is announced to everybody who can
	see tickets, and it is what `/ticketstats` counts.
]]

ix.ticket = ix.ticket or {}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("ticketsEnabled", true,
	"Whether players may open tickets with /report.", nil,
	{category = "Tickets"})

--[[
	HOW LONG AN UNANSWERED TICKET LIVES.

	Not zero and not for ever. A ticket nobody claimed in ten minutes is one
	whose reporter has either sorted it out or logged off, and leaving it on
	four screens for the rest of the evening trains people to ignore the
	corner of the screen tickets appear in. Claiming one restarts the clock -
	see `sv_ticket.lua` - because a claimed ticket is somebody's job now.
]]
ix.config.Add("ticketTimeout", 600,
	"Seconds before an unanswered ticket closes itself.", nil, {
	data = {min = 30, max = 7200}, category = "Tickets"})

ix.config.Add("ticketCooldown", 30,
	"Seconds a player must wait between opening tickets.", nil, {
	data = {min = 0, max = 600}, category = "Tickets"})

ix.config.Add("ticketMaxLength", 200,
	"The longest a single ticket line may be, in characters.", nil, {
	data = {min = 32, max = 512}, category = "Tickets"})

--[[
	How many times somebody may add to their own open ticket.

	An open ticket accepts more lines rather than making a second one - that is
	how a report becomes a conversation instead of four separate popups - but
	somebody hammering `@` is then writing directly onto a staff member's
	screen, so it stops after this many.
]]
ix.config.Add("ticketMaxLines", 6,
	"How many lines one open ticket may hold.", nil, {
	data = {min = 1, max = 20}, category = "Tickets"})

--------------------------------------------------------------------------------
-- Who may do what
--------------------------------------------------------------------------------

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("admin.chat",
		"See and use admin chat", "Staff")
	ix.admin.RegisterPermission("ticket.claim",
		"See, claim and close tickets", "Staff")
	ix.admin.RegisterPermission("ticket.stats",
		"See who has been answering tickets", "Staff")
end

--- Everybody who should be shown a ticket, as a list.
function ix.ticket.Staff()
	local out = {}

	for _, client in player.Iterator() do
		if (client:GetCharacter() and ix.admin.Can(client, "ticket.claim")) then
			out[#out + 1] = client
		end
	end

	return out
end

--------------------------------------------------------------------------------
-- Admin chat
--------------------------------------------------------------------------------

--- Green, and nothing else in this schema's chat is.
ix.ticket.chatColour = Color(90, 210, 130)
ix.ticket.ticketColour = Color(255, 150, 0)

--[[
	Admin chat as a CHAT CLASS, not as a net message.

	`CanHear` is asked once per listener on the server, which is exactly the
	permission test - so the message reaches staff and does not exist for
	anybody else, rather than being sent to everybody and hidden by the client.
	A hidden message is a message somebody can read.

	No prefix, deliberately. The prefix would register `/adminchat` as a chat
	command with no access check on it at all (`OnCheckAccess` on a chat-class
	command is hardcoded to return true in `ix.chat.Register`); `/asay` below
	is a real command with a real check.
]]
ix.chat.Register("adminchat", {
	deadCanChat = true,

	CanHear = function(self, speaker, listener)
		return ix.admin.Can(listener, "admin.chat")
	end,

	CanSay = function(self, speaker, text)
		return ix.admin.Can(speaker, "admin.chat")
	end,

	OnChatAdd = function(self, speaker, text)
		chat.AddText(ix.ticket.chatColour, "[ADMIN] ",
			IsValid(speaker) and speaker:SteamName() or "Console",
			": " .. text)
	end
})

--[[
	WHAT STAFF DID, IN STAFF CHAT.

	A moderation command that only the target and the log know about is a
	command the rest of the team finds out about from the target. `!bring bob`
	now says "Alice brought Bob" to everybody who can see admin chat, and
	`~bring bob` says nothing to anybody - which is the whole difference
	between the two prefixes, and the reason the silent one is worth having.

	A CLASS OF ITS OWN rather than `adminchat`, because these are not somebody
	talking: the tag is `[STAFF]` and there is no name in front of the colon,
	so a line the server generated cannot be mistaken for a line somebody typed.
]]
ix.chat.Register("adminaction", {
	deadCanChat = true,

	CanHear = function(self, speaker, listener)
		return ix.admin.Can(listener, "admin.chat")
	end,

	OnChatAdd = function(self, speaker, text)
		chat.AddText(ix.ticket.chatColour, "[STAFF] ", color_white, text)
	end
})

--[[
	Say it, unless this command was run with `~`.

	Lives here rather than in `sh_adminverbs.lua` because this is where the
	staff channel is; the verbs call it and do not need to know how it reaches
	anybody. Silence is checked in ONE place - `ix.admin.IsSilent` - so a
	command cannot be quiet for the target and loud for the team by accident.
]]
function ix.admin.Announce(client, text)
	--[[
		SERVER ONLY. `ix.chat.Send` is two different functions with two
		different signatures - the server's takes receivers, the client's takes
		data and RENDERS - and calling the client's from a command body would
		print the line locally to whoever ran it and nowhere else.
	]]
	if (not SERVER) then return end

	if (ix.admin.IsSilent and ix.admin.IsSilent(client)) then return end

	ix.chat.Send(client, "adminaction", text)
end

ix.command.Add("ASay", {
	description = "Say something only staff can see.",
	alias = {"A", "AdminChat"},
	arguments = {ix.type.text},
	bNoIndicator = true,

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "admin.chat")
	end,

	OnRun = function(self, client, text)
		text = string.Trim(text or "")

		if (text == "") then return "Say something." end

		ix.chat.Send(client, "adminchat", text)
	end
})

--------------------------------------------------------------------------------
-- Reporting
--------------------------------------------------------------------------------

ix.command.Add("Report", {
	description = "Ask staff for help. They will see it and answer.",

	--[[
		THE NAMES PEOPLE ACTUALLY TYPE. A player who wants help types `!help`
		before they type anything else, and a command that only exists under
		one of its obvious names is a command nobody finds.

		NOT `Admin`, which is taken - `sh_commands.lua` opens the admin menu
		with it. Helix registers an alias by writing it into `ix.command.list`,
		so a second claim on a name silently replaces the first and the menu
		would have stopped opening with no error anywhere.
	]]
	alias = {"Help", "Ticket"},
	arguments = {ix.type.text},
	bNoIndicator = true,

	OnRun = function(self, client, text)
		--- Server side: `sv_ticket.lua` owns the queue and the cooldowns.
		if (CLIENT) then return end

		return ix.ticket.Open(client, text)
	end
})

--------------------------------------------------------------------------------
-- The `@` key
--------------------------------------------------------------------------------

if (SERVER) then
	--[[
		`@something` forks on who is typing it.

		THIS RETURNS AND THAT IS DELIBERATE - see gotcha 27. A `PlayerSay`
		listener that returns a value replaces the whole of `GM:PlayerSay`, so
		nothing else parses the line and the engine does not say it out loud.
		That is the correct outcome here and it is the same thing
		`ixAdminPrefix` does for `!`, four files up the alphabet.

		`@@` is left alone, the way `!!` is: somebody typing "@@@" is not
		running a command.
	]]
	hook.Add("PlayerSay", "ixTicketPrefix", function(client, text)
		if (string.sub(text, 1, 1) ~= "@") then return end

		local rest = string.Trim(string.sub(text, 2))

		if (rest == "" or string.sub(rest, 1, 1) == "@") then return end

		if (ix.admin.Can(client, "admin.chat")) then
			ix.chat.Send(client, "adminchat", rest)
		else
			local reason = ix.ticket.Open(client, rest)

			if (isstring(reason)) then client:Notify(reason) end
		end

		return ""
	end)
end

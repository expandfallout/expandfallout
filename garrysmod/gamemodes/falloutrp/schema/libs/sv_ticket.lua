--[[
	The ticket queue, server side.

	ONE OPEN TICKET PER PLAYER, keyed by their SteamID64. That is the whole
	data structure and it is the reason the rest is short: a second `@` from
	the same person is another LINE on the ticket they already have rather than
	a second popup, so a panicking player cannot bury the queue, and staff read
	one growing card instead of six identical ones.

	A ticket is closed when it is answered, when the reporter leaves, or when
	`ticketTimeout` runs out - and it is `os.time` throughout rather than
	`CurTime`, because "claimed four minutes after it was opened" is a statistic
	that has to survive a map change.
]]

if (not SERVER) then return end

util.AddNetworkString("ixTicketOpen")
util.AddNetworkString("ixTicketClose")
util.AddNetworkString("ixTicketClaim")
util.AddNetworkString("ixTicketAct")
util.AddNetworkString("ixTicketReply")
util.AddNetworkString("ixTicketSaid")
util.AddNetworkString("ixTicketStats")

--- `[steamID64] = ticket`. Memory only: a ticket does not outlive the round.
ix.ticket.open = ix.ticket.open or {}

--- `[steamID64] = {name, claims, closes, respond, last}`. Saved.
ix.ticket.stats = ix.ticket.stats or {}

local nextID = 0

--------------------------------------------------------------------------------
-- Who has been answering them
--------------------------------------------------------------------------------

local STATS_KEY = "ticketstats"
local loaded = false

function ix.ticket.SaveStats()
	if (not loaded) then return end

	ix.data.Set(STATS_KEY, ix.ticket.stats, false, true)
end

--[[
	Loaded the way every other persistent table in this schema is - from
	`LoadData`, again from `PostLoadData`, and once on a timer for a reload
	that fires neither. `sv_hitgroup.lua` carries the same three lines and the
	same reason: `InitPostEntity` never fires in the schema.
]]
function ix.ticket.LoadStats()
	if (loaded) then return end

	ix.ticket.stats = ix.data.Get(STATS_KEY, {}, false, true) or {}
	loaded = true
end

hook.Add("LoadData", "ixTicket", ix.ticket.LoadStats)
hook.Add("PostLoadData", "ixTicket", ix.ticket.LoadStats)
timer.Simple(10, ix.ticket.LoadStats)

--[[
	Record something an admin did.

	`respond` is the TOTAL of every wait, not an average, because an average
	cannot be added to. Dividing happens once, in the window that shows it.
]]
local function Record(admin, field, seconds)
	local key = admin:SteamID64()
	local row = ix.ticket.stats[key] or {claims = 0, closes = 0, respond = 0}

	row.name = admin:SteamName()
	row[field] = (row[field] or 0) + 1
	row.last = os.time()

	if (seconds) then
		row.respond = (row.respond or 0) + math.max(seconds, 0)
	end

	ix.ticket.stats[key] = row

	ix.ticket.SaveStats()
end

--------------------------------------------------------------------------------
-- Telling people
--------------------------------------------------------------------------------

--[[
	The ticket as the client sees it.

	The reporter goes over as an ENTITY INDEX as well as a SteamID64: the
	buttons want a player to act on and the header wants a name that is still
	right after they disconnect, and those are two different needs.
]]
local function Payload(ticket)
	return {
		id = ticket.id,
		index = IsValid(ticket.client) and ticket.client:EntIndex() or 0,
		steamID = ticket.steamID,
		steamID64 = ticket.steamID64,
		name = ticket.name,
		character = ticket.character,
		lines = ticket.lines,
		opened = ticket.opened,
		claimer = ticket.claimer,
		claimerName = ticket.claimerName
	}
end

local function Broadcast(ticket)
	local receivers = ix.ticket.Staff()

	if (#receivers == 0) then return end

	net.Start("ixTicketOpen")
		net.WriteTable(Payload(ticket))
	net.Send(receivers)
end

--- A line in everybody's chat, staff only. Used for claims and closes.
local function Announce(text)
	local receivers = ix.ticket.Staff()

	if (#receivers == 0) then return end

	net.Start("ixTicketSaid")
		net.WriteString(text)
		net.WriteBool(false)
	net.Send(receivers)
end

--------------------------------------------------------------------------------
-- Opening one
--------------------------------------------------------------------------------

--[[
	Returns a string when it refuses, and nothing when it works - which is what
	a Helix command's `OnRun` wants back, so `/report` is one line.
]]
function ix.ticket.Open(client, text)
	if (not ix.config.Get("ticketsEnabled", true)) then
		return "Tickets are disabled on this server."
	end

	text = string.Trim(text or "")

	if (text == "") then return "Say what you need help with." end

	local limit = ix.config.Get("ticketMaxLength", 200)

	if ((utf8.len(text) or #text) > limit) then
		text = string.sub(text, 1, limit)
	end

	local key = client:SteamID64()
	local ticket = ix.ticket.open[key]

	------------------------------------------------------- one they have ---

	if (ticket) then
		if (#ticket.lines >= ix.config.Get("ticketMaxLines", 6)) then
			return "Your ticket already says enough. Wait for an answer."
		end

		ticket.lines[#ticket.lines + 1] = text

		Broadcast(ticket)

		client:Notify("Added to your ticket.")

		return
	end

	--------------------------------------------------------- a new one ---

	--[[
		THE COOLDOWN IS ON OPENING, not on adding.

		Somebody with an open ticket can always say more - that is a
		conversation. Somebody who closed one and immediately opened another is
		what the delay is for, and the two cases look identical if the check
		sits at the top of this function.
	]]
	local delay = ix.config.Get("ticketCooldown", 30)

	if (delay > 0 and client.ixLastTicket) then
		local since = os.time() - client.ixLastTicket

		if (since < delay) then
			return string.format("Wait %d more second(s).",
				math.ceil(delay - since))
		end
	end

	local staff = ix.ticket.Staff()

	nextID = nextID + 1

	local character = client:GetCharacter()

	ticket = {
		id = nextID,
		client = client,
		steamID = client:SteamID(),
		steamID64 = key,
		name = client:SteamName(),
		character = character and character:GetName() or "no character",
		lines = {text},
		opened = os.time(),
		claimer = "",
		claimerName = ""
	}

	ix.ticket.open[key] = ticket
	client.ixLastTicket = os.time()

	Broadcast(ticket)

	ix.log.Add(client, "ticketOpen", text)

	--[[
		TIMED OUT RATHER THAN LEFT OPEN. See `ticketTimeout` for why - and the
		timer is named after the ticket so claiming it can restart the clock
		without knowing whether one was already running.
	]]
	timer.Create("ixTicket" .. ticket.id, ix.config.Get("ticketTimeout", 600),
		1, function()
		ix.ticket.Close(nil, ticket.id, "nobody answered it")
	end)

	--[[
		AND THE REPORTER IS TOLD WHETHER ANYBODY IS LISTENING.

		"Staff have been told" when there are no staff online is the single
		most annoying thing a ticket system can say, because the player then
		waits. The count is not a promise, but it is the truth.
	]]
	if (#staff == 0) then
		client:Notify("Your ticket is open, but no staff are online. It will "
			.. "wait.")
	else
		client:Notify(string.format("Your ticket is open. %d staff can see "
			.. "it.", #staff))
	end
end

--------------------------------------------------------------------------------
-- Claiming and closing
--------------------------------------------------------------------------------

local function Find(id)
	for _, ticket in pairs(ix.ticket.open) do
		if (ticket.id == id) then return ticket end
	end
end

function ix.ticket.Claim(admin, id)
	local ticket = Find(id)

	if (not ticket) then return end

	--[[
		A CLAIM IS EXCLUSIVE AND IT IS FIRST COME. Two staff walking into the
		same report is the thing this whole system exists to stop, so the
		second one is told who got there rather than being allowed to take it
		off them.
	]]
	if (ticket.claimer ~= "") then
		admin:Notify(ticket.claimerName .. " already has that one.")

		return
	end

	ticket.claimer = admin:SteamID64()
	ticket.claimerName = admin:SteamName()

	Record(admin, "claims", os.time() - ticket.opened)

	Broadcast(ticket)

	Announce(string.format("%s claimed %s's ticket.", admin:SteamName(),
		ticket.name))

	if (IsValid(ticket.client)) then
		net.Start("ixTicketSaid")
			net.WriteString(admin:SteamName() .. " is dealing with your "
				.. "ticket.")
			net.WriteBool(true)
		net.Send(ticket.client)
	end

	--- Claimed is not answered. The clock restarts; it does not stop.
	timer.Adjust("ixTicket" .. ticket.id,
		ix.config.Get("ticketTimeout", 600), 1)

	ix.log.Add(admin, "ticketClaim", ticket.name)
end

--[[
	`reason` is a string when nobody closed it on purpose - a timeout, or the
	reporter leaving. `admin` is nil in exactly those cases.
]]
function ix.ticket.Close(admin, id, reason)
	local ticket = Find(id)

	if (not ticket) then return end

	--[[
		A CLAIMED TICKET IS CLOSED BY WHOEVER CLAIMED IT.

		Not because the others are not trusted, but because closing somebody
		else's is how a ticket gets marked dealt with while the person dealing
		with it is still stood in front of the reporter. An UNCLAIMED one may
		be closed by anybody who can see it - that is the "this is nothing, it
		is handled" case, and there is nobody to interrupt.

		A superadmin is the exception, for the ticket claimed by somebody who
		is online and gone for the evening. There is no immunity comparison
		here on purpose: a claim released when its claimer disconnects (see
		`PlayerDisconnected` below) already covers the common case.
	]]
	if (IsValid(admin) and ticket.claimer ~= ""
	and ticket.claimer ~= admin:SteamID64() and not admin:IsSuperAdmin()) then
		admin:Notify(ticket.claimerName .. " has that one.")

		return
	end

	ix.ticket.open[ticket.steamID64] = nil

	timer.Remove("ixTicket" .. ticket.id)

	net.Start("ixTicketClose")
		net.WriteUInt(ticket.id, 16)
	net.Send(ix.ticket.Staff())

	if (IsValid(admin)) then
		Record(admin, "closes")

		Announce(string.format("%s closed %s's ticket.", admin:SteamName(),
			ticket.name))

		ix.log.Add(admin, "ticketClose", ticket.name)
	else
		Announce(string.format("%s's ticket closed - %s.", ticket.name,
			reason or "no reason given"))
	end

	if (IsValid(ticket.client)) then
		net.Start("ixTicketSaid")
			net.WriteString(IsValid(admin)
				and ("Your ticket was closed by " .. admin:SteamName() .. ".")
				or ("Your ticket closed - " .. (reason or "it expired") .. "."))
			net.WriteBool(true)
		net.Send(ticket.client)
	end
end

--------------------------------------------------------------------------------
-- Answering without walking over
--------------------------------------------------------------------------------

--[[
	A reply goes to the reporter AND to the other staff.

	Half a conversation on one screen is how two people answer the same
	question differently, so everybody who can see the ticket sees what was
	said about it - which is also what makes it worth reading the queue rather
	than claiming blindly.
]]
function ix.ticket.Reply(admin, id, text)
	local ticket = Find(id)

	if (not ticket) then return end

	text = string.Trim(text or "")

	if (text == "") then return end

	if (IsValid(ticket.client)) then
		net.Start("ixTicketSaid")
			net.WriteString(string.format("%s: %s", admin:SteamName(), text))
			net.WriteBool(true)
		net.Send(ticket.client)
	end

	Announce(string.format("%s -> %s: %s", admin:SteamName(), ticket.name,
		text))

	ix.log.Add(admin, "ticketReply", ticket.name, text)
end

--------------------------------------------------------------------------------
-- What the client asks for
--------------------------------------------------------------------------------

net.Receive("ixTicketAct", function(length, client)
	if (not ix.admin.Can(client, "ticket.claim")) then return end

	local id = net.ReadUInt(16)
	local action = net.ReadString()

	if (action == "claim") then
		ix.ticket.Claim(client, id)
	elseif (action == "close") then
		ix.ticket.Close(client, id)
	end
end)

net.Receive("ixTicketReply", function(length, client)
	if (not ix.admin.Can(client, "ticket.claim")) then return end

	local id = net.ReadUInt(16)
	local text = net.ReadString()

	--- The reporter's own limit applies to the answer as well.
	ix.ticket.Reply(client, id,
		string.sub(text, 1, ix.config.Get("ticketMaxLength", 200)))
end)

--------------------------------------------------------------------------------
-- Leaving
--------------------------------------------------------------------------------

hook.Add("PlayerDisconnected", "ixTicket", function(client)
	local ticket = ix.ticket.open[client:SteamID64()]

	if (ticket) then
		ix.ticket.Close(nil, ticket.id, "they disconnected")
	end

	--[[
		AND A CLAIM DIES WITH THE CLAIMER. A ticket held by somebody who has
		left is a ticket nobody else may touch, which is worse than an
		unclaimed one - so it goes back in the queue and everybody is told.
	]]
	local key = client:SteamID64()

	for _, other in pairs(ix.ticket.open) do
		if (other.claimer == key) then
			other.claimer = ""
			other.claimerName = ""

			Broadcast(other)
			Announce(string.format("%s left - %s's ticket is unclaimed again.",
				client:SteamName(), other.name))
		end
	end
end)

--[[
	Somebody who has just been given the permission, or who has just connected,
	gets the queue as it stands. Without this a staff member joining halfway
	through an evening sees an empty corner and a queue of four.
]]
hook.Add("PlayerLoadedCharacter", "ixTicket", function(client)
	timer.Simple(2, function()
		if (not IsValid(client)) then return end
		if (not ix.admin.Can(client, "ticket.claim")) then return end

		for _, ticket in pairs(ix.ticket.open) do
			net.Start("ixTicketOpen")
				net.WriteTable(Payload(ticket))
			net.Send(client)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

--- Everything open, for somebody who closed the popups and wants them back.
ix.command.Add("Tickets", {
	description = "Show every open ticket again.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "ticket.claim")
	end,

	OnRun = function(self, client)
		local count = 0

		for _, ticket in pairs(ix.ticket.open) do
			net.Start("ixTicketOpen")
				net.WriteTable(Payload(ticket))
			net.Send(client)

			count = count + 1
		end

		if (count == 0) then return "Nothing is open." end

		return string.format("%d open.", count)
	end
})

ix.command.Add("TicketClose", {
	description = "Close a ticket by its number.",
	arguments = {ix.type.number},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "ticket.claim")
	end,

	OnRun = function(self, client, id)
		ix.ticket.Close(client, math.floor(id))
	end
})

ix.command.Add("TicketStats", {
	description = "See who has been answering tickets.",
	alias = {"ClaimStats"},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "ticket.stats")
	end,

	OnRun = function(self, client)
		ix.ticket.LoadStats()

		if (not next(ix.ticket.stats)) then
			return "Nobody has claimed a ticket yet."
		end

		net.Start("ixTicketStats")
			net.WriteTable(ix.ticket.stats)
		net.Send(client)
	end
})

--[[
	Wiping them is a separate permission from reading them, because a bad month
	is a thing somebody might want to make disappear.
]]
ix.command.Add("TicketStatsClear", {
	description = "Wipe the ticket statistics.",
	superAdminOnly = true,

	OnRun = function(self, client)
		ix.ticket.stats = {}

		ix.ticket.SaveStats()

		ix.log.Add(client, "ticketWipe")

		return "Cleared."
	end
})

--------------------------------------------------------------------------------
-- The log
--------------------------------------------------------------------------------

ix.log.AddType("ticketOpen", function(client, text)
	return string.format("%s opened a ticket: %s", client:Name(), text)
end)

ix.log.AddType("ticketClaim", function(client, who)
	return string.format("%s claimed %s's ticket.", client:Name(), who)
end)

ix.log.AddType("ticketClose", function(client, who)
	return string.format("%s closed %s's ticket.", client:Name(), who)
end)

ix.log.AddType("ticketReply", function(client, who, text)
	return string.format("%s answered %s: %s", client:Name(), who, text)
end)

ix.log.AddType("ticketWipe", function(client)
	return string.format("%s wiped the ticket statistics.", client:Name())
end, FLAG_WARNING)

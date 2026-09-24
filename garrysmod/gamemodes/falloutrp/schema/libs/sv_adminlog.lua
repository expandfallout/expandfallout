--[[
	The log store: everything that happens, kept and searchable.

	Helix's own logging is a `Msg` to the console and one line appended to a
	text file per day. That is a record you can read and cannot QUESTION - and
	the questions are always the same shape: who gave that rifle away, where
	did forty thousand caps come from, which of these two accounts is feeding
	the other.

	ONE HANDLER CATCHES EVERYTHING. `ix.log.RegisterHandler` is called by the
	framework for every log it writes, with the client, the type and the raw
	arguments - so registering one handler captures Helix's built-in logs, this
	schema's, and anything added later, without a single call site changing.
	That is the whole design: nothing has to remember to log to us.

	    time      os.time, so entries survive a restart in order
	    steamID   the account, which is what a ban is against
	    name      the player at the time, which is what people remember
	    charID    the character, which is what the items belong to
	    type      the log type, which is what a filter is built on
	    category  derived from the type; see `CATEGORIES`
	    message   the human sentence Helix already formatted
	    args      the raw arguments, so a search can match an item id exactly

	KEPT IN MEMORY AND ON DISK. Memory answers the admin menu instantly;
	disk is what survives a restart. The in-memory half is a ring buffer with a
	hard ceiling, because an unbounded table on a server that runs for a month
	is a memory leak with a nice interface.
]]

if (not SERVER) then return end

util.AddNetworkString("ixLogQuery")
util.AddNetworkString("ixLogResult")

ix.adminlog = ix.adminlog or {}

--[[
	REGISTERING A LOG TYPE THAT ALREADY EXISTS REPLACES IT, SILENTLY.

	`ix.log.AddType` is a plain table write, so a second registration of the
	same name wins and the first is gone. That is how six of this schema's
	types quietly took over Helix's own - `charLoad`, `charCreate`,
	`charDelete`, `playerDeath`, and the rest - and then Helix's logging plugin
	called OUR formatter with ITS arguments:

	    ix.log.Add(client, "charLoad", character:GetName())   -- one argument
	    function(client, name, id, steamID) ... "%d" ... id   -- three expected

	which errored on every single character load, from inside
	`character:Setup()`, and left the player on a grey screen.

	Nothing about that was visible at registration time. So registration is
	wrapped: a name that is already taken is REFUSED and shouted about, rather
	than accepted and then discovered from a stack trace weeks later. Refusing
	is right rather than overwriting, because the existing one is the one
	something is already calling.
]]
do
	local original = ix.log.AddType

	if (original and not ix.log.ixGuarded) then
		ix.log.ixGuarded = true

		function ix.log.AddType(logType, format, flag)
			if (ix.log.types[logType]) then
				ErrorNoHalt(string.format("[falloutrp] log type '%s' is "
					.. "already registered - refusing to replace it\n",
					tostring(logType)))

				return
			end

			return original(logType, format, flag)
		end
	end
end

--- How many entries to hold in memory. Older ones live only on disk.
ix.adminlog.limit = 4000

--- Newest last, so `#entries` is the newest and iteration reads forwards.
ix.adminlog.entries = ix.adminlog.entries or {}

--------------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------------

local function Folder()
	return "helix/falloutrp/logs"
end

local function FileName()
	return Folder() .. "/" .. os.date("%Y-%m-%d") .. ".txt"
end

--[[
	One JSON object per line.

	NOT one big JSON array, because a day's file is appended to thousands of
	times and re-encoding the whole thing per entry would be quadratic. A file
	of lines can be appended to for ever and read back a line at a time.
]]
local function Persist(entry)
	file.CreateDir("helix")
	file.CreateDir("helix/falloutrp")
	file.CreateDir(Folder())

	file.Append(FileName(), util.TableToJSON(entry) .. "\n")
end

--[[
	Turn arbitrary log arguments into something storable.

	Entities and players become readable strings rather than being dropped or
	crashing the encoder - an entry naming "Player [1][Bob]" is more use than
	one that failed to save.
]]
local function Clean(arguments)
	local out = {}

	for index, value in ipairs(arguments or {}) do
		if (isentity(value)) then
			out[index] = IsValid(value) and tostring(value) or "NULL"
		elseif (isvector(value) or isangle(value)) then
			out[index] = tostring(value)
		elseif (istable(value)) then
			out[index] = "table"
		else
			out[index] = value
		end
	end

	return out
end

function ix.adminlog.Write(client, message, flag, logType, arguments)
	local character = IsValid(client) and client:GetCharacter()

	--[[
		The FACTION is captured at the moment of the entry, not looked up when
		it is read. Somebody who leaves a faction after doing something should
		still show as having been in it at the time - a log that reported
		today's faction against last week's action would be quietly wrong in
		exactly the case somebody is investigating.
	]]
	local faction = ""

	if (character) then
		local team = ix.faction.indices[character:GetFaction()]

		faction = team and team.name or ""
	end

	local entry = {
		time = os.time(),
		--- The day, so a search can narrow to one without parsing timestamps.
		day = os.date("%Y-%m-%d"),
		steamID = IsValid(client) and client:SteamID() or "",
		name = IsValid(client) and client:Name() or "Console",
		charID = character and character:GetID() or 0,
		charName = character and character:GetName() or "",
		faction = faction,
		type = logType or "raw",
		category = ix.adminlog.Categorise(logType or "raw"),
		flag = flag or FLAG_NORMAL,
		message = message,
		args = Clean(arguments)
	}

	local entries = ix.adminlog.entries

	entries[#entries + 1] = entry

	--[[
		Trimmed from the front when it grows past the ceiling. `table.remove`
		on index 1 is O(n) and this happens once per entry past the limit,
		which at four thousand entries is cheap and simple - and simple matters
		more here than a ring buffer's arithmetic, because a logging system
		that is clever is a logging system that loses entries.
	]]
	while (#entries > ix.adminlog.limit) do
		table.remove(entries, 1)
	end

	Persist(entry)
end

--[[
	Read the recent files back into memory on start.

	LOGS DO NOT DISAPPEAR ON RESTART, which they effectively did: the disk half
	kept every entry, and the SEARCH only ever looked at memory - so the moment
	the server restarted, everything before it became invisible to the admin
	menu even though it was sitting in a file.

	The last few days are loaded, not everything ever. A server that has run
	for a year has a folder nobody wants read into RAM at boot, and "what
	happened this week" is the question the menu is for; older days are still
	on disk in the same format, one JSON object per line, greppable.
]]
function ix.adminlog.Restore(days)
	days = days or 3

	local restored = 0

	for back = days - 1, 0, -1 do
		local name = os.date("%Y-%m-%d", os.time() - back * 86400)
		local contents = file.Read(Folder() .. "/" .. name .. ".txt", "DATA")

		if (not contents) then continue end

		for line in string.gmatch(contents, "[^\r\n]+") do
			local entry = util.JSONToTable(line)

			--[[
				A line that will not parse is skipped rather than stopping the
				load. A half-written entry from a server that was killed
				mid-append is exactly the sort of thing that is in these files,
				and losing three days of history to one bad line would be a
				poor trade.
			]]
			if (istable(entry) and entry.message) then
				ix.adminlog.entries[#ix.adminlog.entries + 1] = entry
				restored = restored + 1
			end
		end
	end

	--- Oldest first, and trimmed to the ceiling from the front.
	while (#ix.adminlog.entries > ix.adminlog.limit) do
		table.remove(ix.adminlog.entries, 1)
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] restored %d log entr%s from disk\n", restored,
		restored == 1 and "y" or "ies"))

	return restored
end

--[[
	Registered as a Helix log handler, which is what makes this catch
	everything without a single call site knowing about it.
]]
ix.log.RegisterHandler("FalloutAdmin", {
	Load = function()
		file.CreateDir("helix")
		file.CreateDir("helix/falloutrp")
		file.CreateDir(Folder())

		ix.adminlog.Restore(3)
	end,

	Write = ix.adminlog.Write
})

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

--[[
	Search the log. Everything is optional and everything narrows.

	Walks BACKWARDS from the newest, so a search that finds its limit finds the
	most recent matches rather than the oldest - which is what somebody asking
	"what just happened" wants, and they are the only person who ever asks.
]]
--[[
	Does one entry match a text search?

	The message AND the raw arguments, so searching an item id finds it even
	when the sentence phrases it differently. That is the difference between
	"find every log mentioning 4471" and "find every log whose English happens
	to contain 4471".

	Pulled out of the loop below so the loop can be a flat list of `continue`s
	rather than needing a `found` flag carried through it.
]]
local function Matches(entry, text)
	if (string.find(string.lower(entry.message or ""), text, 1, true)) then
		return true
	end

	for _, value in pairs(entry.args or {}) do
		if (string.find(string.lower(tostring(value)), text, 1, true)) then
			return true
		end
	end

	return false
end

--[[
	Search the log. Everything is optional and everything narrows.

	Walks BACKWARDS from the newest, so a search that finds its limit finds the
	most recent matches rather than the oldest - which is what somebody asking
	"what just happened" wants, and they are the only person who ever asks.

	`continue` HERE, NOT `goto continue`. GMod's Lua adds `continue` as a real
	keyword, so `::continue::` is a label named after a keyword and the parser
	refuses the file outright:

	    '=' expected near 'continue'

	which takes the whole schema down on load. Plain `continue` is both legal
	and what every other loop in this schema uses.
]]
function ix.adminlog.Search(filter, may)
	filter = filter or {}

	local out = {}
	local entries = ix.adminlog.entries
	local limit = math.Clamp(filter.limit or 200, 1, 500)

	--[[
		PAGES, newest first: page 0 is the newest `limit` matches, page 1
		the `limit` before those. The whole log is thousands of lines and
		one net message cannot carry it, so it is read a page at a time.
	]]
	local skip = math.max(0, math.floor(tonumber(filter.page) or 0)) * limit
	local matched = 0
	local text = filter.text and filter.text ~= ""
		and string.lower(filter.text) or nil

	for index = #entries, 1, -1 do
		local entry = entries[index]

		--[[
			READING THE LOG DOES NOT FILL THE LOG.

			Every search writes an `adminLogRead` entry, which is right for
			accountability and ruinous for reading: eighty searches in a
			testing session buried every other category under "searched the
			everything log for ''". The one action guaranteed to appear in the
			thing you are looking at is the one that must not appear by
			default.

			It is still there, and still searchable - under ADMIN, where
			somebody checking who has been reading logs would go looking.
		]]
		if (entry.type == "adminLogRead" and filter.category ~= "admin") then
			continue
		end

		if (filter.category and filter.category ~= ""
		and entry.category ~= filter.category) then continue end

		if (filter.steamID and filter.steamID ~= ""
		and entry.steamID ~= filter.steamID) then continue end

		if (text and not Matches(entry, text)) then continue end
		if (may and not may(entry)) then continue end

		--- Every match is counted, so the pages know how many there are.
		matched = matched + 1

		if (matched <= skip) then continue end
		if (#out < limit) then out[#out + 1] = entry end
	end

	return out, matched > skip + limit, matched
end

net.Receive("ixLogQuery", function(length, client)
	if (not ix.admin.Can(client, "log.view")) then return end

	local filter = net.ReadTable() or {}

	--[[
		The finer categories are gated separately. A helper may read the chat
		log and see who was where; the economy log is where a moderator would
		see how much money everybody has, and that is a different thing to
		trust somebody with.
	]]
	local gate = {
		economy = "log.economy", items = "log.items", admin = "log.admin",
		chat = "log.chat"
	}

	local needed = gate[filter.category]

	if (needed and not ix.admin.Can(client, needed)) then
		client:Notify("You cannot read that log.")

		return
	end

	--[[
		With no category chosen, the search is narrowed to what they may
		actually see rather than refused - a helper searching everything should
		get the chat results, not an error.
	]]
	--- Gated inside the search, so the pages and the total count only what they may see.
	local results, more, total = ix.adminlog.Search(filter, function(entry)
		local permission = gate[entry.category]

		return not permission or ix.admin.Can(client, permission)
	end)

	net.Start("ixLogResult")
		net.WriteUInt(#results, 16)

		for _, entry in ipairs(results) do
			net.WriteUInt(entry.time, 32)
			net.WriteString(entry.name)
			net.WriteString(entry.steamID)
			net.WriteString(entry.faction or "")
			net.WriteString(entry.category)
			net.WriteString(entry.type)
			net.WriteUInt(entry.flag or 0, 4)
			net.WriteString(string.sub(entry.message or "", 1, 250))
		end

		--- Which page this was, whether an older one exists, and how many there are in all.
		net.WriteBool(more == true)
		net.WriteUInt(math.Clamp(math.floor(tonumber(filter.page) or 0), 0, 65535), 16)
		net.WriteUInt(math.min(total or 0, 4294967295), 32)
		net.WriteUInt(math.Clamp(filter.limit or 200, 1, 500), 16)
	net.Send(client)

	ix.log.Add(client, "adminLogRead", filter.category or "everything",
		filter.text or "", #results)
end)

ix.log.AddType("adminLogRead", function(client, category, text, count)
	return string.format("%s searched the %s log for '%s' - %d result(s).",
		client:Name(), category, text, count)
end, FLAG_DEV)

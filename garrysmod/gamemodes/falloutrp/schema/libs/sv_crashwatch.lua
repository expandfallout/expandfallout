--[[
	A black box, for when the server stops without saying anything.

	A silent crash leaves nothing: no Lua error, no stack, and `-condebug` ends
	mid-sentence because the process was gone before the next line was written.
	Nothing in Lua can catch that - by the time the engine dies there is no
	interpreter left to run a handler in.

	WHAT LUA CAN DO IS LEAVE A TRAIL AHEAD OF TIME. Every few seconds this
	writes what the server is doing to a file, and on the next boot it looks at
	the one the previous session left. If that file does not end with a clean
	shutdown marker, the previous session died where the file stops - so the
	file IS the last known state, and it is kept.

	    data/falloutrp_crashwatch.txt        the live one, overwritten
	    data/falloutrp_crash_<when>.txt      a copy, kept, one per crash

	WHAT IT WATCHES, and why each one:

	    edicts        running out is the commonest silent GMod crash there is.
	                  The engine limit is 8192 and it does not warn you.
	    entities      the same number from Lua's side, so a leak shows as a
	                  climb rather than as a single reading
	    lua memory    a runaway table is slower to kill a server and just as
	                  quiet
	    lua errors    the last error before a crash is very often the cause of
	                  it, and it scrolls off the console in seconds
	    breadcrumbs   who joined, who died, what was spawned - the last minute
	                  of the server's life in twenty lines

	IT IS CHEAP ON PURPOSE. One small file write every few seconds and a table
	of sixty strings. Anything heavier would be a thing to switch off, and a
	black box that is switched off is not one.
]]

if (not SERVER) then return end

ix.crashwatch = ix.crashwatch or {}

local LIVE = "falloutrp_crashwatch.txt"
local PREFIX = "falloutrp_crash_"

--- How often the file is rewritten, and how much history it holds.
local INTERVAL = 5
local BREADCRUMBS = 60

--- The line that says the last session ended on purpose.
local CLEAN = "-- CLEAN SHUTDOWN --"

--[[
	Warn once when the edict count crosses this. 8192 is the engine's hard
	limit; there is no warning at all before it is hit, and what happens then
	is exactly what was reported - the server simply stops.
]]
local EDICT_WARN = 6500

ix.crashwatch.trail = ix.crashwatch.trail or {}
ix.crashwatch.errors = ix.crashwatch.errors or {}
ix.crashwatch.started = ix.crashwatch.started or os.time()

--------------------------------------------------------------------------------
-- Leaving a trail
--------------------------------------------------------------------------------

--[[
	Add one line to the trail.

	Kept as a ring by dropping the oldest rather than by an index that wraps -
	sixty `table.remove`s a minute is nothing, and a wrapping index would mean
	the file has to be written out of order to read in order.
]]
function ix.crashwatch.Note(text)
	local trail = ix.crashwatch.trail

	trail[#trail + 1] = string.format("%s  %s", os.date("%H:%M:%S"), text)

	while (#trail > BREADCRUMBS) do
		table.remove(trail, 1)
	end
end

--- What the server looks like right now, as lines.
function ix.crashwatch.State()
	local uptime = os.time() - ix.crashwatch.started
	local players = player.GetAll()
	local names = {}

	for _, client in ipairs(players) do
		local character = client:GetCharacter()

		names[#names + 1] = string.format("%s (%s)%s", client:Name(),
			client:SteamID(),
			character and (" as " .. character:GetName()) or "")
	end

	return {
		string.format("map        %s", game.GetMap()),
		string.format("uptime     %d second(s)", uptime),
		string.format("written    %s", os.date("%d/%m/%Y %H:%M:%S")),
		string.format("edicts     %d of 8192", ents.GetCount()),
		string.format("entities   %d", #ents.GetAll()),
		string.format("lua memory %.1f MB", collectgarbage("count") / 1024),
		string.format("players    %d", #players),
		string.format("           %s", #names > 0 and table.concat(names,
			"\n           ") or "nobody")
	}
end

--------------------------------------------------------------------------------
-- Writing it out
--------------------------------------------------------------------------------

local function Write(final)
	local lines = {
		"-- falloutrp crash watch --",
		""
	}

	for _, line in ipairs(ix.crashwatch.State()) do
		lines[#lines + 1] = line
	end

	if (#ix.crashwatch.errors > 0) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- lua errors, most recent last --"

		for _, entry in ipairs(ix.crashwatch.errors) do
			lines[#lines + 1] = entry
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- the last minute --"

	for _, entry in ipairs(ix.crashwatch.trail) do
		lines[#lines + 1] = entry
	end

	if (final) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = CLEAN
	end

	file.Write(LIVE, table.concat(lines, "\n"))
end

timer.Create("ixCrashWatch", INTERVAL, 0, function() Write(false) end)

--[[
	The clean marker, written as late as possible.

	`ShutDown` runs on a map change and on a deliberate stop, so a session that
	ends either way is not reported as a crash on the next boot. A session that
	ends any other way leaves the file without it, which is the whole test.
]]
hook.Add("ShutDown", "ixCrashWatch", function()
	ix.crashwatch.Note("shutting down")

	Write(true)
end)

--------------------------------------------------------------------------------
-- Reading the last one
--------------------------------------------------------------------------------

--[[
	Look at what the previous session left behind.

	Run once, a few seconds in, so the message lands after the wall of loading
	output rather than in the middle of it - a warning nobody scrolls back to
	is a warning that was not given.
]]
local function Inspect()
	if (not file.Exists(LIVE, "DATA")) then return end

	local contents = file.Read(LIVE, "DATA") or ""

	if (string.find(contents, CLEAN, 1, true)) then return end

	--[[
		Kept under a name of its own. The live file is overwritten within five
		seconds of the server starting, so a crash that is not copied out now
		is a crash whose evidence is already gone.
	]]
	local name = PREFIX .. os.date("%Y%m%d_%H%M%S") .. ".txt"

	file.Write(name, contents)

	local accent, bad = Color(255, 200, 100), Color(255, 120, 120)

	MsgC(bad, "\n============================================================\n")
	MsgC(bad, "  THE LAST SESSION DID NOT SHUT DOWN CLEANLY.\n")
	MsgC(accent, "  What it was doing is in data/" .. name .. "\n")
	MsgC(accent, "  Run fo_crashwatch to see the current state.\n")
	MsgC(bad, "============================================================\n\n")

	--- The tail of it, so the common case needs no file at all.
	local lines = string.Explode("\n", contents)
	local from = math.max(#lines - 12, 1)

	for index = from, #lines do
		MsgC(Color(200, 200, 200), "  " .. lines[index] .. "\n")
	end

	MsgC(accent, "\n")
end

timer.Simple(8, Inspect)

--------------------------------------------------------------------------------
-- What gets noted
--------------------------------------------------------------------------------

hook.Add("PlayerInitialSpawn", "ixCrashWatch", function(client)
	ix.crashwatch.Note(string.format("%s joined (%s)", client:Name(),
		client:SteamID()))
end)

hook.Add("PlayerDisconnected", "ixCrashWatch", function(client)
	ix.crashwatch.Note(client:Name() .. " left")
end)

hook.Add("PlayerLoadedCharacter", "ixCrashWatch", function(client, character)
	ix.crashwatch.Note(string.format("%s loaded '%s'", client:Name(),
		character and character:GetName() or "?"))
end)

hook.Add("PlayerDeath", "ixCrashWatch", function(client, _, attacker)
	ix.crashwatch.Note(string.format("%s died to %s", client:Name(),
		IsValid(attacker) and attacker:GetClass() or "something"))
end)

hook.Add("PlayerSpawnedProp", "ixCrashWatch", function(client, model)
	ix.crashwatch.Note(string.format("%s spawned %s", client:Name(),
		tostring(model)))
end)

--[[
	Weapon changes, which is where the last crash happened to stop.

	Rate limited per player: a weapon change is one of the noisiest events
	there is - scrolling the wheel fires it per notch - and sixty breadcrumbs
	of somebody scrolling is sixty breadcrumbs of nothing.
]]
hook.Add("PlayerWeaponChanged", "ixCrashWatch", function(client, weapon)
	if ((client.ixCrashNoteAt or 0) > CurTime()) then return end

	client.ixCrashNoteAt = CurTime() + 2

	ix.crashwatch.Note(string.format("%s drew %s", client:Name(),
		IsValid(weapon) and weapon:GetClass() or "nothing"))
end)

--[[
	Lua errors, if this build has the hook.

	`OnLuaError` is not in every version of the game, so it is added the same
	way everything else uncertain in this schema is - guarded, and silent when
	it is not there rather than an error of its own.
]]
hook.Add("OnLuaError", "ixCrashWatch", function(message, realm, stack, name)
	local errors = ix.crashwatch.errors

	errors[#errors + 1] = string.format("%s  [%s] %s", os.date("%H:%M:%S"),
		tostring(realm or name or "?"), tostring(message))

	while (#errors > 20) do
		table.remove(errors, 1)
	end
end)

--------------------------------------------------------------------------------
-- The edict watch
--------------------------------------------------------------------------------

--[[
	The one number that kills a server without a word.

	Warned about ONCE per crossing rather than every tick, and noted in the
	trail as well as printed - so if the crash follows, the file says the
	server was already close before it happened.
]]
local warned = false

timer.Create("ixCrashWatchEdicts", 10, 0, function()
	local count = ents.GetCount()

	if (count < EDICT_WARN) then
		warned = false

		return
	end

	if (warned) then return end

	warned = true

	ix.crashwatch.Note(string.format("EDICT COUNT %d - the limit is 8192",
		count))

	ErrorNoHalt(string.format("[falloutrp] %d entities on the map. The engine "
		.. "limit is 8192 and it does not warn you before it stops.\n", count))
end)

--------------------------------------------------------------------------------
-- Asking it directly
--------------------------------------------------------------------------------

concommand.Add("fo_crashwatch", function(client)
	if (IsValid(client) and not ix.admin.Can(client, "dev.terminal")) then
		return
	end

	local accent, plain = Color(255, 200, 100), Color(200, 200, 200)

	MsgC(accent, "\n-- crash watch -----------------------------------------\n")

	for _, line in ipairs(ix.crashwatch.State()) do
		MsgC(plain, "  " .. line .. "\n")
	end

	if (#ix.crashwatch.errors > 0) then
		MsgC(accent, "\n  lua errors:\n")

		for _, entry in ipairs(ix.crashwatch.errors) do
			MsgC(Color(255, 140, 140), "  " .. entry .. "\n")
		end
	end

	MsgC(accent, "\n  the last minute:\n")

	for _, entry in ipairs(ix.crashwatch.trail) do
		MsgC(plain, "  " .. entry .. "\n")
	end

	MsgC(accent, "\n  written to data/" .. LIVE .. "\n\n")

	Write(false)
end)

ix.crashwatch.Note("server started")

--[[
	Bans and warnings: storing them, enforcing them, handing them out.

	See `sh_punish.lua` for the shapes and the arithmetic.

	THE BAN IS CHECKED AT `CheckPassword`, before the player entity exists.
	Every later hook - `PlayerInitialSpawn`, `PlayerAuthed` - means the person
	has already joined, and kicking somebody a second after they connect is a
	loading screen, a spawn, and a message in everybody's chat. `CheckPassword`
	refuses at the door with a reason on their screen.

	STORED GLOBALLY, not per schema and not per map. A ban is a fact about a
	person and this server; losing it on a map change would be a special kind
	of useless.
]]

if (not SERVER) then return end

util.AddNetworkString("ixPunishSync")
util.AddNetworkString("ixPunishUnban")
util.AddNetworkString("ixPunishRequest")

local BAN_KEY = "bans"
local WARN_KEY = "warnings"

local loaded = false

--- `[steamID64] = ban`.
ix.punish.bans = ix.punish.bans or {}

--- `[steamID64] = { warning, ... }`, oldest first.
ix.punish.warnings = ix.punish.warnings or {}

function ix.punish.Save()
	if (not loaded) then return end

	ix.data.Set(BAN_KEY, ix.punish.bans, true, true)
	ix.data.Set(WARN_KEY, ix.punish.warnings, true, true)
end

function ix.punish.Load()
	if (loaded) then return end

	ix.punish.bans = ix.data.Get(BAN_KEY, {}, true, true) or {}
	ix.punish.warnings = ix.data.Get(WARN_KEY, {}, true, true) or {}
	loaded = true

	--[[
		Expired bans are cleared on load rather than left to be skipped
		for ever. A file that only grows is one that eventually takes a second
		to read, and an expired ban is not evidence of anything the warning
		list does not already hold.
	]]
	local cleared = 0

	for steamID, ban in pairs(ix.punish.bans) do
		if (ix.punish.Expired(ban)) then
			ix.punish.bans[steamID] = nil
			cleared = cleared + 1
		end
	end

	if (cleared > 0) then ix.punish.Save() end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d ban(s), %d account(s) with warnings%s\n",
		table.Count(ix.punish.bans), table.Count(ix.punish.warnings),
		cleared > 0 and string.format(", cleared %d expired", cleared) or ""))
end

hook.Add("LoadData", "ixPunish", ix.punish.Load)
hook.Add("PostLoadData", "ixPunish", ix.punish.Load)
timer.Simple(4, ix.punish.Load)

--------------------------------------------------------------------------------
-- The door
--------------------------------------------------------------------------------

--[[
	`CheckPassword` runs before anything else and takes a STRING SteamID64.

	It can fire before `LoadData` has - a player connecting during startup - so
	the load is forced here rather than trusted to have happened. Letting a
	banned account in because the file had not been read yet is the one
	failure this hook exists to prevent.
]]
hook.Add("CheckPassword", "ixPunish", function(steamID64)
	ix.punish.Load()

	local ban = ix.punish.bans[tostring(steamID64)]

	if (not ban) then return end

	if (ix.punish.Expired(ban)) then
		ix.punish.bans[tostring(steamID64)] = nil

		ix.punish.Save()

		return
	end

	local remaining = ix.punish.Remaining(ban)

	return false, string.format(
		"You are banned.\nReason: %s\nBy: %s\n%s", ban.reason or "none given",
		ban.admin or "the console",
		remaining > 0
			and ("Time left: " .. ix.punish.FormatLength(remaining))
			or "This ban is permanent.")
end)

--------------------------------------------------------------------------------
-- Banning
--------------------------------------------------------------------------------

--[[
	Ban an account. Returns `true`, or `false, reason`.

	Takes a STEAMID rather than a player, so banning somebody who is not
	connected is the same function - `!banid` and `!ban` differ only in where
	they get the id from, and a second code path would be a second place for
	the rank limit to be forgotten.
]]
function ix.punish.Ban(client, steamID64, name, seconds, reason)
	local ok, why = ix.punish.CanBanFor(client, seconds)

	if (not ok) then return false, why end

	steamID64 = tostring(steamID64)

	if (steamID64 == ix.admin.rootSteamID) then
		return false, "That account cannot be banned."
	end

	--[[
		Somebody who is here is checked against the ladder as well. An
		offline account has no rank to compare - `ix.admin.stored` holds one,
		but immunity is read off a player - so the online check is the one that
		can be made, and it is the one that matters: you cannot ban an admin
		who is standing in front of you.
	]]
	local target

	for _, other in ipairs(player.GetAll()) do
		if (other:SteamID64() == steamID64) then target = other break end
	end

	if (IsValid(target) and not ix.admin.Outranks(client, target)) then
		return false, "They outrank you, or match you."
	end

	reason = string.Trim(reason or "")

	if (reason == "") then reason = "No reason given." end

	ix.punish.bans[steamID64] = {
		steamID = steamID64,
		name = name or (IsValid(target) and target:Name()) or "unknown",
		reason = reason,
		admin = IsValid(client) and client:Name() or "the console",
		adminSteamID = IsValid(client) and client:SteamID64() or "",
		time = os.time(),
		length = seconds,
		expires = seconds > 0 and (os.time() + seconds) or 0
	}

	ix.punish.Save()

	ix.admin.Announce(client, string.format("%s banned %s (%s) - %s",
		IsValid(client) and client:SteamName() or "the console",
		ix.punish.bans[steamID64].name, ix.punish.FormatLength(seconds),
		reason))

	ix.log.Add(client, "punishBan", ix.punish.bans[steamID64].name, steamID64,
		ix.punish.FormatLength(seconds), reason)

	if (IsValid(target)) then
		--[[
			SAME RULE AS THE KICK: the reason, without the name.

			A ban cannot be hidden - they are leaving and they will be told why
			when they try to come back - so `~ban` only removes the signature.
		]]
		target:Kick(ix.admin.IsSilent(client)
			and string.format("Banned (%s): %s",
				ix.punish.FormatLength(seconds), reason)
			or string.format("Banned by %s (%s): %s",
				IsValid(client) and client:Name() or "the console",
				ix.punish.FormatLength(seconds), reason))
	end

	ix.punish.SendAll()

	return true
end

function ix.punish.Unban(client, steamID64)
	steamID64 = tostring(steamID64)

	local ban = ix.punish.bans[steamID64]

	if (not ban) then return false, "That account is not banned." end

	ix.punish.bans[steamID64] = nil

	ix.punish.Save()
	ix.punish.SendAll()

	ix.log.Add(client, "punishUnban", ban.name, steamID64)

	return true, ban.name
end

--------------------------------------------------------------------------------
-- Warning
--------------------------------------------------------------------------------

function ix.punish.Warn(client, target, reason)
	if (not ix.admin.Can(client, "player.warn")) then
		return false, "You cannot warn."
	end

	if (not ix.admin.Outranks(client, target)) then
		return false, "They outrank you, or match you."
	end

	reason = string.Trim(reason or "")

	if (reason == "") then return false, "Give a reason." end

	local steamID64 = target:SteamID64()
	local list = ix.punish.warnings[steamID64] or {}

	list[#list + 1] = {
		time = os.time(),
		reason = reason,
		admin = IsValid(client) and client:Name() or "the console",
		adminSteamID = IsValid(client) and client:SteamID64() or "",
		name = target:Name()
	}

	ix.punish.warnings[steamID64] = list

	ix.punish.Save()
	ix.punish.SendAll()

	ix.log.Add(client, "punishWarn", target:Name(), steamID64, #list, reason)

	--[[
		The person warned is TOLD, and told how many they have. A warning
		nobody sees is a note, and the point of a warning is that it changes
		what somebody does next.
	]]
	target:Notify(string.format("Warning from %s: %s",
		IsValid(client) and client:Name() or "the console", reason))

	target:ChatPrint(string.format(
		"[!] That is warning number %d on your account.", #list))

	--[[
		Everybody who can read the admin log is told when somebody crosses the
		threshold, because "third time this week" is exactly the fact that is
		invisible to whoever is on next.
	]]
	local threshold = ix.config.Get("warningThreshold", 3)

	if (#list >= threshold) then
		for _, staff in ipairs(player.GetAll()) do
			if (ix.admin.Can(staff, "log.admin")) then
				staff:Notify(string.format("%s now has %d warnings.",
					target:Name(), #list))
			end
		end
	end

	return true, #list
end

function ix.punish.RemoveWarning(client, steamID64, index)
	steamID64 = tostring(steamID64)

	local list = ix.punish.warnings[steamID64]

	if (not list or not list[index]) then
		return false, "There is no such warning."
	end

	local removed = table.remove(list, index)

	if (#list == 0) then ix.punish.warnings[steamID64] = nil end

	ix.punish.Save()
	ix.punish.SendAll()

	ix.log.Add(client, "punishUnwarn", steamID64, removed.reason)

	return true, removed.reason
end

--------------------------------------------------------------------------------
-- Telling the menu
--------------------------------------------------------------------------------

--[[
	The whole list, to anybody who may see it.

	Sent rather than queried because it is small - a server with a thousand
	bans has a 60KB table - and because the BANS tab wants to be searchable
	client-side without a round trip per keystroke.
]]
function ix.punish.SendAll(client)
	local receivers = {}

	if (IsValid(client)) then
		receivers = {client}
	else
		for _, other in ipairs(player.GetAll()) do
			if (ix.admin.Can(other, "player.ban")
			or ix.admin.Can(other, "player.warn")) then
				receivers[#receivers + 1] = other
			end
		end
	end

	if (#receivers == 0) then return end

	net.Start("ixPunishSync")
		net.WriteTable(ix.punish.bans)
		net.WriteTable(ix.punish.warnings)
	net.Send(receivers)
end

net.Receive("ixPunishRequest", function(length, client)
	if (not ix.admin.Can(client, "player.ban")
	and not ix.admin.Can(client, "player.warn")) then return end

	ix.punish.SendAll(client)
end)

net.Receive("ixPunishUnban", function(length, client)
	if (not ix.admin.Can(client, "player.ban")) then return end

	local ok, name = ix.punish.Unban(client, net.ReadString())

	client:Notify(ok and ("Unbanned " .. name .. ".") or name)
end)

hook.Add("PlayerInitialSpawn", "ixPunish", function(client)
	timer.Simple(3, function()
		if (not IsValid(client)) then return end

		ix.punish.SendAll(client)

		--[[
			Somebody with warnings is reminded of them on join. It is the one
			moment they are certain to read something, and a warning they have
			forgotten is a warning that did no work.
		]]
		local list = ix.punish.warnings[client:SteamID64()]

		if (list and #list > 0) then
			client:ChatPrint(string.format(
				"[!] You have %d warning(s) on this account. The most recent: "
				.. "%s", #list, list[#list].reason))
		end
	end)
end)

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("punishBan", function(client, name, steamID, length, reason)
	return string.format("%s banned %s (%s) for %s - %s",
		client and client:Name() or "the console", name, steamID, length,
		reason)
end, FLAG_DANGER)

ix.log.AddType("punishUnban", function(client, name, steamID)
	return string.format("%s unbanned %s (%s).",
		client and client:Name() or "the console", name, steamID)
end, FLAG_WARNING)

ix.log.AddType("punishWarn", function(client, name, steamID, count, reason)
	return string.format("%s warned %s (%s) - number %d - %s",
		client and client:Name() or "the console", name, steamID, count,
		reason)
end, FLAG_WARNING)

ix.log.AddType("punishUnwarn", function(client, steamID, reason)
	return string.format("%s removed a warning from %s - %s",
		client and client:Name() or "the console", steamID, reason)
end, FLAG_WARNING)

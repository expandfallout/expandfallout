--[[
	Bans and warnings: the shapes, and the arithmetic both realms need.

	    a ban       an account cannot connect, until a time or for ever
	    a warning   a note against an account that it is shown, and that
	                stays whether or not anybody was banned for it

	WARNINGS ARE A RECORD, NOT A PUNISHMENT. The point of one is that the next
	admin can see it - "third time this week" is the fact that turns a kick
	into a ban, and it is the fact nobody has when warnings live in somebody's
	memory or a Discord channel.

	BOTH ARE KEYED BY STEAMID64, not by character and not by name. A ban that
	could be walked away from by making a new character would not be a ban, and
	a name is not an identity.

	`banLimit` ON THE RANK is what stops a moderator handing out a permanent
	ban. It lives in `sh_usergroups.lua` because it is a property of the rank;
	the check is here because this is where banning happens.
]]

ix.punish = ix.punish or {}

--------------------------------------------------------------------------------
-- Durations
--------------------------------------------------------------------------------

--[[
	Read a length written the way people write them.

	    0        permanent
	    30       thirty minutes, because a bare number is minutes everywhere
	    45m 2h 7d 3w

	Returns SECONDS, or nil if it makes no sense. Minutes for a bare number
	because that is what every admin mod has trained people to expect, and
	disagreeing with that convention would produce very long accidental bans.
]]
function ix.punish.ParseLength(text)
	text = string.lower(string.Trim(tostring(text or "")))

	if (text == "" or text == "0" or text == "perma"
	or text == "permanent") then
		return 0
	end

	local amount, unit = string.match(text, "^(%d+)%s*(%a*)$")

	amount = tonumber(amount)

	if (not amount) then return nil end

	local units = {
		[""] = 60, m = 60, min = 60, mins = 60,
		h = 3600, hr = 3600, hrs = 3600, hour = 3600, hours = 3600,
		d = 86400, day = 86400, days = 86400,
		w = 604800, week = 604800, weeks = 604800
	}

	local multiplier = units[unit]

	if (not multiplier) then return nil end

	return amount * multiplier
end

--- Seconds as something readable. "Permanent" for zero.
function ix.punish.FormatLength(seconds)
	seconds = math.floor(seconds or 0)

	if (seconds <= 0) then return "permanent" end

	if (seconds < 3600) then
		return math.floor(seconds / 60) .. " minute(s)"
	end

	if (seconds < 86400) then
		return string.format("%.4g hour(s)", seconds / 3600)
	end

	return string.format("%.4g day(s)", seconds / 86400)
end

--- How long is left on a ban, in seconds. 0 means it never ends.
function ix.punish.Remaining(ban)
	if (not ban or (ban.length or 0) <= 0) then return 0 end

	return math.max((ban.expires or 0) - os.time(), 0)
end

--[[
	Has this ban run out?

	A PERMANENT BAN NEVER HAS. That is the one case where "remaining is zero"
	and "expired" are opposite answers to the same number, which is why this is
	a function rather than a comparison written out at each call site.
]]
function ix.punish.Expired(ban)
	if (not ban) then return true end
	if ((ban.length or 0) <= 0) then return false end

	return os.time() >= (ban.expires or 0)
end

--------------------------------------------------------------------------------
-- What a rank may hand out
--------------------------------------------------------------------------------

--[[
	May this person ban for this long? Returns `true`, or `false, reason`.

	`banLimit` of 0 means no limit, which is the same number that means
	"permanent" for a ban length - so both are read through named helpers
	rather than compared raw, because the two zeroes mean opposite things.
]]
function ix.punish.CanBanFor(client, seconds)
	if (not ix.admin.Can(client, "player.ban")) then
		return false, "You cannot ban."
	end

	local limit = ix.admin.BanLimit(client)

	if (limit <= 0) then return true end

	if (seconds <= 0) then
		return false, string.format("You can only ban up to %s.",
			ix.punish.FormatLength(limit))
	end

	if (seconds > limit) then
		return false, string.format("You can only ban up to %s.",
			ix.punish.FormatLength(limit))
	end

	return true
end

--------------------------------------------------------------------------------
-- Permissions and configuration
--------------------------------------------------------------------------------

--[[
	Registered SHARED, like every other permission - the rank editor runs on
	the client and a permission it cannot see is a tickbox that does not exist.
	See `sh_sandbox.lua`, which learned that the hard way.
]]
ix.admin.RegisterPermission("player.warn", "Warn a player", "People")
ix.admin.RegisterPermission("player.warn.remove", "Remove a warning",
	"People")

ix.config.Add("warningThreshold", 3, "Warnings before staff on duty are told "
	.. "about somebody.", nil, {
	data = {min = 1, max = 20},
	category = "Administration"
})

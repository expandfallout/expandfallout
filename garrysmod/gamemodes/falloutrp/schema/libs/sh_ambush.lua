--[[
	Ambushes.

	A faction declares that it is fighting, somewhere, and for the next few
	minutes it may shoot people without the usual reasons. Phoenix's plugin
	describes it exactly: "lets factions RDM each other without a raid".

	WHAT AN AMBUSH IS, mechanically:

	    the faction that called it is marked hostile for a while
	    everybody hears distant gunfire and reads a line in chat
	    the faction sees a countdown at the top of the screen
	    calling it again offers to end it early

	THE COOLDOWN IS PER FACTION, NOT PER PLAYER, and that is the whole point of
	the rule: an ambush is the faction acting, so a faction that has just
	ambushed cannot send its next enlisted man to do it again a minute later.

	WHO MAY: anybody with a class in a real faction - "enlisted and up", which
	is rank 1 of `sh_classrank.lua`'s ladder. Wastelanders are the default
	faction and are not an organisation, so they cannot; a faction marked
	`raidImmune` cannot either, because a faction that cannot be fought should
	not be able to start a fight.
]]

ix.ambush = ix.ambush or {}

--- `[faction index] = {endTime, caller, startedAt}` for the one in progress.
ix.ambush.active = ix.ambush.active or {}

--- `[faction index] = CurTime()` the cooldown runs out at.
ix.ambush.cooldowns = ix.ambush.cooldowns or {}

--[[
	The lines the wasteland hears, one at random.

	Phoenix's seven, kept word for word - they are the flavour of the thing and
	rewriting them would make it a different server's ambush. The user asked
	for the fourth one by name.
]]
ix.ambush.notices = {
	"Distant gunfire can be heard . . .",
	"Sounds of war chime in the wind . . .",
	"Whizzing bullets & blasts echo in the air . . .",
	"Sounds of an on-going battle linger in the air . . .",
	"A firefight can be heard in the distance . . .",
	"Gunshots & explosions ring across the wasteland . . .",
	"Sounds of war echo in the air . . ."
}

ix.config.Add("ambushDuration", 300, "How long an ambush lasts, in seconds.",
	nil, {data = {min = 10, max = 3600}, category = "Ambush"})

ix.config.Add("ambushCooldown", 900,
	"Seconds before a faction may call another ambush.", nil, {
	data = {min = 0, max = 21600}, category = "Ambush"})

--[[
	HOW LONG BEFORE THE WASTELAND NOTICES.

	The line in chat is not the announcement of an ambush - it is the sound of
	one that has already started reaching everybody else, which is why it is
	late on purpose. Nobody should be able to read the chat and know that the
	shooting has not begun yet.
]]
ix.config.Add("ambushNoticeDelay", 25,
	"Seconds after an ambush starts before the wasteland hears it.", nil, {
	data = {min = 0, max = 600}, category = "Ambush"})

ix.config.Add("ambushMinRank", 1,
	"Lowest class rank that may call an ambush. 1 is enlisted, 4 is lead.",
	nil, {data = {min = 1, max = 4}, category = "Ambush"})

--- The colour the notice is written in - Phoenix's orange.
ix.ambush.colour = Color(255, 150, 0)

--[[
	Seconds as something a person reads.

	`ix.util.GetStringTime` IS NOT A FORMATTER - it PARSES one. Handed the
	number 900 it does `tonumber("900") * 60` and answers 54000, which is how
	a fifteen-minute cooldown came out as "54000 seconds" and looked like the
	cooldown itself was broken. It reads "5m" and answers 300; it is the
	opposite direction.
]]
function ix.ambush.Time(seconds)
	seconds = math.ceil(seconds)

	if (seconds < 60) then return seconds .. "s" end

	local minutes = math.floor(seconds / 60)

	if (seconds % 60 == 0) then return minutes .. "m" end

	return string.format("%dm %ds", minutes, seconds % 60)
end

--[[
	Whether this faction is ambushing right now.

	Takes a faction index rather than a player because the HUD asks about the
	viewer's faction and the damage rules ask about two of them.
]]
function ix.ambush.IsActive(faction)
	local entry = ix.ambush.active[faction]

	if (not entry) then return false end

	return entry.endTime > CurTime()
end

--- Seconds left, or 0. Never negative, so callers can print it directly.
function ix.ambush.TimeLeft(faction)
	local entry = ix.ambush.active[faction]

	if (not entry) then return 0 end

	return math.max(entry.endTime - CurTime(), 0)
end

--- Seconds until this faction may call another, or 0.
function ix.ambush.Cooldown(faction)
	return math.max((ix.ambush.cooldowns[faction] or 0) - CurTime(), 0)
end

--[[
	Whether this player may call one. `true`, or `false, reason`.

	Shared so the window can grey the option out and the server can refuse it,
	which is the same rule asked twice rather than two rules that agree today.
]]
function ix.ambush.CanCall(client)
	local character = IsValid(client) and client:GetCharacter()

	if (not character) then return false, "You need a character." end

	local faction = character:GetFaction()
	local data = ix.faction.indices[faction]

	if (not data) then return false, "You are not in a faction." end

	if (data.isDefault) then
		return false, "Wastelanders are not a faction and cannot ambush."
	end

	if (data.raidImmune) then
		return false, "Your faction cannot take part in fighting."
	end

	local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

	if (rank < ix.config.Get("ambushMinRank", 1)) then
		return false, string.format("You must be %s or above to call an ambush.",
			ix.class.GetRankName(faction, ix.config.Get("ambushMinRank", 1)))
	end

	if (ix.ambush.IsActive(faction)) then
		return false, "Your faction is already ambushing."
	end

	local cooldown = ix.ambush.Cooldown(faction)

	if (cooldown > 0) then
		return false, string.format("Your faction may ambush again in %s.",
			ix.ambush.Time(cooldown))
	end

	return true
end

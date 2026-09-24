--[[
	Player killing.

	A character can be marked PK ACTIVE for a while. If they die during that
	window it is a player kill, and a player kill costs them: levels, caps,
	everyone who knew them, everyone they knew - and their head, which is left
	on the ground where they fell for anybody to pick up.

	PORTED FROM PHOENIX'S `playerkilling`. Their configs and their split:

	    PK Level Reduction Above 50    2
	    PK Level Reduction Below 50    5
	    PK Money Cost Above 50      1000
	    PK Money Cost Below 50       500

	50 is `ix.leveling.spike` here, the same number and the same meaning, so
	the split lands in the same place theirs does.

	WHAT IS THEIRS AND KEPT: the two-tier costs, the confirmation before
	marking somebody, the countdown on the marked player's own screen, and the
	local announcement to anybody standing nearby.

	WHAT THIS ADDS, because it was asked for:

	    a timer      `/pk` marks somebody for a configurable while, not for ever
	    recognition  wiped in BOTH directions, which theirs does not do
	    the head     a unique item, "<name>'s Head", dropped where they fell

	WHAT IS DELIBERATELY NOT HERE: Phoenix force a name change after a PK -
	`freeNameChange`, `/charname` and a Derma prompt to pick a new one. That
	was not asked for and it is a different answer to the same question the
	recognition wipe answers: how a character stops being the person they were.
	Doing both would be doing it twice.

	THE HEAD IS TAKEN FROM THE BODY, not dropped by the death. `ix.corpse`
	place a head is ever made, and it takes a character and a position rather
	than a death - so when corpses can be decapitated, that system calls this
	function and nothing here has to know about it.
]]

ix.pk = ix.pk or {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

--[[
	How long `/pk` marks somebody for.

	Phoenix's has no timer at all - theirs is on until they die or an admin
	turns it off. A window is what was asked for, and it is the better rule:
	an indefinite mark is one that gets forgotten and collected weeks later.
]]
ix.config.Add("pkDuration", 1800,
	"Seconds somebody stays PK active after /pk.", nil, {
	data = {min = 60, max = 86400},
	category = "Player Killing"
})

--[[
	How long a mugging marks somebody for.

	The mugging system does not exist yet. The config does, because the number
	belongs with the other PK numbers rather than in whatever file eventually
	does the mugging, and because `ix.pk.Mark` is already the one way in.
]]
ix.config.Add("pkMuggingDuration", 900,
	"Seconds somebody stays PK active after being mugged.", nil, {
	data = {min = 60, max = 86400},
	category = "Player Killing"
})

ix.config.Add("pkLevelsAbove", 2,
	"Levels lost on a PK at or above level 50.", nil, {
	data = {min = 0, max = 100},
	category = "Player Killing"
})

ix.config.Add("pkLevelsBelow", 5,
	"Levels lost on a PK below level 50.", nil, {
	data = {min = 0, max = 100},
	category = "Player Killing"
})

ix.config.Add("pkCapsAbove", 1000,
	"Caps lost on a PK at or above level 50.", nil, {
	data = {min = 0, max = 100000},
	category = "Player Killing"
})

ix.config.Add("pkCapsBelow", 500,
	"Caps lost on a PK below level 50.", nil, {
	data = {min = 0, max = 100000},
	category = "Player Killing"
})

--- How far Phoenix's `pknotify` carries. Theirs, exactly.
ix.config.Add("pkNotifyRange", 800,
	"How far the 'marked for death' notice carries.", nil, {
	data = {min = 0, max = 8192},
	category = "Player Killing"
})

--------------------------------------------------------------------------------
-- Reading it
--------------------------------------------------------------------------------

--[[
	When somebody's mark runs out, as a wall clock. 0 for not marked.

	ON THE CHARACTER, NOT THE PLAYER, so it survives a disconnect - otherwise
	`/pk` is defeated by reconnecting, which is the first thing anybody would
	try. `os.time` rather than `CurTime` for the same reason: `CurTime` starts
	again at zero on every map load and a mark saved in it would either expire
	instantly or last for ever.
]]
function ix.pk.Until(character)
	if (not character) then return 0 end

	return tonumber(character:GetData("pkUntil", 0)) or 0
end

function ix.pk.IsActive(character)
	return ix.pk.Until(character) > os.time()
end

--- Seconds left on somebody's mark, or 0.
function ix.pk.Remaining(character)
	return math.max(ix.pk.Until(character) - os.time(), 0)
end

--[[
	What a PK costs this character.

	Two tiers, split at `ix.leveling.spike` - level 50, the same number Phoenix
	split on. Somebody at the ceiling has a great deal more to lose in absolute
	terms and loses fewer levels for it; somebody below it loses more levels
	and fewer caps, because levels are what they have.
]]
function ix.pk.Cost(character)
	if (not character) then return 0, 0 end

	local above = character:GetLevel() >= ix.leveling.spike

	return ix.config.Get(above and "pkLevelsAbove" or "pkLevelsBelow", 2),
		ix.config.Get(above and "pkCapsAbove" or "pkCapsBelow", 1000)
end

--------------------------------------------------------------------------------
-- Permissions
--------------------------------------------------------------------------------

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("player.pk", "Mark a player for death",
		"People")
end

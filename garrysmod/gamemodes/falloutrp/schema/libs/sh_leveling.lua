--[[
	Levelling.

	Ported from Phoenix's `leveling` plugin ("Leveling 2.0"). The XP curve,
	the level 50 spike, the respec rules and their configs are theirs exactly.

	Everything lives in character DATA rather than registered vars - `level`,
	`XP`, `skillPoints`, `respecs` - which is their choice and is kept, because
	`SetData` is `isLocal` in Helix and none of it needs to reach anyone but
	the owner.

	THE CURVE HAS TWO HALVES, and the shape is the whole design:

	    level <= 50   (92 + level * 2) * (level - 1) + 200      quadratic
	    level >  50   requiredXP(50) + floor(1.22 ^ level)      exponential

	so levelling is steady up to 50 and then hits a wall. 50 is the intended
	soft cap, and it is also the respec gate - the two are the same number on
	purpose.

	`sv_plugin.lua` was never scraped, so how XP is actually granted, how
	levelling up is detected and what a level awards are all reconstructed -
	see `sv_leveling.lua`.
]]

ix.leveling = ix.leveling or {}

--[[
	Where the curve changes shape. Named as they named it.
]]
ix.leveling.spike = 50

ix.config.Add("xpMultiplier", 1, "Multiplier applied to all XP gained.", nil, {
	data = {min = 1, max = 20}, category = "Leveling"
})

ix.config.Add("xpPerNPCKill", 1, "XP gained per NPC or creature killed.", nil, {
	data = {min = 0, max = 1000}, category = "Leveling"
})

--[[
	Per CONTAINER, once, on the first time anyone opens it - not per item
	taken. Higher than a kill because it happens far less often.
]]
ix.config.Add("xpPerContainer", 5,
	"XP gained the first time a container is opened.", nil, {
	data = {min = 0, max = 1000}, category = "Leveling"
})

ix.config.Add("xpPerKill", 2, "XP gained per kill.", nil, {
	data = {min = 1, max = 100}, category = "Leveling"
})

--[[
	Their config is spelled "Respect Cost". The typo is theirs; the name here
	is corrected, since nothing reads it by that string any more.
]]
ix.config.Add("respecCost", 1000, "Cost to respec, in caps.", nil, {
	data = {min = 0, max = 9999999}, category = "Leveling"
})

ix.config.Add("respecExtraCost", 1000, "Extra cost per respec already used.", nil, {
	data = {min = 0, max = 9999999}, category = "Leveling"
})

ix.config.Add("respecClamp", 5, "The most respecs that can raise the price.", nil, {
	data = {min = 1, max = 999}, category = "Leveling"
})

ix.config.Add("respecFirstFree", true, "Whether a character's first respec is free.",
	nil, {category = "Leveling"})

--[[
	NOT THEIRS. Their plugin never says what a level awards, because the half
	that awarded it was server-side and is not in any scrape. One point per
	level is the obvious reading of a system with a `skillPoints` counter and a
	SPECIAL spread of 7 attributes, and it is a config so it can be tuned
	without touching code.
]]
ix.config.Add("skillPointsPerLevel", 1, "SPECIAL points awarded per level.", nil, {
	data = {min = 0, max = 10}, category = "Leveling"
})

--[[
	Total XP needed to BE a given level - cumulative, not per-level.

	Recursive above the spike exactly as theirs is. The recursion is one deep
	and terminates immediately, since `requiredXP(50)` takes the quadratic
	branch.
]]
function ix.leveling.RequiredXP(level)
	level = level or 1

	if (level > ix.leveling.spike) then
		return ix.leveling.RequiredXP(ix.leveling.spike) + math.floor(1.22 ^ level)
	elseif (level > 0) then
		return (92 + (level * 2)) * math.max(level - 1, 0) + 200
	end

	return 0
end

local characterMeta = ix.meta.character

function characterMeta:GetLevel()
	return self:GetData("level", 1)
end

function characterMeta:GetXP()
	return self:GetData("XP", 0)
end

function characterMeta:GetSkillPoints()
	return self:GetData("skillPoints", 0)
end

function characterMeta:GetRespecs()
	return self:GetData("respecs", 0)
end

--[[
	Where this character sits between its current level and the next.

	Returns `earned, needed, fraction` - the XP INTO the current level, the XP
	that level spans, and 0-1 for a bar.

	CLAMPED, because the two ends do not agree. `RequiredXP(1)` is 200 but a
	new character starts on 0 XP, so the raw fraction is negative until they
	earn their first 200. Their `charsetlevel` papers over this by writing
	`XP = requiredXP(level)` whenever it sets a level; a character who has
	never been touched by that command has not had it done for them.
]]
function ix.leveling.GetProgress(character)
	if (not character) then return 0, 1, 0 end

	local level = character:GetLevel()
	local current = ix.leveling.RequiredXP(level)
	local next = ix.leveling.RequiredXP(level + 1)
	local span = math.max(next - current, 1)
	local earned = math.Clamp(character:GetXP() - current, 0, span)

	return earned, span, earned / span
end

--[[
	May this character respec, and what does it cost?

	Returns `true, cost` or `false, reason`. Their rules exactly: level 50 or
	better, the first one free if configured, and the price climbing with each
	respec already taken up to a clamp.
]]
function ix.leveling.CanRespec(client)
	local character = IsValid(client) and client:GetCharacter()

	if (not character) then return false, "No character." end

	if (character:GetLevel() < ix.leveling.spike) then
		return false, string.format("You must be level %d to respec.", ix.leveling.spike)
	end

	local used = math.min(character:GetRespecs(), ix.config.Get("respecClamp", 5))

	if (used == 0 and ix.config.Get("respecFirstFree", true)) then
		return true, 0
	end

	local cost = ix.config.Get("respecCost", 1000)
		+ (used * ix.config.Get("respecExtraCost", 1000))

	--[[
		`GetMoney`, not a `HasMoney` helper - Helix has no such method. Money is
		a registered char var with only a getter and a setter.
	]]
	if (character:GetMoney() < cost) then
		return false, string.format("Not enough caps. You need %s.",
			ix.currency.Get(cost))
	end

	return true, cost
end

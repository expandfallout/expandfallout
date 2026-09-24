--[[
	Levelling - the server half.

	RECONSTRUCTED. Their `sv_plugin.lua` is not in any scrape, so how XP is
	granted, how a level-up is detected and what a level awards are all worked
	out from what the client and shared halves assume of them:

	    net "getXP"        an int and a mute flag  -> the +N popup
	    net "levelUpNotif" no payload              -> the "Level up!" panel
	    char data          level, XP, skillPoints, respecs
	    config             XP Multiplier, XP Per Kill

	The one thing nothing in the scrape reveals is what a level GIVES you. A
	`skillPoints` counter that nothing ever increments is not a system, so it
	is awarded per level through a config - see `skillPointsPerLevel`.

	LEVELLING UP IS A LOOP, NOT A TEST. A single large XP award - a quest, an
	admin command - can cross several thresholds at once, and a system that
	only checked `>= next` would swallow every level but the first.
]]

if (not SERVER) then return end

util.AddNetworkString("ixLevelingXP")
util.AddNetworkString("ixLevelingLevelUp")
util.AddNetworkString("ixLevelingRespec")
util.AddNetworkString("ixLevelingSpend")

local characterMeta = ix.meta.character

function characterMeta:SetLevel(level)
	self:SetData("level", math.max(math.Round(level or 1), 1))
end

function characterMeta:SetXP(amount)
	self:SetData("XP", math.max(math.Round(amount or 0), 0))
end

function characterMeta:SetSkillPoints(amount)
	self:SetData("skillPoints", math.max(math.Round(amount or 0), 0))
end

--[[
	Award XP.

	`bMute` suppresses the sound but not the popup, which is what their net
	message carries a mute flag for - a stream of small awards should not
	become a stream of chimes.
]]
function characterMeta:AddXP(amount, bMute)
	amount = math.Round((amount or 0) * ix.config.Get("xpMultiplier", 1))

	if (amount == 0) then return end

	local client = self:GetPlayer()

	self:SetXP(self:GetXP() + amount)

	if (IsValid(client) and amount > 0) then
		net.Start("ixLevelingXP")
			net.WriteInt(amount, 32)
			net.WriteBool(bMute and true or false)
		net.Send(client)
	end

	self:CheckLevel()
end

--[[
	Promote as far as the XP allows.

	The loop is the point - see the header. Capped at a hundred iterations so
	a corrupt XP value cannot spin the server; that is far more levels than
	the curve can produce in one award.
]]
function characterMeta:CheckLevel()
	local client = self:GetPlayer()
	local gained = 0

	for _ = 1, 100 do
		local next = self:GetLevel() + 1

		if (self:GetXP() < ix.leveling.RequiredXP(next)) then break end

		self:SetLevel(next)
		gained = gained + 1
	end

	if (gained < 1) then return end

	local points = gained * ix.config.Get("skillPointsPerLevel", 1)

	if (points > 0) then
		self:SetSkillPoints(self:GetSkillPoints() + points)
	end

	if (IsValid(client)) then
		--[[
			One notification for the whole batch. Crossing three levels at once
			should feel like one good moment, not three overlapping panels
			fighting for the same corner of the screen.
		]]
		net.Start("ixLevelingLevelUp")
			net.WriteUInt(self:GetLevel(), 16)
			net.WriteUInt(points, 16)
		net.Send(client)
	end

	hook.Run("OnCharacterLevelUp", client, self, gained)
end

--[[
	XP for kills.

	Only players killing players, and never for killing yourself - the obvious
	exploit, and one worth blocking before anyone finds it rather than after.
]]
hook.Add("PlayerDeath", "ixLeveling", function(victim, inflictor, attacker)
	if (not IsValid(attacker) or not attacker:IsPlayer()) then return end
	if (attacker == victim) then return end

	local character = attacker:GetCharacter()

	if (not character) then return end

	character:AddXP(ix.config.Get("xpPerKill", 2))
end)

--[[
	XP for killing things that are not players.

	`OnNPCKilled` covers engine NPCs and any scripted entity built on an NPC
	base, which is what the Fallout creature addons use. It does NOT cover
	nextbots - those are not NPCs as far as this hook is concerned, and if
	creature packs that use them are added later they will need their own
	death hook rather than this one quietly not firing.

	Set `xpPerNPCKill` to 0 to turn it off.
]]
hook.Add("OnNPCKilled", "ixLeveling", function(npc, attacker)
	if (not IsValid(attacker) or not attacker:IsPlayer()) then return end

	local character = attacker:GetCharacter()

	if (not character) then return end

	local amount = ix.config.Get("xpPerNPCKill", 1)

	if (amount <= 0) then return end

	--[[
		Not muted. The panel only plays its chime when it OPENS - `IncreaseXP`
		deliberately does not - so a burst of kills is one sound and a running
		total, and muting here would just mean never hearing it at all.
	]]
	character:AddXP(amount)
end)

--[[
	Spending a point.

	Re-checked from scratch: the client asking is not evidence it may. A point
	can only go into a real SPECIAL attribute, only if one is owed, and only up
	to the same ceiling character creation uses.
]]
net.Receive("ixLevelingSpend", function(length, client)
	if (not IsValid(client)) then return end

	local key = string.lower(net.ReadString())
	local character = client:GetCharacter()

	if (not character) then return end

	if (not ix.special.isSpecial[key]) then return end

	if (character:GetSkillPoints() < 1) then
		client:NotifyLocalized("levelNoPoints")
		return
	end

	--[[
		Read the RAW attribute, not `ix.special.Get`. That applies radiation
		and hunger modifiers, so a starving player would appear to have room
		they do not have - and would lose the point the moment they ate.
	]]
	local current = character:GetAttribute(key, 0)
	local maximum = ix.config.Get("maxAttributes", 25)

	if (current >= maximum) then
		client:NotifyLocalized("levelAttributeMaxed")
		return
	end

	character:SetAttrib(key, current + 1)
	character:SetSkillPoints(character:GetSkillPoints() - 1)

	ix.special.Apply(client)
end)

--[[
	Respec.

	Refunds every point spent since creation by resetting each attribute to
	zero and handing back the creation allowance plus one point per level -
	which is exactly what the character would have had if they had levelled
	without spending anything.
]]
--[[
	Do the reset. Returns how many points they have afterwards.

	PULLED OUT OF THE NET RECEIVE so a PK can call it. Losing levels and
	keeping the attributes those levels paid for is not a state this schema
	should be able to reach - it would leave somebody with more spent than they
	have earned, and every recompute afterwards reading from a total that is
	wrong.

	`bCounted` is what tells a chosen respec from an imposed one. A PK is not
	somebody spending their free respec, so it does not use it up and does not
	push the price of the next one along.
]]
function ix.leveling.Respec(character, bCounted)
	if (not character) then return 0 end

	local client = character:GetPlayer()

	for _, key in ipairs(ix.special.order) do
		character:SetAttrib(key, 0)
	end

	--[[
		Exactly what they would have had if they had levelled without spending
		anything: the creation allowance, plus one lot per level SINCE the
		first. Read from the current level, so calling this after a PK has
		taken levels away gives the points for the level they are now.
	]]
	local levels = math.max(character:GetLevel() - 1, 0)

	character:SetSkillPoints(ix.config.Get("specialPoints", 15)
		+ levels * ix.config.Get("skillPointsPerLevel", 1))

	if (bCounted) then
		character:SetData("respecs", character:GetRespecs() + 1)
	end

	if (IsValid(client)) then ix.special.Apply(client) end

	return character:GetSkillPoints()
end

--[[
	UNSPENT POINTS DO NOT STOP A RESPEC, and never did.

	`ix.leveling.CanRespec` asks three things - level 50 or better, how many
	respecs have been used, and whether they can afford the next one. Having
	points in hand is not one of them, and should not be: somebody who has
	saved their points and wants to move the ones they DID spend is doing
	exactly what a respec is for.
]]
net.Receive("ixLevelingRespec", function(length, client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local allowed, result = ix.leveling.CanRespec(client)

	if (not allowed) then
		client:Notify(result)
		return
	end

	if (result > 0) then
		-- No TakeMoney in Helix; money is a plain get/set char var.
		character:SetMoney(math.max(character:GetMoney() - result, 0))
	end

	local points = ix.leveling.Respec(character, true)

	client:NotifyLocalized("levelRespecDone", points)
	ix.log.Add(client, "levelRespec", result)
end)

ix.log.AddType("levelRespec", function(client, cost)
	return string.format("%s respecced for %d caps.", client:Name(), cost)
end, FLAG_NORMAL)

--[[
	Sets the level and the XP together, as theirs does. Setting one without
	the other leaves a character who instantly re-levels or can never level
	again.
]]

--[[
	Where the XP went.

	Written because "I am not getting any XP" has four possible causes - no
	source fired, the multiplier is zero, the character has none, or the popup
	is broken - and no way to tell them apart from in front of the screen.
]]
concommand.Add("fo_xp_report", function(client)
	if (IsValid(client) and not client:IsAdmin()) then return end

	local function Line(colour, text)
		if (IsValid(client)) then
			client:ChatPrint(text)
		end

		MsgC(colour, text .. "\n")
	end

	Line(Color(255, 200, 100), "[falloutrp] XP sources")

	for _, entry in ipairs({
		{"xpPerKill", 2, "killing a player"},
		{"xpPerNPCKill", 1, "killing an NPC"},
		{"xpPerContainer", 5, "opening a container nobody has looted"}
	}) do
		local value = ix.config.Get(entry[1], entry[2])

		Line(value > 0 and Color(200, 200, 200) or Color(255, 160, 160),
			string.format("  %-14s %-4s  %s", entry[1], tostring(value),
				value > 0 and entry[3] or "OFF - " .. entry[3]))
	end

	local multiplier = ix.config.Get("xpMultiplier", 1)

	Line(Color(200, 200, 200), string.format("  %-14s %s",
		"xpMultiplier", tostring(multiplier)))

	local character = IsValid(client) and client:GetCharacter()

	if (not character) then return end

	local earned, span = ix.leveling.GetProgress(character)

	Line(Color(255, 200, 100), string.format(
		"  you: level %d, %d XP total, %d/%d into this level, %d point(s) unspent",
		character:GetLevel(), character:GetXP(), earned, span,
		character:GetSkillPoints()))

	--[[
		An actual award, so the popup is tested along with the numbers. One XP
		is small enough not to matter and enough to prove the whole chain.
	]]
	character:AddXP(1)
	Line(Color(200, 200, 200),
		"  granted 1 XP - if no +1 appeared on the left, the popup is the problem")
end)

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]

--[[
	Aid base item - chems, stimpaks and cures.

	Everything in `items/aid/` inherits this: `ix.item.LoadFromDir` gives items
	in `items/<folder>/` the base `base_<folder>`, so the folder name and this
	filename have to stay in step.

	The field contract is Phoenix's, so their chem roster converts
	mechanically:

	    aidID              identity of the effect, so a second dose refuses
	    effectSound        played on use
	    buffs              what it grants: {stat, value, duration}
	    heal               health restored immediately
	    radiation          rads added (RadAway passes a negative)
	    addictionName      what it can hook you on
	    addictionChance    0-100
	    injectFlavour      the verb, for using it on somebody else

	WHAT IS DIFFERENT FROM THEIRS. Their items carry `effectFunctions` with a
	SERVER and CLIENT function each, and every one of the thirty is a handful
	of lines calling `nut.buffs:add`. Written as DATA here instead: a chem is
	what it grants, and a table of grants can be read by the description
	builder, the report and the item itself. Their version can only be read by
	running it, which is why their descriptions are hand-written strings that
	disagree with the code in several places - their Buffout says "+25 Max HP
	for 2 minutes" and grants exactly that, but their Jet says "+30 speed for
	1 minute" while granting 30 for 60 which is right, and Med-X says 4 minutes
	and grants 240 which is also right, so the risk is real rather than
	realised. `effectFunctions` is still supported for the handful of chems
	that genuinely do something a table cannot describe.
]]

ITEM.name = "Aid"
ITEM.description = "Something medicinal."
ITEM.model = "models/mosi/fnv/props/health/stimpak.mdl"
ITEM.category = "Aid"

ITEM.width = 1
ITEM.height = 1

--- The marker other systems key off, rather than a base name.
ITEM.isAid = true

--[[
	Whether this is a REPAIR rather than a drug.

	A race with `canUseChems` off refuses every aid item except these, which is
	the difference between a stimpak and a robot repair kit: one is chemistry
	and the other is a spanner. Set it on anything a machine should be able to
	use on itself.
]]
ITEM.mechanical = false

--[[
	Identity of the effect, NOT of the item.

	Two items can share one - Mentats and Berry Mentats are the same high - and
	sharing it is what stops a player stacking them. Nil means the chem can be
	taken on top of itself, which is right for a stimpak.
]]
ITEM.aidID = nil

ITEM.effectSound = "phoenix/itm/npc_human_using_stimpak.mp3"

--- `{{stat = "SPD", value = 30, duration = 60}, ...}`
ITEM.buffs = {}

ITEM.heal = 0

--- Seconds the healing is spread over. 0 is instant.
ITEM.healTime = 0

ITEM.radiation = 0

ITEM.addictionName = nil
ITEM.addictionChance = 0

--- Cures addiction: true for all of it, or a name for one.
ITEM.cures = nil

--[[
	How it goes in: "inject", "swallow" or "inhale".

	Drives the flash and the noise on the client - see `libs/cl_chemfx.lua`.
	Phoenix have the same three and pick between them per item; a pill and a
	syringe should not feel the same going down.
]]
ITEM.useEffect = "inject"

ITEM.injectFlavour = "inject"
ITEM.effectFunctions = {}

--[[
	Built from the fields rather than written out.

	The reason is in the header: a hand-written description is a second copy of
	the numbers, and second copies go stale. The addiction warning is Phoenix's
	wording and their three bands.
]]
function ITEM:GetDescription()
	local description = self.description or ""
	local lines = {}

	if ((self.heal or 0) > 0) then
		lines[#lines + 1] = (self.healTime or 0) > 0
			and string.format(" - Heals %d health over %s, stops if you are hit",
				self.heal, ix.buff.FormatDuration(self.healTime))
			or string.format(" - Heals %d health", self.heal)
	end

	for _, buff in ipairs(self.buffs or {}) do
		local info = ix.buff.stats[buff.stat]

		lines[#lines + 1] = string.format(" - %s for %s",
			ix.buff.Describe(buff.stat, buff.value),
			buff.duration and buff.duration > 0
				and ix.buff.FormatDuration(buff.duration) or "as long as it lasts")

		if (info and info.name) then
			lines[#lines] = lines[#lines] .. string.format("  (%s)", info.name)
		end
	end

	if ((self.radiation or 0) > 0) then
		lines[#lines + 1] = string.format(" - Radiation: +%d", self.radiation)
	elseif ((self.radiation or 0) < 0) then
		lines[#lines + 1] = string.format(" - Removes %d rads", -self.radiation)
	end

	if (self.cures) then
		lines[#lines + 1] = self.cures == true
			and " - Cures every addiction"
			or " - Cures " .. tostring(self.cures) .. " addiction"
	end

	if (#lines > 0) then
		description = description .. "\n\n" .. table.concat(lines, "\n")
	end

	--[[
		The warning is the last thing, in its own paragraph, because it is the
		one line that changes whether somebody uses the item.
	]]
	if ((self.addictionChance or 0) > 0) then
		local band = self.addictionChance > 75 and "High"
			or self.addictionChance > 40 and "Moderate" or "Low"

		description = description .. string.format(
			"\n\n%s chance of addiction (%d%%).", band, self.addictionChance)

		local data = self.addictionName and ix.addiction.Get(self.addictionName)

		description = description .. (data and data.timedClear
			and "\nThe addiction wears off in time."
			or "\nThe addiction must be cured.")
	end

	return description
end

--[[
	May this character use it at all?

	Two gates, both Phoenix's:

	  * a race can whitelist or blacklist chems, because a ghoul and a super
	    mutant do not have the same chemistry
	  * POWER ARMOUR seals you in, and you cannot get a needle through it. Only
	    the chems on `ix.armor.paAllowedChems` work, which is where the
	    inhalers and the ones fed through the suit's own systems live.

	Both libraries are optional as far as this file is concerned - it must not
	stop working because one of them has not loaded.
]]
function ITEM:CanConsume(client)
	local character = IsValid(client) and client:GetCharacter()

	if (not character) then return false, "you have no character" end

	--[[
		A RACE THAT CANNOT TAKE CHEMS AT ALL.

		`RACE.canUseChems` off means chemistry does nothing to that body - a
		securitron has no bloodstream - and the exception is an item marked
		`ITEM.mechanical`, which is how a repair kit reaches a robot and a
		stimpak does not. Set in the live editor, per race.

		Asked before the whitelists below, because it is the broader rule: a
		race that takes nothing has no use for a list of what it takes.
	]]
	local race = ix.races and ix.races.Get(character:GetRace())

	if (race and race.canUseChems == false and not self.mechanical) then
		return false, "your kind has no use for chemistry"
	end

	if (ix.races and ix.races.GetChemWhitelist) then
		local whitelist = ix.races.GetChemWhitelist(character)

		--[[
			AN EMPTY LIST IS NO LIST - the editor takes a list off by
			unticking everything - and a repair kit is a spanner, not a
			chem, so the list does not apply to it.
		]]
		if (whitelist and next(whitelist) ~= nil and not self.mechanical
		and not whitelist[self.uniqueID]) then
			return false, "your kind cannot use this"
		end
	end

	if (ix.races and ix.races.GetChemBlacklist) then
		local blacklist = ix.races.GetChemBlacklist(character)

		if (blacklist and blacklist[self.uniqueID]) then
			return false, "your kind cannot use this"
		end
	end

	if (ix.armor and ix.armor.paAllowedChems
	and client:GetNW2Bool("WearingPA", false)
	and not ix.armor.paAllowedChems[self.uniqueID]) then
		return false, "you cannot use that inside power armour"
	end

	if (self.aidID and ix.buff.Has(client, self.aidID)) then
		return false, "that is already working"
	end

	return true
end

--[[
	Apply the item to somebody.

	`client` is who is being dosed, which is not always who owns the item - an
	injection puts the effect in the other person. Everything below reads
	`client` and nothing reads `item.player`, so the two paths cannot diverge.
]]
function ITEM:Consume(client)
	if (not SERVER or not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	if (self.effectSound) then
		client:EmitSound(self.effectSound, 60, 100, 0.7)
	end

	--[[
		Sent rather than played from the item's own client half, because the
		person being dosed is not always the person holding the item - an
		injection has to flash the TARGET's screen.
	]]
	if (self.useEffect) then
		net.Start("ixChemIntake")
			net.WriteString(self.useEffect)
		net.Send(client)
	end

	if ((self.heal or 0) > 0) then
		--[[
			OVER TIME, and interrupted by damage - see `libs/sv_healing.lua`.

			`healTime` of 0 means instant, which is right for the things that
			are not stimpaks: a blood pack goes in all at once and a first aid
			kit is time you already spent. Anything with a time behaves like a
			stimpak in the games, where using one in a firefight wastes it.
		]]
		if ((self.healTime or 0) > 0 and ix.healing) then
			ix.healing.Begin(client, self.heal, self.healTime, self.name)
		else
			client:SetHealth(math.min(client:Health() + self.heal,
				client:GetMaxHealth()))
		end
	end

	if ((self.radiation or 0) ~= 0 and character.SetRadiation) then
		--[[
			ADDING rads goes through `AddRadiation`, which applies the
			character's resistance. REMOVING them does not: Rad-X reducing what
			you take in is the point of Rad-X, and it must not also reduce what
			RadAway takes out - a well protected character would then find that
			the same dose cleaned less.
		]]
		if (self.radiation > 0) then
			character:AddRadiation(self.radiation)
		else
			character:SetRadiation(
				math.max(character:GetRadiation() + self.radiation, 0))

			if (character.ApplyBodyState) then
				character:ApplyBodyState()
			end
		end
	end

	for _, buff in ipairs(self.buffs or {}) do
		ix.buff.Add(client, buff.stat, buff.value, buff.duration or 0,
			self.aidID and (self.aidID .. "_" .. buff.stat) or nil, self.name)
	end

	--[[
		THE DOSE COMES BEFORE THE ROLL.

		Feeding an existing addiction resets its clock and clears its
		withdrawal; only then does an unaddicted character roll to gain one.
		In the other order, a character who just got hooked would immediately
		have that new addiction "fed", which is harmless, and a character
		already hooked would roll again for something they have, which is not.
	]]
	if (self.addictionName) then
		ix.addiction.Dose(client, self.addictionName)
		ix.addiction.Roll(client, self.addictionName, self.addictionChance or 0)
	end

	if (self.cures) then
		local cured = ix.addiction.Cure(client,
			self.cures ~= true and self.cures or nil)

		client:Notify(cured > 0
			and string.format("Cured %d addiction(s).", cured)
			or "You were not addicted to anything.")
	end

	if (self.effectFunctions and self.effectFunctions.OnConsume) then
		self.effectFunctions.OnConsume(self, client)
	end

	ix.log.Add(client, "aidUsed", self.name)
end

ITEM.functions.Use = {
	name = "use",
	icon = "icon16/pill.png",

	OnRun = function(item)
		local client = item.player
		local ok, reason = item:CanConsume(client)

		if (not ok) then
			client:Notify("You cannot use that - " .. reason .. ".")

			return false
		end

		item:Consume(client)

		return true
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}

--[[
	Using it on somebody else.

	A five-second stared action, the same shape as the food base's Feed: both
	parties have to stand still and either can walk away from it. Phoenix used
	their recognition plugin for the names; that is not ported, so character
	names are used directly.
]]
ITEM.functions.Inject = {
	name = "inject",
	icon = "icon16/user_go.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client) or not client:Alive()) then return false end

		local target = client:GetEyeTrace().Entity

		if (not IsValid(target) or not target:IsPlayer()) then return false end

		local theirCharacter = target:GetCharacter()
		local ourCharacter = client:GetCharacter()

		if (not theirCharacter or not ourCharacter) then return false end

		local ok, reason = item:CanConsume(target)

		if (not ok) then
			client:Notify("They cannot take that - " .. reason .. ".")

			return false
		end

		local verb = item.injectFlavour or "inject"

		target:ChatPrint(string.format("%s is trying to %s you with %s.",
			ourCharacter:GetName(), verb, item.name))
		client:ChatPrint(string.format("You begin %sing %s with %s.",
			verb, theirCharacter:GetName(), item.name))

		client:SetAction(verb .. "ing...", 5)
		client:DoStaredAction(target, function()
			--[[
				Re-checked on completion. Five seconds is long enough for the
				item to have been dropped or used, and for the target to have
				put a suit of power armour on.
			]]
			if (not IsValid(target) or not item:GetOwner()) then return end

			local stillOk = item:CanConsume(target)

			if (not stillOk) then return end

			target:ChatPrint(string.format("You have been %sed with %s.",
				verb, item.name))
			client:ChatPrint(string.format("You %s %s with %s.",
				verb, theirCharacter:GetName(), item.name))

			item:Consume(target)
			item:Remove()
		end, 5, function()
			client:ChatPrint("You stop " .. verb .. "ing.")
		end, 200)

		return false
	end,

	OnCanRun = function(item)
		if (IsValid(item.entity) or not IsValid(item.player)) then return false end

		local target = item.player:GetEyeTrace().Entity

		return IsValid(target) and target:IsPlayer() and target ~= item.player
	end
}

--[[
	The marker that tells two chems on one model apart.

	Twenty-five of the sixty-four share a model with something else - Psycho,
	Psycho-Jet, Psychobuff, Psychotats, Overdrive, Fury and Berserk are all the
	same syringe - and an inventory full of identical icons is unusable. A
	small square of colour in the corner is the least intrusive thing that
	fixes it, and it sits where the armour base already puts its equipped dot
	so the two never overlap.

	The generator refuses to write a roster where two chems share both a model
	and a marker, so the colours cannot silently collide.
]]
if (CLIENT) then
	function ITEM:PaintOver(item, width, height)
		if (not item.tint) then return end

		surface.SetDrawColor(item.tint)
		surface.DrawRect(width - 15, 4, 11, 11)

		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawOutlinedRect(width - 15, 4, 11, 11, 1)
	end
end

if (SERVER) then
	ix.log.AddType("aidUsed", function(client, name)
		return string.format("%s used %s.", client:Name(), name)
	end, FLAG_NORMAL)
end

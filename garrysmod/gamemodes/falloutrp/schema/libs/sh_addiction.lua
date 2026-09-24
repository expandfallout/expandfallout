--[[
	Addiction.

	Phoenix's model, which is a good one: taking a chem rolls against its
	`addictionChance`, and an addiction has a SEVERITY that climbs the longer
	you go without the thing you are addicted to. Each severity applies its own
	withdrawal penalty on top of the last.

	    severity 1   -15 SPD      you feel sluggish
	    severity 2   -30 SPD      you feel fatigued, the screen desaturates
	    severity 3   -45 SPD      severe withdrawal, the screen blurs too

	    -- their sh_aid_jet.lua, addictionEffects[1..3]

	WHAT CLIMBS IT IS TIME SINCE THE LAST DOSE, not time since the addiction.
	Taking the chem resets the clock, which is the whole shape of the thing: an
	addiction costs you nothing at all as long as you keep feeding it, and
	everything the moment you cannot.

	TWO KINDS OF ADDICTION. `timedClear` addictions burn out on their own once
	you have gone long enough without; the others do not, and have to be cured
	with Addictol or Fixer. Phoenix carry the same flag and Buffout is their
	example of the first, Jet of the second.

	WHAT IS STORED, AND WHERE. The addiction lives on the CHARACTER, because it
	has to survive a restart - an addiction you can log out of is not one. The
	withdrawal PENALTIES live in `ix.buff` and are runtime only, rebuilt from
	the addiction whenever it changes or the character spawns. So there is one
	durable fact and one derived consequence, rather than two copies of the
	same thing drifting apart.
]]

ix.addiction = ix.addiction or {}

--- Registered addictions, keyed by name, filled in by the aid items.
ix.addiction.list = ix.addiction.list or {}

--[[
	The most severe an addiction gets.

	Three, matching Phoenix. A fourth tier exists in their base's comment block
	but no item they shipped defines one, and a penalty nothing can reach is
	not a feature.
]]
ix.addiction.maxSeverity = 3

ix.config.Add("addictionEnabled", true,
	"Whether chems can cause addiction at all.", nil, {
	category = "Chems"
})

ix.config.Add("addictionSpeed", 1,
	"Multiplier on how fast withdrawal severity climbs. Higher is faster.",
	nil, {data = {min = 0.1, max = 10}, category = "Chems"})

--[[
	Register what an addiction does.

	Called by every aid item that can cause one, at load. The item is the
	natural place for it - the withdrawal from Jet is a fact about Jet - and
	registering it centrally means the cure items, the HUD and the report can
	all ask about an addiction without knowing which item made it.
]]
function ix.addiction.Register(data)
	if (not data or not data.name) then return end

	ix.addiction.list[data.name] = {
		name = data.name,
		--- What the player sees. Defaults to the addiction's own name.
		label = data.label or data.name,
		--- Seconds without a dose before severity climbs one step.
		interval = math.max(data.interval or 600, 1),
		--- Whether it burns out on its own, or needs curing.
		timedClear = data.timedClear ~= false,
		--[[
			The withdrawal penalty per severity step, as buff stats. Applied
			CUMULATIVELY: at severity 3 the player carries the entries for 1, 2
			and 3 at once, which is how Phoenix's -15/-30/-45 comes out of
			three identical -15 steps.
		]]
		effects = data.effects or {},
		--- What the player is told at each step.
		messages = data.messages or {},
		--[[
			What the screen does at each step, as effect names from
			`ix.chemfx.renderers`. Absent means the default set, which is
			Phoenix's: nothing, then desaturation, then motion blur on top.

			Per addiction rather than by severity alone because withdrawal
			from Cateye should hurt your eyes and withdrawal from Psycho
			should not - one rule for everything is one look for everything.
		]]
		screen = data.screen,
		--- The item that causes it, so a report can point at something.
		source = data.source
	}
end

function ix.addiction.Get(name)
	return ix.addiction.list[name]
end

--- Every registered addiction name, sorted.
function ix.addiction.GetNames()
	local names = {}

	for name in pairs(ix.addiction.list) do
		names[#names + 1] = name
	end

	table.sort(names)

	return names
end

--------------------------------------------------------------------------------
-- What a character is addicted to
--------------------------------------------------------------------------------

local characterMeta = ix.meta.character

--[[
	`{[name] = {severity = 1-3, lastDose = os.time()}}`.

	`os.time` rather than `CurTime`, deliberately: `CurTime` restarts with the
	map, so an addiction stored against it would reset its own clock every time
	the server did. Withdrawal is meant to be something you carry.
]]
function characterMeta:GetAddictions()
	return self:GetData("addictions", {})
end

function characterMeta:IsAddictedTo(name)
	local addictions = self:GetAddictions()

	return addictions[name] ~= nil
end

function characterMeta:GetAddictionSeverity(name)
	local addiction = self:GetAddictions()[name]

	return addiction and addiction.severity or 0
end

--- How many separate things this character is hooked on.
function characterMeta:GetAddictionCount()
	local count = 0

	for _ in pairs(self:GetAddictions()) do
		count = count + 1
	end

	return count
end

--[[
	Seconds since the last dose of one thing.

	Answers 0 for something the character is not addicted to, which reads the
	same as "just took some" and is the right answer for every caller: neither
	is withdrawing.
]]
function characterMeta:GetTimeSinceDose(name)
	local addiction = self:GetAddictions()[name]

	if (not addiction) then return 0 end

	return math.max(os.time() - (addiction.lastDose or os.time()), 0)
end

--[[
	The severity this addiction SHOULD be at, from the clock.

	Kept as a calculation rather than a stored countdown so that time passing
	while the server is off still counts. A player who logs out in withdrawal
	and comes back a day later comes back worse, not frozen.
]]
function ix.addiction.GetExpectedSeverity(character, name)
	local data = ix.addiction.Get(name)
	local addiction = character:GetAddictions()[name]

	if (not data or not addiction) then return 0 end

	local elapsed = character:GetTimeSinceDose(name)
	local interval = data.interval / math.max(ix.config.Get("addictionSpeed", 1), 0.1)
	local steps = math.floor(elapsed / interval)

	--[[
		A timed-clear addiction that has gone a full step PAST the top is over;
		the caller reads the -1 as "cure it". One that has to be cured stops
		climbing at the top and stays there.
	]]
	if (data.timedClear and steps > ix.addiction.maxSeverity) then
		return -1
	end

	return math.Clamp(steps, 0, ix.addiction.maxSeverity)
end

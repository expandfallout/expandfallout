--[[
	Addiction - the server half.

	Three things happen here: a chem rolls whether it hooks you, a clock turns
	that into a severity, and the severity becomes buffs.

	THE BUFFS ARE REBUILT, NEVER ADJUSTED. Every time anything changes, every
	withdrawal buff this character holds is cleared and the whole set is
	applied again from the current severity. Phoenix's version adds and removes
	individual buffs as severity moves, and their `onClearAddiction` has to
	unwind exactly what was applied - three branches, each removing a different
	total, and any mismatch leaves a permanent penalty that nothing can find.

	Rebuilding cannot drift. The buffs are derived data; the addiction is the
	fact. There is one function that turns one into the other and it is the
	only thing that writes withdrawal buffs.
]]

if (not SERVER) then return end

util.AddNetworkString("ixAddictionSync")
util.AddNetworkString("ixChemIntake")

--[[
	How often the clock is checked.

	Severity climbs on the order of ten minutes, so a fifteen second tick is
	already far finer than it needs to be and costs a table walk per player.
]]
local TICK = 15

--- The buff id a withdrawal step uses, so the rebuild can find its own work.
local function BuffID(name, index, stat)
	return string.format("wd_%s_%d_%s", name, index, stat)
end

--[[
	Clear every withdrawal buff, then apply what the current severities say.

	`ix.buff.Clear` is not used because it would take the chem buffs with it -
	a player can be high on Jet and withdrawing from Psycho at the same time,
	and curing one must not cancel the other.
]]
function ix.addiction.ApplyEffects(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	--[[
		Removed by id rather than by clearing everything, so this only ever
		touches buffs it put there itself. The ids are built from the same
		function that made them, so nothing has to be remembered between calls.
	]]
	for name, data in pairs(ix.addiction.list) do
		for index = 1, ix.addiction.maxSeverity do
			for _, effect in ipairs(data.effects[index] or {}) do
				ix.buff.Remove(client, BuffID(name, index, effect.stat))
			end
		end
	end

	for name, addiction in pairs(character:GetAddictions()) do
		local data = ix.addiction.Get(name)

		if (data) then
			--[[
				CUMULATIVE. Severity 3 carries the effects of 1 and 2 as well,
				which is how three identical -15 Speed steps become the -45
				Phoenix's Jet describes.
			]]
			for index = 1, math.min(addiction.severity or 0, ix.addiction.maxSeverity) do
				for _, effect in ipairs(data.effects[index] or {}) do
					ix.buff.Add(client, effect.stat, effect.value, 0,
						BuffID(name, index, effect.stat),
						data.label .. " withdrawal")
				end
			end
		end
	end
end

--- Tell the client what it is addicted to, for the HUD.
function ix.addiction.Sync(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local list = {}

	for name, addiction in pairs(character:GetAddictions()) do
		local data = ix.addiction.Get(name)

		if (data) then
			list[#list + 1] = {
				name = name,
				label = data.label,
				severity = addiction.severity or 0
			}
		end
	end

	table.sort(list, function(a, b)
		if (a.severity ~= b.severity) then return a.severity > b.severity end

		return a.label < b.label
	end)

	net.Start("ixAddictionSync")
		net.WriteUInt(#list, 8)

		for _, entry in ipairs(list) do
			net.WriteString(entry.name)
			net.WriteString(entry.label)
			net.WriteUInt(entry.severity, 4)
		end
	net.Send(client)
end

local function Commit(character, addictions)
	character:SetData("addictions", addictions)

	local client = character:GetPlayer()

	if (IsValid(client)) then
		ix.addiction.ApplyEffects(client)
		ix.addiction.Sync(client)
	end
end

--[[
	Take a dose of something you may or may not already be hooked on.

	Called by the aid base on every use of an addictive chem, whether or not
	the roll succeeds - because a dose RESETS THE CLOCK even when it does not
	cause a new addiction, and that is the mechanic. Feeding an addiction is
	how you keep it from hurting.
]]
function ix.addiction.Dose(client, name)
	if (not IsValid(client)) then return false end

	local character = client:GetCharacter()
	local data = ix.addiction.Get(name)

	if (not character or not data) then return false end

	local addictions = character:GetAddictions()
	local existing = addictions[name]

	if (existing) then
		--[[
			A dose clears the withdrawal entirely rather than stepping it down
			one. That is what taking the drug does: you stop being in
			withdrawal, you do not become slightly less withdrawn.
		]]
		existing.lastDose = os.time()
		existing.severity = 0

		Commit(character, addictions)

		return false
	end

	return false
end

--[[
	Roll for a new addiction.

	Separate from `Dose` because the two answer different questions and the
	item calls both: the dose always happens, the hook only sometimes. Returns
	whether it took, so the item can say so.
]]
function ix.addiction.Roll(client, name, chance)
	if (not IsValid(client)) then return false end
	if (not ix.config.Get("addictionEnabled", true)) then return false end

	local character = client:GetCharacter()
	local data = ix.addiction.Get(name)

	if (not character or not data) then return false end

	local addictions = character:GetAddictions()

	-- Already hooked: the dose has already reset the clock, nothing to roll.
	if (addictions[name]) then return false end

	--[[
		Endurance resists it.

		A tough character shrugging off a chem is the obvious use for the
		attribute, it gives Endurance a second job beyond stamina, and it means
		the same chem is a different decision for different characters. Ten
		Endurance halves the chance; it never reaches zero.
	]]
	local endurance = ix.special and ix.special.Get(character, "endurance") or 0
	local resisted = chance * (1 - math.Clamp(endurance, 0, 10) * 0.05)

	if (math.random() * 100 > resisted) then return false end

	addictions[name] = {severity = 0, lastDose = os.time()}

	Commit(character, addictions)

	client:Notify("You have become addicted to " .. data.label .. ".")
	ix.log.Add(client, "addictionGained", data.label)

	return true
end

--[[
	Cure one addiction, or all of them.

	`name` nil means everything, which is what Addictol does. Returns how many
	were cured so the item can refuse to be used for nothing.
]]
function ix.addiction.Cure(client, name)
	if (not IsValid(client)) then return 0 end

	local character = client:GetCharacter()

	if (not character) then return 0 end

	local addictions = character:GetAddictions()
	local cured = 0

	for key in pairs(addictions) do
		if (not name or key == name) then
			addictions[key] = nil
			cured = cured + 1
		end
	end

	if (cured > 0) then
		Commit(character, addictions)
	end

	return cured
end

--[[
	Advance the clock.

	The severity is CALCULATED from the time of the last dose rather than
	counted up, so time that passed while the server was down still counts -
	see `GetExpectedSeverity`. This loop only notices when the answer has
	changed and tells the player about it.
]]
local function Tick()
	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if (not character) then continue end

		local addictions = character:GetAddictions()
		local changed = false

		for name, addiction in pairs(addictions) do
			local data = ix.addiction.Get(name)

			if (not data) then continue end

			local expected = ix.addiction.GetExpectedSeverity(character, name)

			if (expected < 0) then
				--[[
					Burned out. Only the `timedClear` addictions ever return
					this; the rest sit at maximum severity until cured.
				]]
				addictions[name] = nil
				changed = true

				client:Notify("Your " .. data.label ..
					" addiction has passed.")
			elseif (expected > (addiction.severity or 0)) then
				addiction.severity = expected
				changed = true

				local message = data.messages[expected]

				if (message) then
					client:Notify(message)
				end
			end
		end

		if (changed) then
			Commit(character, addictions)
		end
	end
end

timer.Create("ixAddictionTick", TICK, 0, Tick)

--[[
	Withdrawal comes back with the character.

	The addiction is stored; its buffs are not. Without this a player would
	reconnect free of every penalty they had earned, which is the one thing an
	addiction must not let you do.
]]
hook.Add("PlayerLoadedCharacter", "ixAddiction", function(client)
	timer.Simple(1, function()
		if (not IsValid(client)) then return end

		ix.addiction.ApplyEffects(client)
		ix.addiction.Sync(client)
	end)
end)

--[[
	And with a respawn.

	`PlayerDeath` clears every buff, withdrawal included - the penalties are
	re-derived here rather than being spared there, because "buffs die with
	you" is a rule worth keeping simple and this is the one exception to it.
]]
hook.Add("PlayerSpawn", "ixAddiction", function(client)
	timer.Simple(0.5, function()
		if (not IsValid(client)) then return end

		ix.addiction.ApplyEffects(client)
		ix.addiction.Sync(client)
	end)
end)

ix.log.AddType("addictionGained", function(client, label)
	return string.format("%s became addicted to %s.", client:Name(), label)
end, FLAG_NORMAL)

concommand.Add("fo_addictions", function(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local addictions = character:GetAddictions()
	local count = 0

	for name, addiction in pairs(addictions) do
		local data = ix.addiction.Get(name)

		count = count + 1

		client:ChatPrint(string.format("%s - severity %d/%d, %ds since a dose%s",
			data and data.label or name, addiction.severity or 0,
			ix.addiction.maxSeverity, character:GetTimeSinceDose(name),
			data and not data.timedClear and " (needs curing)" or ""))
	end

	if (count == 0) then
		client:ChatPrint("You are not addicted to anything.")
	end
end)

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]

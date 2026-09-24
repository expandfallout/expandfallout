--[[
	Timed stat modifiers.

	Chems are the reason this exists, but nothing here knows what a chem is. A
	buff is a named amount of a named stat, for a length of time, and every
	system that already answers "how fast, how tough, how strong" asks this
	library whether anything is adding to its answer.

	Phoenix's `nut.buffs` is the model. Their items call it as

	    nut.buffs:add(client, "SPD", 30, 60, "DRUG SPD")

	and their whole chem roster is written against thirteen stat names, which
	are the thirteen here.

	WHY A SEPARATE LIBRARY RATHER THAN A FIELD ON THE CHARACTER.

	Three systems already modify SPECIAL - radiation, hunger, armour - and each
	does it at the point `ix.special.Get` collects modifiers. A fourth needs to
	join that chain rather than fight it, and a chem's +2 Strength has to
	expire on its own without anybody remembering to take it off. A buff is the
	only one of these that has an end time, so it needs somewhere to keep one.

	RUNTIME ONLY, DELIBERATELY. Buffs live on the player and die with the
	session. A chem you took twenty minutes before a server restart should not
	still be running afterwards, and reconnecting to reset a two-minute timer
	is not an exploit worth the storage. Withdrawal penalties are the exception
	and they are not stored here either: `ix.addiction` holds the addiction on
	the CHARACTER and re-applies its penalties on spawn, so the durable thing
	is the addiction rather than its symptom.
]]

ix.buff = ix.buff or {}

--[[
	The stats a buff can name.

	`apply` says who reads it, purely as documentation for the next person
	wondering why a number they set does nothing - the consumers are elsewhere
	and each one calls `ix.buff.Get` itself.
]]
ix.buff.stats = {
	SPD = {name = "Speed", suffix = "", apply = "run and walk speed"},
	HP = {name = "Max Health", suffix = "", apply = "maximum health"},
	DR = {name = "Damage Resistance", suffix = "%", apply = "incoming damage"},
	DMG = {name = "Damage", suffix = "%", apply = "outgoing damage"},
	--[[
		The one buff whose VALUE does not matter. Any positive amount means
		"you can cloak"; it is a buff rather than a flag so that it expires by
		itself. Read by `ix.armor.CanStealth`.
	]]
	STEALTH = {name = "Stealth Field", suffix = "", apply = "the ability to cloak"},
	RADRES = {name = "Rad Resistance", suffix = "%", apply = "radiation taken"},

	--[[
		SPECIAL, under the short names Phoenix's items use. They resolve to the
		attribute keys through `ix.buff.specialKeys` rather than being those
		keys, because "STR" is what a chem's description says and `strength` is
		what the attribute is called.
	]]
	STR = {name = "Strength", suffix = "", apply = "SPECIAL"},
	PER = {name = "Perception", suffix = "", apply = "SPECIAL"},
	END = {name = "Endurance", suffix = "", apply = "SPECIAL"},
	CHR = {name = "Charisma", suffix = "", apply = "SPECIAL"},
	INT = {name = "Intelligence", suffix = "", apply = "SPECIAL"},
	AGL = {name = "Agility", suffix = "", apply = "SPECIAL"},
	LCK = {name = "Luck", suffix = "", apply = "SPECIAL"}
}

--- Short buff name to the attribute key `ix.special.Get` uses.
ix.buff.specialKeys = {
	STR = "strength",
	PER = "perception",
	END = "endurance",
	CHR = "charisma",
	INT = "intelligence",
	AGL = "agility",
	LCK = "luck"
}

--- The reverse, so `ix.special.Get` can ask what buffs a key has.
ix.buff.specialStats = {}

for short, key in pairs(ix.buff.specialKeys) do
	ix.buff.specialStats[key] = short
end

ix.config.Add("buffHUD", true,
	"Whether active buffs are listed on the HUD.", nil, {
	category = "Chems"
})

--[[
	Read the total for one stat.

	Sums every live buff of that name. Nothing is clamped here - a -45 Speed
	from three tiers of Jet withdrawal is a real number and the consumer is the
	only thing that knows what its own floor is. `ix.special.Apply` will not let
	run speed reach zero; `ix.special.Get` will not let an attribute go
	negative. This just adds up.

	Shared because the client needs the same answer for the HUD, and reading a
	number two different ways is how the two disagree.
]]
function ix.buff.Get(client, stat)
	if (not IsValid(client)) then return 0 end

	local list = client.ixBuffs

	if (not list) then return 0 end

	local total = 0
	local now = CurTime()

	for _, buff in pairs(list) do
		if (buff.stat == stat and (buff.endTime == 0 or buff.endTime > now)) then
			total = total + buff.value
		end
	end

	return total
end

--- Whether a buff with this id is running. Used to refuse a second dose.
function ix.buff.Has(client, id)
	if (not IsValid(client) or not id or not client.ixBuffs) then return false end

	local buff = client.ixBuffs[id]

	return buff ~= nil and (buff.endTime == 0 or buff.endTime > CurTime())
end

--- Seconds left on a buff, or 0 for one that does not expire.
function ix.buff.GetRemaining(client, id)
	if (not IsValid(client) or not client.ixBuffs) then return 0 end

	local buff = client.ixBuffs[id]

	if (not buff or buff.endTime == 0) then return 0 end

	return math.max(buff.endTime - CurTime(), 0)
end

--[[
	Everything currently running, sorted for display.

	Permanent buffs first and timed ones after, because the permanent ones are
	withdrawal penalties and a player wants those where they do not move. Timed
	buffs sort by what is about to run out.
]]
function ix.buff.GetAll(client)
	local out = {}

	if (not IsValid(client) or not client.ixBuffs) then return out end

	local now = CurTime()

	for id, buff in pairs(client.ixBuffs) do
		if (buff.endTime == 0 or buff.endTime > now) then
			out[#out + 1] = {
				id = id,
				stat = buff.stat,
				value = buff.value,
				endTime = buff.endTime,
				label = buff.label
			}
		end
	end

	table.sort(out, function(a, b)
		if ((a.endTime == 0) ~= (b.endTime == 0)) then
			return a.endTime == 0
		end

		if (a.endTime ~= b.endTime) then
			return a.endTime < b.endTime
		end

		return a.id < b.id
	end)

	return out
end

--[[
	Seconds as words.

	Written here rather than using `ix.util.GetStringTime`, which is a PARSER
	and not a formatter - it turns "5m" into seconds, and given a plain number
	it MULTIPLIES BY 60. Med-X's 240 second buff came out of it as "14400",
	which is what four minutes looks like when you ask a parser to format.
]]
function ix.buff.FormatDuration(seconds)
	seconds = math.max(math.Round(tonumber(seconds) or 0), 0)

	if (seconds < 60) then
		return string.format("%d second%s", seconds, seconds == 1 and "" or "s")
	end

	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	local text = string.format("%d minute%s", minutes, minutes == 1 and "" or "s")

	if (rest > 0) then
		text = text .. string.format(" %d second%s", rest, rest == 1 and "" or "s")
	end

	return text
end

--- "+30 SPD" / "-15 SPD", the way the chem descriptions are written.
function ix.buff.Describe(stat, value)
	local info = ix.buff.stats[stat]

	return string.format("%s%d%s %s", value >= 0 and "+" or "", value,
		info and info.suffix or "", stat)
end

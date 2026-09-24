--[[
	Implants: permanent SPECIAL, put in by somebody else.

	Phoenix's `implants` plugin, and its two good ideas kept:

	    YOU CANNOT IMPLANT YOURSELF. The item's Use traces at whoever you are
	    looking at, so every implant in the wasteland went in because another
	    character stood still for five seconds and did it. That is a scene, and
	    it is the whole reason implants are interesting rather than a stat
	    upgrade you buy.

	    THEY SURVIVE DEATH. An implant is inside you; dying does not take it
	    out. Only a PERMANENT KILL does, and the extractor - which is another
	    person, again.

	WHAT AN IMPLANT IS, here: an id on the character (`ix.implants.Of`) and a
	set of bonuses this file knows about. The item is only how it gets there,
	which is why the numbers are edited in `/liveedit` rather than in nine item
	files - see `ix.implants.list` below and the IMPLANTS section of the editor.

	THE BONUSES ARE THE SAME LANGUAGE CHEMS USE: `ix.buff`'s stat codes, so
	`STR` is Strength and `HP` is maximum health, and everything that already
	reads a buff reads an implant without knowing what one is.
]]

ix.implants = ix.implants or {}

--[[
	Every implant in the wasteland.

	NO NUMBERS IN THE DESCRIPTIONS. They used to read "Grants +5 Strength",
	which is a second copy of `buffs` written in English - so an implant edited
	down to +3 in `/liveedit` still promised five on its own tooltip, and the
	tooltip said it twice. The item lists the real bonuses underneath; the
	description is for what the thing IS.

	`buffs` is `[code] = amount`, applied while the implant is in and taken out
	with it. `faction` locks one to a single faction - the C.I.T implant is the
	only one, and it is a whole story about what happens when somebody else
	tries.
]]
ix.implants.list = ix.implants.list or {
	strength = {
		name = "Strength Implant",
		description = "A cybernetic implant, wired into the muscle.",
		buffs = {STR = 5}
	},

	perception = {
		name = "Perception Implant",
		description = "A cybernetic implant, threaded behind the eyes.",
		buffs = {PER = 5}
	},

	endurance = {
		name = "Endurance Implant",
		description = "A cybernetic implant that reinforces the body.",
		buffs = {END = 5}
	},

	charisma = {
		name = "Charisma Implant",
		description = "A cybernetic implant that smooths the voice.",
		buffs = {CHR = 5}
	},

	intelligence = {
		name = "Intelligence Implant",
		description = "A cybernetic implant, seated against the skull.",
		buffs = {INT = 5}
	},

	agility = {
		name = "Agility Implant",
		description = "A cybernetic implant spliced into the nerves.",
		buffs = {AGL = 5}
	},

	luck = {
		name = "Luck Implant",
		description = "A cybernetic implant nobody can quite explain.",
		buffs = {LCK = 5}
	},

	synth = {
		name = "FEV Experimental Implant",
		description = "Experimental gene-work. It was not made for you.",
		buffs = {END = 5, HP = 40}
	},

	cit_implant = {
		name = "C.I.T Implant",
		description = "Embedded in synths, and linked to C.I.T systems.",
		buffs = {END = 5, HP = 40},

		--[[
			ONLY C.I.T MAY HANDLE IT. Anybody else who tries is burned putting
			it in and has it detonate coming out - Phoenix's rule, kept,
			because it is what makes a synth implant a thing worth having and a
			thing worth fearing.
		]]
		faction = "cit",
		volatile = true
	}
}

ix.config.Add("implantMax", 3, "How many implants one character may carry.",
	nil, {data = {min = 0, max = 20}, category = "Implants"})

ix.config.Add("implantTime", 5,
	"Seconds of standing still to put an implant in or take one out.", nil, {
	data = {min = 0, max = 60}, category = "Implants"})

ix.config.Add("implantRange", 96,
	"How close you must be to implant somebody.", nil, {
	data = {min = 32, max = 256}, category = "Implants"})

--- One implant's definition, or nil.
function ix.implants.Get(id)
	return ix.implants.list[id]
end

--[[
	What a character is carrying, as `[id] = true`.

	Never nil and never the stored table - a caller counting these must not be
	able to add one by accident.
]]
function ix.implants.Of(character)
	if (not character) then return {} end

	local stored = character:GetData("implants")

	return istable(stored) and table.Copy(stored) or {}
end

function ix.implants.Has(character, id)
	return ix.implants.Of(character)[id] == true
end

function ix.implants.Count(character)
	return table.Count(ix.implants.Of(character))
end

--[[
	Whether this implant could go into this character. `true`, or a reason.

	Shared, so the item can grey itself out and the server can refuse - the
	same rule asked twice rather than two rules that agree today.
]]
function ix.implants.CanTake(character, id)
	local implant = ix.implants.Get(id)

	if (not implant) then return false, "That is not an implant." end

	if (ix.implants.Has(character, id)) then
		return false, "They already have that implant."
	end

	local maximum = ix.config.Get("implantMax", 3)

	if (ix.implants.Count(character) >= maximum) then
		return false, string.format("They already carry %d implants.", maximum)
	end

	return true
end

--- Every bonus from every implant a character has, as `[code] = total`.
function ix.implants.Bonuses(character)
	local out = {}

	for id in pairs(ix.implants.Of(character)) do
		local implant = ix.implants.Get(id)

		if (not implant) then continue end

		for code, amount in pairs(implant.buffs or {}) do
			out[code] = (out[code] or 0) + amount
		end
	end

	return out
end

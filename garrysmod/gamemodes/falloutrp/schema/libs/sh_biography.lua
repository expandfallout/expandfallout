--[[
	Height, weight and age.

	These are part of a character's description, and they are FORCED into it in
	a fixed format:

	    6ft 5in | 120lbs | 18 | A wastelander that is awesome!

	Stored as three separate character vars as well as being composed into the
	description string. The description is what a player reads; the separate
	vars are what code reads - they are going on the HUD when you look at
	someone, and parsing them back out of a free-text field would be fragile the
	moment somebody types a pipe character.

	They do not change after creation. Altering them is a player-kill concern,
	which is a separate system and deliberately not handled here.
]]

ix.fallout = ix.fallout or {}

--[[
	Ranges.

	The age minimum is a rule rather than a technical limit, so it is a config
	an admin can move. The rest are sanity bounds: wide enough not to argue with
	a character concept, narrow enough that the value is still a person.
]]
ix.config.Add("minimumAge", 18, "The youngest a character may be created.", nil, {
	data = {min = 1, max = 100},
	category = "Characters"
})

ix.fallout.MAX_AGE = 90

-- Inches. 5ft to 7ft.
ix.fallout.MIN_HEIGHT = 60
ix.fallout.MAX_HEIGHT = 84

-- Pounds.
ix.fallout.MIN_WEIGHT = 100
ix.fallout.MAX_WEIGHT = 350

--------------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------------

--[[
	Height is stored in INCHES and displayed as feet and inches.

	One number is far easier to validate, clamp and compare than a pair, and
	feet-and-inches is only ever a presentation detail.
]]
function ix.fallout.FormatHeight(inches)
	inches = math.Clamp(math.floor(tonumber(inches) or ix.fallout.MIN_HEIGHT),
		ix.fallout.MIN_HEIGHT, ix.fallout.MAX_HEIGHT)

	return string.format("%dft %din", math.floor(inches / 12), inches % 12)
end

function ix.fallout.FormatWeight(pounds)
	return string.format("%dlbs", math.floor(tonumber(pounds) or 0))
end

--[[
	The forced description line.

	`text` is whatever the player wrote. The three values are prefixed, pipe
	separated, in a fixed order - so anything reading a description knows where
	to look, and every character reads the same way.
]]
function ix.fallout.FormatDescription(height, weight, age, text)
	return string.format("%s | %s | %d | %s",
		ix.fallout.FormatHeight(height),
		ix.fallout.FormatWeight(weight),
		math.floor(tonumber(age) or 0),
		tostring(text or ""))
end

--------------------------------------------------------------------------------
-- Character vars
--------------------------------------------------------------------------------

--[[
	`category = "description"` puts these on the description step, where Helix
	builds a panel for every var that has an `OnDisplay`.

	`index` decides both the display order within the category and the order
	validation runs in. These sit at 20+, clear of everything Helix declares -
	its own go up to 4, and vars registered without one are numbered from the
	table count as it grows, which already produces duplicates (`class` and
	`attributes` are both 4). Sharing a number would leave the order between
	them undefined.

	NOTHING IS SEEDED INTO THE PAYLOAD. The boxes start empty and stay unset
	until the player types, so an unanswered field is a rejection rather than a
	default nobody chose. `OnValidate` is what turns that into a message.
]]
local function BuildEntry(class, key, setup)
	return function(self, container, payload)
		local panel = container:Add(class)

		panel:Dock(TOP)
		panel:SetTall(math.Round(30 * ix.fallout.GetFontScale()))
		panel:DockMargin(0, 0, 0, math.Round(4 * ix.fallout.GetFontScale()))

		setup(panel)

		-- Repopulating returns here with whatever was already entered.
		panel:SetValue(payload[key])

		panel.OnChanged = function(_, value)
			payload:Set(key, value)
		end

		return panel
	end
end

--[[
	Height, in inches.

	Entered as feet and inches - nobody gives their height in inches - but
	stored as a single number, which is far easier to clamp and compare.
]]
ix.char.RegisterVar("height", {
	field = "height",
	fieldType = ix.type.number,
	default = 70,
	index = 20,
	category = "description",

	OnValidate = function(self, value, payload, client)
		value = tonumber(value)

		--[[
			No L() here. `OnValidate` runs on the SERVER as well, where the
			signature is `L(key, client, ...)` - and the fault travels to the
			client as a KEY to be translated there, so translating it early would
			be wrong even if it worked.
		]]
		if (not value) then
			return false, "heightRequired"
		end

		value = math.floor(value)

		if (value < ix.fallout.MIN_HEIGHT or value > ix.fallout.MAX_HEIGHT) then
			return false, "heightRange",
				ix.fallout.FormatHeight(ix.fallout.MIN_HEIGHT),
				ix.fallout.FormatHeight(ix.fallout.MAX_HEIGHT)
		end

		return value
	end,

	OnDisplay = BuildEntry("ixFOHeightEntry", "height", function(panel)
		panel:SetFeetRange(math.floor(ix.fallout.MIN_HEIGHT / 12),
			math.floor(ix.fallout.MAX_HEIGHT / 12))
	end)
})

ix.char.RegisterVar("weight", {
	field = "weight",
	fieldType = ix.type.number,
	default = 160,
	index = 21,
	category = "description",

	OnValidate = function(self, value, payload, client)
		value = tonumber(value)

		if (not value) then
			return false, "weightRequired"
		end

		value = math.floor(value)

		if (value < ix.fallout.MIN_WEIGHT or value > ix.fallout.MAX_WEIGHT) then
			return false, "weightRange", ix.fallout.MIN_WEIGHT, ix.fallout.MAX_WEIGHT
		end

		return value
	end,

	OnDisplay = BuildEntry("ixFONumberEntry", "weight", function(panel)
		panel:SetSuffix("lbs")
		panel:SetMin(ix.fallout.MIN_WEIGHT)
		panel:SetMax(ix.fallout.MAX_WEIGHT)
	end)
})

ix.char.RegisterVar("age", {
	field = "age",
	fieldType = ix.type.number,
	default = 18,
	index = 22,
	category = "description",

	--[[
		The minimum is checked HERE, on the server, not only in the widget. The
		widget clamps for convenience; this is the rule, and a payload can be
		sent by anything.
	]]
	OnValidate = function(self, value, payload, client)
		local minimum = ix.config.Get("minimumAge", 18)

		value = tonumber(value)

		if (not value) then
			return false, "ageRequired"
		end

		value = math.floor(value)

		if (value < minimum) then
			return false, "ageTooYoung", minimum
		end

		if (value > ix.fallout.MAX_AGE) then
			return false, "ageTooOld", ix.fallout.MAX_AGE
		end

		return value
	end,

	OnDisplay = BuildEntry("ixFONumberEntry", "age", function(panel)
		panel:SetSuffix("years")
		panel:SetMin(ix.config.Get("minimumAge", 18))
		panel:SetMax(ix.fallout.MAX_AGE)
	end)
})

--------------------------------------------------------------------------------
-- Forcing the description
--------------------------------------------------------------------------------

if (SERVER) then
	--[[
		`AdjustCreationPayload` is Helix's own hook for exactly this: it runs
		after every var has validated and before `ix.char.Create`, and whatever
		is written into `newPayload` is merged over the payload.

		Composing here rather than in the description var's own `OnValidate`
		means the values are already validated and clamped - the description
		cannot be built out of an age that was about to be rejected.
	]]
	hook.Add("AdjustCreationPayload", "ixFalloutBiography", function(client, payload, newPayload)
		newPayload.description = ix.fallout.FormatDescription(
			payload.height, payload.weight, payload.age, payload.description)
	end)
end

--[[
	The YOU tab, with everything this schema keeps on a character.

	Helix's own panel lists faction, class, money and the attribute bars, which
	is what a stock Helix character HAS. This schema added level and experience,
	karma, radiation, hunger and thirst, a race and a height and weight - and
	none of it was anywhere in the menu, so the one place a player looks to find
	out about their own character was the least informative screen in the game.

	`CreateCharacterInfo` and `UpdateCharacterInfo` are Helix's own hooks for
	exactly this, and `ixListRow` is the panel its own three rows use - so these
	sit in the list looking like they were always there, and nothing about
	Helix's panel is replaced.

	ROWS ARE MADE ONCE AND UPDATED, which is what the two hooks are for: the
	update runs every time the tab is opened and on every change, and rebuilding
	the rows there would leak a panel per open.
]]

if (not CLIENT) then return end

local rows = {}

--[[
	One row, remembered by name.

	`SetList` is what gives a row the alternating background Helix's own rows
	have; without it the row draws on nothing and the list looks like it has a
	hole in it.
]]
local function Row(panel, id)
	if (IsValid(rows[id])) then return rows[id] end

	local row = panel:Add("ixListRow")

	row:SetList(panel.list)
	row:Dock(TOP)

	rows[id] = row

	return row
end

hook.Add("CreateCharacterInfo", "ixCharInfo", function(panel)
	--[[
		Cleared rather than reused across panels. The information tab is
		rebuilt whenever the menu is created, so a row remembered from the last
		one is a dead panel - `IsValid` in `Row` catches it, but only if this
		table is not holding the stale entries from two menus ago.
	]]
	rows = {}

	for _, id in ipairs({"race", "level", "karma", "radiation", "hunger",
		"biography"}) do
		Row(panel, id)
	end
end)

hook.Add("UpdateCharacterInfo", "ixCharInfo", function(panel, character)
	if (not character) then return end

	local function Set(id, label, text)
		local row = rows[id]

		if (not IsValid(row)) then return end

		--- A row with nothing to say is hidden rather than left blank.
		if (not text) then
			row:SetVisible(false)

			return
		end

		row:SetVisible(true)
		row:SetLabelText(label)
		row:SetText(text)
		row:SizeToContents()
	end

	local race = ix.races and ix.races.Get(character:GetRace())

	Set("race", "Race", race and race.name or nil)

	if (character.GetLevel) then
		local earned, needed = ix.leveling.GetProgress(character)

		Set("level", "Level", string.format("%d   (%d / %d XP)",
			character:GetLevel(), earned, needed))
	end

	--[[
		KARMA, WHICH IS THE ONE THING NOBODY COULD SEE ABOUT THEMSELVES.

		The title under somebody's name is deliberately vague and gated on
		recognition, and `/karma` is a command nobody knows to type - so a
		player had no way at all of finding out what they had become. Their own
		numbers are their own business to read.
	]]
	if (ix.karma and ix.config.Get("karmaEnabled", true)) then
		local good, bad = ix.karma.Of(character)

		if (good + bad > 0) then
			local title, level = ix.karma.Describe(good, bad)

			Set("karma", "Karma", string.format("%s   -   level %d, %d good, "
				.. "%d bad", title, level, good, bad))
		else
			Set("karma", "Karma", "Nothing yet")
		end
	else
		Set("karma", "Karma", nil)
	end

	if (character.GetRadiation) then
		local rads = math.Round(character:GetRadiation())
		local resistance = character.GetRadiationResistance
			and math.Round(character:GetRadiationResistance()) or 0

		Set("radiation", "Radiation", string.format("%d rads   (%d%% "
			.. "resistance)", rads, resistance))
	end

	if (character.GetHunger) then
		--[[
			`character.GetThirst`, with a DOT. `character:GetThirst` is method
			CALL syntax and Lua will not accept it as a value - it is a syntax
			error at load, which took the whole schema down with it. The colon
			is only ever for calling.
		]]
		local thirst = character.GetThirst and character:GetThirst() or 0

		Set("hunger", "Hunger / Thirst", string.format("%d%% / %d%%",
			math.Round(character:GetHunger()), math.Round(thirst)))
	end

	--[[
		Height, weight and age together on one line: three rows for three
		numbers nobody reads separately is three rows of scrolling.
	]]
	if (character.GetHeight) then
		Set("biography", "Height / Weight / Age", string.format(
			"%s   %s   %s", tostring(character:GetHeight()),
			tostring(character:GetWeight()), tostring(character:GetAge())))
	end
end)

--[[
	Karma: what you are known for, and what your faction is known for.

	Phoenix's `karma` plugin, kept whole - the fifty title levels, the three
	alignments, the ratio, and the faction bands. What is missing from their
	scrape is the server half (their `sv_plugin.lua` was never in it), so how
	karma is EARNED is written here from what their data plainly describes:
	`FACTION.karma = {kill = {good, bad}, passive = {good, bad}}` on every one
	of their faction files.

	TWO NUMBERS, BOTH ONLY EVER GOING UP. A character has GOOD karma and BAD
	karma, and nothing subtracts from either. That is the whole design and it
	is better than a single score:

	    the RATIO       `(good - bad) / (good + bad)`, from -1 to 1, is what
	                    you ARE - a saint, a neutral, a monster
	    the TOTAL       `good + bad` is how MUCH you are it, and is what the
	                    title level counts

	So somebody who has done a great deal of both is a notorious figure rather
	than a nobody, which a single score cannot express: +50 and -50 would read
	as "has never done anything".

	WHERE THE KARMA COMES FROM

	    passive    every `karmaTimer` seconds, each faction gives its members
	               its own `passive` pair. The NCR hand out good karma for
	               simply being NCR; the Fiends hand out bad
	    a kill     the killer takes the VICTIM's faction's `kill` pair, so
	               killing a Fiend is a good deed and killing a ranger is not

	Both pairs are per faction and both are editable in the developer terminal
	- see `sv_karma.lua`, which stores them, because the faction files are
	generated (`_docs/tools/genfactions.py`) and anything written into them by
	hand is lost the next time that runs.
]]

ix.karma = ix.karma or {}

--[[
	How often passive karma is handed out, in seconds.

	Sixty is Phoenix's. It is the one number here that changes what karma FEELS
	like: at a minute, an evening of standing around is a title.
]]
ix.config.Add("karmaTimer", 60,
	"Seconds between passive karma being handed out.", nil, {
	data = {min = 10, max = 3600},
	category = "Karma"
})

--[[
	Whether karma exists at all.

	Off leaves every number where it is and stops handing any more out, so it
	is a pause rather than a reset - which is the safe way round for something
	people have been earning for weeks.
]]
ix.config.Add("karmaEnabled", true,
	"Whether karma is earned and shown at all.", nil, {
	category = "Karma"
})

--[[
	Whether a title is only shown for people you RECOGNISE.

	On, which is Phoenix's: their `DrawCharInfo` checks `doesRecognize` before
	it draws anything. A title is a reputation, and a reputation belongs to a
	NAME - reading "Wasteland Savior" off a stranger in a gas mask is knowing
	something about somebody you have never met.
]]
ix.config.Add("karmaNeedsRecognition", true,
	"Whether a karma title only shows for characters you recognise.", nil, {
	category = "Karma"
})

--[[
	Whether earning karma makes a SOUND. There is no notice either way.

	A rising or falling tone says which direction a kill moved you and takes
	no room on the screen; a line in the corner reading "+1 good, +5 bad" turns
	a reputation into a scoreboard, and the corner is already full at the
	moment somebody dies. Passive karma is silent regardless - once a minute
	for ever is not an event.
]]
ix.config.Add("karmaNotify", true,
	"Whether earning karma plays a sound. There is never a notice.", nil, {
	category = "Karma"
})

--[[
	WHERE THE SCOREBOARD ICON CHANGES, as a percentage of good karma.

	Phoenix have five icons at fixed points; these are the same five with the
	points moved into the terminal, because "how good does a faction have to be
	before it looks like a saint" is a judgement about a server rather than a
	fact. See `cl_scoreboard.lua`, which also shades between them.

	Written high to low. Nothing stops somebody setting them out of order and
	the icon logic simply takes the first one a percentage clears, so the worst
	that happens is a band nothing can fall into.
]]
ix.config.Add("karmaIconVeryGood", 60,
	"Percentage of good karma a faction needs for the best icon.", nil, {
	data = {min = -100, max = 100},
	category = "Karma"
})

ix.config.Add("karmaIconGood", 20,
	"Percentage of good karma a faction needs for the good icon.", nil, {
	data = {min = -100, max = 100},
	category = "Karma"
})

ix.config.Add("karmaIconBad", -20,
	"Below this percentage a faction gets the bad icon.", nil, {
	data = {min = -100, max = 100},
	category = "Karma"
})

ix.config.Add("karmaIconVeryBad", -60,
	"Below this percentage a faction gets the worst icon.", nil, {
	data = {min = -100, max = 100},
	category = "Karma"
})

--------------------------------------------------------------------------------
-- The titles
--------------------------------------------------------------------------------

--[[
	Fifty levels, three alignments each: `{good, neutral, evil}`.

	Phoenix's list, unchanged. It is Fallout's own naming convention - a level
	and a moral direction - and the point of keeping it exactly is that a
	player who has played their server already knows what "Wasteland Savior"
	means.
]]
ix.karma.titles = {
	{"Samaritan", "Drifter", "Grifter"},
	{"Martyr", "Renegade", "Outlaw"},
	{"Sentinel", "Seeker", "Opportunist"},
	{"Defender", "Wanderer", "Plunderer"},
	{"Dignitary", "Citizen", "Fat Cat"},
	{"Peacekeeper", "Adventurer", "Marauder"},
	{"Ranger of the Wastes", "Vagabond of the Wastes", "Pirate of the Wastes"},
	{"Protector", "Mercenary", "Betrayer"},
	{"Desert Avenger", "Desert Scavenger", "Desert Terror"},
	{"Exemplar", "Observer", "Ne'er-do-well"},
	{"Vegas Crusader", "Vegas Councilor", "Vegas Crime Lord"},
	{"Paladin", "Keeper", "Defiler"},
	{"Mojave Legend", "Mojave Myth", "Mojave Boogeyman"},
	{"Shield of Hope", "Pinnacle of Survival", "Sword of Despair"},
	{"Vegas Legend", "Vegas Myth", "Vegas Boogeyman"},
	{"Hero of the Wastes", "Strider of the Wastes", "Villain of the Wastes"},
	{"Paragon", "Beholder", "Fiend"},
	{"Wasteland Savior", "Wasteland Watcher", "Wasteland Destroyer"},
	{"Saint", "Super-Human", "Evil Incarnate"},
	{"Guardian of the Wastes", "Renegade of the Wastes",
		"Scourge of the Wastes"},
	{"Restorer of Faith", "Soldier of Fortune", "Architect of Doom"},
	{"Model of Selflessness", "Profiteer", "Bringer of Sorrow"},
	{"Shepherd", "Egocentric", "Deceiver"},
	{"Friend of the People", "Loner", "Consort of Discord"},
	{"Champion of Justice", "Hero for Hire", "Stuff of Nightmares"},
	{"Symbol of Order", "Model of Apathy", "Agent of Chaos"},
	{"Herald of Tranquility", "Person of Refinement", "Instrument of Ruin"},
	{"Last, Best Hope of Humanity", "Moneygrubber", "Soultaker"},
	{"Savior of the Damned", "Gray Stranger", "Demon's Spawn"},
	{"Messiah", "True Mortal", "Devil"},
	{"Beacon of Virtue", "Lone Survivor", "Harbinger of Death"},
	{"Paragon of Peace", "Desert Phantom", "Devourer of Souls"},
	{"Angel of Redemption", "Nomad", "Grim Reaper"},
	{"Voice of Reason", "Reckless Wanderer", "Bringer of Wrath"},
	{"Divine Crusader", "Wasteland Drifter", "Architect of Annihilation"},
	{"Shining Beacon", "Desert Ghost", "Prince of Darkness"},
	{"Emissary of Hope", "Wasteland Phantom", "King of Destruction"},
	{"Savior of the Wastes", "Seeker of Fortune", "Apocalypse Incarnate"},
	{"Saint of the Wastes", "Free Spirit", "Nemesis of Mankind"},
	{"Immortal Guardian", "Survivor", "Fallen One"},
	{"Virtuous Savior", "Silent Traveler", "Master of Evil"},
	{"Pillar of Benevolence", "Wayward Wanderer", "Agent of Oblivion"},
	{"Champion of the People", "Desert Seeker", "Bringer of Doom"},
	{"Light of the Wasteland", "Wasteland Explorer", "Lord of Destruction"},
	{"Holy Avenger", "Ranger of the Wastes", "Cursed Soul"},
	{"Hopebringer", "Scavenger of the Lost", "Corrupter of the Innocent"},
	{"Redeemer", "Shadow of the Desert", "Warlord of Despair"},
	{"Knight of Purity", "Outlander", "Bane of Existence"},
	{"The Chosen One", "The Wanderer", "The Endbringer"},
	{"Ascendant", "Outcast", "Annihilator"}
}

--[[
	What a FACTION is called, by the percentage of its karma that is good.

	Phoenix's eleven bands, from +100 to -100 in twenties. The one thing that
	changed is the spelling - theirs has "Villians" and "Opportunist" for a
	plural - because these are printed to players.
]]
ix.karma.bands = {
	{at = 100, name = "Wasteland Angels",
		description = "Dedicated to helping others and defending the "
			.. "innocent."},
	{at = 80, name = "Wasteland Saints",
		description = "Infamous for its selfless acts."},
	{at = 60, name = "Wasteland Heroes",
		description = "Known for its acts of kindness."},
	{at = 40, name = "Wasteland Peacekeepers",
		description = "Known for its acts of heroism."},
	{at = 20, name = "Wasteland Saviours",
		description = "Known for the occasional good deed."},
	{at = 0, name = "Wasteland Outcasts",
		description = "Known for taking both sides."},
	{at = -20, name = "Wasteland Renegades",
		description = "Known for following its own rules."},
	{at = -40, name = "Wasteland Opportunists",
		description = "Known for its self-serving actions."},
	{at = -60, name = "Wasteland Marauders",
		description = "Known for its ruthless actions."},
	{at = -80, name = "Wasteland Villains",
		description = "Known for its evil deeds."},
	{at = -100, name = "Wasteland Devils",
		description = "Dedicated to causing chaos and destruction."}
}

--[[
	What a faction hands out when nothing has been set for it.

	Deliberately EVEN - one of each, both ways - so a faction nobody has
	configured drifts nowhere rather than quietly making everybody in it a
	saint. The dev terminal is where a faction is given a character.
]]
ix.karma.defaults = {
	passive = {1, 1},
	kill = {1, 1}
}

--------------------------------------------------------------------------------
-- The arithmetic
--------------------------------------------------------------------------------

--[[
	-1 to 1. Nothing at all reads as neutral rather than as an error.

	Phoenix divide without checking, so a character with no karma at all
	divides zero by zero and gets a NaN - which compares false against
	everything and would make their `getKarmaData` fall through every branch.
]]
function ix.karma.Ratio(good, bad)
	local total = (good or 0) + (bad or 0)

	if (total <= 0) then return 0 end

	return ((good or 0) - (bad or 0)) / total
end

--[[
	The level a total reaches, 1 to 50.

	Phoenix's ladder: each level costs `100 + 15 * (level - 1)` on top of the
	one before it, so the first is 100 and the fiftieth is 835 - and the whole
	fifty comes to about 23,000, which is a long-running character rather than
	an evening.
]]
function ix.karma.Level(total)
	local threshold = 0

	for level = 1, #ix.karma.titles do
		threshold = threshold + 100 + 15 * (level - 1)

		if ((total or 0) < threshold) then
			return math.max(level - 1, 1)
		end
	end

	return #ix.karma.titles
end

--[[
	1 good, 2 neutral, 3 evil.

	The thresholds are Phoenix's: a THIRD either way, which is a wide neutral
	band on purpose - one bad day should not make somebody a villain.
]]
function ix.karma.Alignment(ratio)
	if (ratio > 0.3) then return 1 end
	if (ratio < -0.3) then return 3 end

	return 2
end

--[[
	The colour a title is drawn in: green for good, red for bad, and the mix
	in between.

	Phoenix build it from the two numbers directly rather than from the
	alignment, which is why a neutral character who leans good is a slightly
	different colour from one who leans bad. Kept, because it is more
	information for free.
]]
function ix.karma.Colour(good, bad)
	local total = (good or 0) + (bad or 0)

	if (total <= 0) then return Color(200, 200, 200) end

	local ratio = ix.karma.Ratio(good, bad)

	return Color(
		math.max(255 * (bad / total), 30),
		math.max(255 * (good / total), 30),
		math.max(122 * (1 - math.abs(ratio)), 30)
	)
end

--[[
	Everything about one character's karma, in one call.

	Returns `title, level, colour, good, bad`. Never nil - a character with no
	karma is a level 1 Drifter, which is what somebody who has done nothing
	is.
]]
function ix.karma.Describe(good, bad)
	good, bad = good or 0, bad or 0

	local level = ix.karma.Level(good + bad)
	local alignment = ix.karma.Alignment(ix.karma.Ratio(good, bad))
	local titles = ix.karma.titles[level] or ix.karma.titles[1]

	return titles[alignment], level, ix.karma.Colour(good, bad), good, bad
end

--- The band a faction's karma falls into, and the colour for it.
function ix.karma.Band(good, bad)
	local percent = ix.karma.Ratio(good, bad) * 100
	local band = ix.karma.bands[#ix.karma.bands]

	--[[
		Walked from the TOP down, taking the first band the percentage reaches
		- so 55% is "Wasteland Heroes" (40) rather than "Angels" (100). The
		list is written in order, so this needs no sorting.
	]]
	for _, entry in ipairs(ix.karma.bands) do
		if (percent >= entry.at) then
			band = entry

			break
		end
	end

	--[[
		Hue from red through to green across the whole range, which is
		Phoenix's `HSVToColor(120 * ((ratio + 1) / 2), 1, 1)`.
	]]
	return band, HSVToColor(120 * ((ix.karma.Ratio(good, bad) + 1) / 2), 1, 1)
end

--------------------------------------------------------------------------------
-- Reading it off a character
--------------------------------------------------------------------------------

--[[
	One character's karma as `good, bad`.

	THE SERVER READS THE CHARACTER AND THE CLIENT READS A NETWORKED VAR, which
	is Phoenix's split and is not optional: character data reaches its owner
	only, and a title everybody can see has to be networked to everybody. See
	`sv_karma.lua`, which writes both.
]]
function ix.karma.Of(character)
	if (not character) then return 0, 0 end

	if (SERVER) then
		local stored = character:GetData("karma")

		if (istable(stored)) then
			return tonumber(stored[1]) or 0, tonumber(stored[2]) or 0
		end

		return 0, 0
	end

	local client = character:GetPlayer()
	local networked = IsValid(client) and client:GetNetVar("karma")

	if (istable(networked)) then
		return tonumber(networked[1]) or 0, tonumber(networked[2]) or 0
	end

	return 0, 0
end

--[[
	The same thing for a PLAYER, which is what everything drawing a title
	actually has.

	The netvar lives on the player, so this is the direct read - going through
	the character means asking the character for its player and then reading
	the same var, which is the long way round and fails for a character whose
	player is not the one being looked at.
]]
function ix.karma.OfPlayer(client)
	if (not IsValid(client)) then return 0, 0 end

	if (SERVER) then
		return ix.karma.Of(client:GetCharacter())
	end

	local networked = client:GetNetVar("karma")

	if (istable(networked)) then
		return tonumber(networked[1]) or 0, tonumber(networked[2]) or 0
	end

	return 0, 0
end

--------------------------------------------------------------------------------
-- Per faction
--------------------------------------------------------------------------------

--- `[factionUniqueID] = {passive = {good, bad}, kill = {good, bad}}`.
ix.karma.settings = ix.karma.settings or {}

--- `[factionUniqueID] = {good, bad}` - what the faction has earned in total.
ix.karma.factions = ix.karma.factions or {}

--[[
	What a faction hands out. Never nil, and never the stored table itself -
	callers read numbers out of it and a shared table is a table somebody
	eventually writes into.
]]
function ix.karma.Settings(uniqueID)
	local stored = ix.karma.settings[uniqueID] or {}
	local passive = stored.passive or ix.karma.defaults.passive
	local kill = stored.kill or ix.karma.defaults.kill

	return {
		passive = {tonumber(passive[1]) or 0, tonumber(passive[2]) or 0},
		kill = {tonumber(kill[1]) or 0, tonumber(kill[2]) or 0}
	}
end

--- What a faction has earned as a whole, as `good, bad`.
function ix.karma.FactionKarma(uniqueID)
	local stored = ix.karma.factions[uniqueID]

	if (not istable(stored)) then return 0, 0 end

	return tonumber(stored[1]) or 0, tonumber(stored[2]) or 0
end

--- The faction table for a character, or nil.
function ix.karma.FactionOf(character)
	if (not character) then return nil end

	return ix.faction.indices[character:GetFaction()]
end

--[[
	Mining.

	Phoenix's: rocks placed around the map that you hit with a pickaxe until the
	ore in them runs out, and which grow back on a timer. Their plugin's server
	half is not in the scrape, but everything it did is legible from the client
	half and the tool:

	    a node holds KILOGRAMMES of one ore, not "three uses"
	    the model shrinks through five bodygroups as it empties
	    a soft spot is sent to the client and drawn as a yellow glow
	    only a pickaxe counts as mining
	    XP per successful swing

	THE SOFT SPOT IS THE GAME. It is Rust's, and Phoenix's `nutMiningSendGSpot`
	is the same idea: a small patch on the rock that is worth several times a
	normal hit, and which moves once you strike it. Mining without looking is
	slow and mining well is fast, which is the difference between a chore and
	something somebody chooses to do.

	EVERYTHING HERE IS EDITABLE IN GAME. The ore list is not a table in this
	file that a coder has to change - it is data, saved with the rest of the
	world, edited through `/MiningConfig`. What is written below is only what a
	server starts with.
]]

ix.mining = ix.mining or {}

--------------------------------------------------------------------------------
-- The numbers
--------------------------------------------------------------------------------

ix.config.Add("miningXP", 2,
	"Experience for each ore dug out.", nil, {
	data = {min = 0, max = 1000},
	category = "Mining"
})

ix.config.Add("miningKgPerHit", 1.5,
	"Kilogrammes knocked off a node by an ordinary hit.", nil, {
	data = {min = 0.1, max = 100, decimals = 1},
	category = "Mining"
})

ix.config.Add("miningSoftMultiplier", 3,
	"How many times an ordinary hit a soft spot hit is worth.", nil, {
	data = {min = 1, max = 20, decimals = 1},
	category = "Mining"
})

ix.config.Add("miningSoftRadius", 12,
	"How close to the soft spot a hit has to land.", nil, {
	data = {min = 2, max = 64},
	category = "Mining"
})

ix.config.Add("miningKgPerOre", 5,
	"Kilogrammes that have to come off before one ore drops.", nil, {
	data = {min = 0.5, max = 1000, decimals = 1},
	category = "Mining"
})

--[[
	HOW MANY ORE ONE MILESTONE GIVES.

	`miningKgPerOre` is how much rock has to come off before a drop; this is how
	big that drop is. Two dials rather than one because they are two different
	decisions - how OFTEN ore comes out, and how MUCH - and an ore that pays
	three at a time every ten kilogrammes feels nothing like one that pays one
	every three, even though the rate is the same.

	Each ore can override it with a `yield` of its own in `/MiningConfig`.
]]
ix.config.Add("miningOrePerDrop", 1,
	"How many ore one milestone gives, unless the ore says otherwise.", nil, {
	data = {min = 1, max = 100},
	category = "Mining"
})

ix.config.Add("miningRespawn", 600,
	"Seconds an emptied node takes to come back.", nil, {
	data = {min = 10, max = 86400},
	category = "Mining"
})

ix.config.Add("miningStrength", 1,
	"A multiplier on every swing, before the ore's own strength.", nil, {
	data = {min = 0.1, max = 10, decimals = 1},
	category = "Mining"
})

--[[
	THE ONE THING THAT CAN MINE.

	Phoenix hard-code `meleearts_blade_pickaxe` in the rock's damage handler.
	This is a config so a server can add a second pickaxe, or a drill, without
	editing code - and blank means "anything", which is the setting for a server
	that would rather people used whatever they are carrying.
]]
ix.config.Add("miningTool", "meleearts_blade_pickaxe",
	"Weapon class that can mine. Blank means anything.", nil, {
	category = "Mining"
})

--------------------------------------------------------------------------------
-- The ores
--------------------------------------------------------------------------------

--[[
	What a server starts with: Phoenix's seven, with their skins and their
	strengths, pointed at the ore items this schema already has.

	    item       what one ore gives you
	    strength   a multiplier on how fast this ore comes out. Gold is 0.75
	               in Phoenix's - harder rock, slower digging
	    skin       which skin of the node model this ore uses
	    colour     the glow on the soft spot and the text over the node
]]
ix.mining.defaults = {
	{
		id = "iron", name = "Iron Ore", item = "mat_oreiron",
		strength = 1, skin = 1, colour = {200, 200, 200}
	},
	{
		id = "bronze", name = "Bronze Ore", item = "mat_orebronze",
		strength = 1, skin = 2, colour = {205, 127, 50}
	},
	{
		id = "silver", name = "Silver Ore", item = "mat_oresilver",
		strength = 1, skin = 3, colour = {230, 230, 240}
	},
	{
		id = "gold", name = "Gold Ore", item = "mat_oregold",
		strength = 0.75, skin = 4, colour = {255, 215, 0}
	},
	{
		id = "coal", name = "Coal Ore", item = "mat_orecoal",
		strength = 1, skin = 5, colour = {60, 60, 60}
	},
	{
		id = "uranium", name = "Uranium Ore", item = "mat_oreuranium",
		strength = 1, skin = 6, colour = {0, 255, 0}
	},
	{
		id = "saturnite", name = "Saturnite Ore", item = "mat_oresaturnite",
		strength = 1, skin = 6, colour = {0, 255, 255}
	}
}

--[[
	The live list. Replaced wholesale by the server on load and whenever
	somebody saves the config, and sent to every client - the node's own label,
	the tool's dropdown and the config window all read this one table.
]]
ix.mining.ores = ix.mining.ores or {}

function ix.mining.Get(id)
	for _, ore in ipairs(ix.mining.ores) do
		if (ore.id == id) then return ore end
	end
end

--- The first one, for anything that has lost track of its type.
function ix.mining.Fallback()
	return ix.mining.ores[1]
end

--[[
	THE SOFT SPOT IS ORANGE, whatever the ore is.

	It was the ore's own colour, which made iron's spot white on grey rock -
	nearly invisible, and the one thing in this system that has to be seen from
	across a cave. The ore's colour still names the node; the spot is one
	colour so that it always means the same thing.
]]
ix.mining.softColour = Color(255, 140, 0)

--[[
	What a soft spot hit on THIS ore is worth, in ordinary hits.

	Zero means "whatever the config says", which is what an ore with no opinion
	writes - so the global dial still moves everything that has not been given
	a number of its own. A rock somebody wants to be all about the sweet spot
	gets a six; a rock that should reward patience gets a one.
]]
function ix.mining.SoftMultiplier(ore)
	local own = ore and tonumber(ore.soft)

	if (own and own > 0) then return own end

	return ix.config.Get("miningSoftMultiplier", 3)
end

--- How many ore this one gives per milestone.
function ix.mining.Yield(ore)
	local own = ore and tonumber(ore.yield)

	if (own and own >= 1) then return math.floor(own) end

	return math.max(math.floor(ix.config.Get("miningOrePerDrop", 1)), 1)
end

--[[
	Hardness and hits, which are the same number read two ways.

	Somebody tuning an ore thinks in "how many swings is this rock", not in "a
	multiplier on kilogrammes per hit" - so the config window shows both and
	converts between them. `amount` is the node size those hits are counted
	against.
]]
function ix.mining.HitsFor(strength, amount)
	local kg = ix.config.Get("miningKgPerHit", 1.5)
		* math.max(tonumber(strength) or 1, 0.05)
		* ix.config.Get("miningStrength", 1)

	if (kg <= 0) then return 0 end

	return math.max(math.ceil((tonumber(amount) or 25) / kg), 1)
end

--- The reverse: how hard an ore has to be for a node to take this many hits.
function ix.mining.StrengthFor(hits, amount)
	hits = math.max(tonumber(hits) or 1, 1)

	local perHit = (tonumber(amount) or 25) / hits
	local base = ix.config.Get("miningKgPerHit", 1.5)
		* ix.config.Get("miningStrength", 1)

	if (base <= 0) then return 1 end

	return math.Clamp(math.Round(perHit / base, 2), 0.05, 20)
end

function ix.mining.Colour(ore)
	local colour = ore and ore.colour

	if (not istable(colour)) then return Color(220, 220, 0) end

	return Color(tonumber(colour[1]) or 220, tonumber(colour[2]) or 220,
		tonumber(colour[3]) or 0)
end

--- Phoenix's "12.5kg", which is how every number in this system is written.
function ix.mining.FormatAmount(amount)
	return string.format("%skg", math.Round(tonumber(amount) or 0, 2))
end

--[[
	How much a node shows of itself, by how much is left in it.

	Phoenix's five bodygroups, keyed by the percentage at which each one starts.
	Written as a sorted list rather than their table so the lookup is a loop
	with an obvious order rather than `pairs` over numeric keys.
]]
ix.mining.stages = {
	{above = 65, bodygroup = 0},
	{above = 45, bodygroup = 1},
	{above = 30, bodygroup = 2},
	{above = 15, bodygroup = 3},
	{above = -1, bodygroup = 4}
}

function ix.mining.Bodygroup(fraction)
	local percent = math.Clamp((tonumber(fraction) or 0) * 100, 0, 100)

	for _, stage in ipairs(ix.mining.stages) do
		if (percent > stage.above) then return stage.bodygroup end
	end

	return 4
end

--- The model every node uses. From `phoenix_mining_content`.
ix.mining.model = "models/zerochain/props_mining/zrms_resource_point.mdl"

--[[
	The addon's particles, registered the way Phoenix register them.

	A `.pcf` is not loaded unless something says so, and a particle that was
	never added is a silent nothing rather than an error - the same failure mode
	as a missing sound (gotcha 16), and the reason this is guarded by a file
	check rather than assumed: a server without the mining content should lose
	the sparks, not throw on every swing.
]]
if (file.Exists("particles/zrms_pickaxe_vfx.pcf", "GAME")) then
	game.AddParticles("particles/zrms_pickaxe_vfx.pcf")
	game.AddParticles("particles/zrms_ore_vfx.pcf")

	PrecacheParticleSystem("pickaxe_hit01")
	PrecacheParticleSystem("zrms_ore_mine")

	util.PrecacheModel(ix.mining.model)
else
	MsgC(Color(255, 200, 100), "[falloutrp] the mining content addon is not "
		.. "installed - nodes will work and will not spark\n")
end

--------------------------------------------------------------------------------
-- Who may place them
--------------------------------------------------------------------------------

--[[
	Registered SHARED, for the reason `sh_points.lua` gives: a permission the
	client does not know about is a tickbox missing from the rank editor.
]]
if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("mining.edit",
		"Place ore nodes and configure the mining system", "World")
end

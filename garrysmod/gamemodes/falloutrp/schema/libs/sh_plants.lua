--[[
	Plants you can pick.

	Phoenix's `plants` plugin: seventeen kinds of wasteland flora placed around
	the map, each one a prop you press E on for an item and some experience,
	which then grows back on a timer.

	WHAT THEIR PLUGIN IS, in one paragraph: `nut.plants:add(name, model, item,
	offset)` registers a kind; `placePlant` spawns a `nut_plant` and writes the
	position into the plugin's own save data; the entity's `Use` gives the item,
	sets bodygroup 1 (which hides the fruit and leaves the stalk), awards
	`Plant Experience` and sets a `timer.Simple` to put the fruit back.

	THE PLACEMENT IS NOT REBUILT HERE, because this schema already has it.

	A plant is exactly what `sh_points.lua` calls a point - "a thing a map-maker
	places one of at a time", an object you walk up to and press E on. It gets
	the point tool, the point list, the per-map persistence with its save guard,
	`/Points`, `/PointDelete`, and the protection from map cleanups, all of
	which their plugin either wrote again or did without. The only thing added
	to the point system is a type.

	WHAT IS HERE: which plants exist, what each drops, and the two effects their
	items need that nothing else in this schema provides.
]]

ix.plants = ix.plants or {}

ix.config.Add("plantXP", 10,
	"Experience for harvesting a plant.", nil, {
	data = {min = 0, max = 1000},
	category = "Plants"
})

--[[
	The seventeen kinds, exactly Phoenix's list.

	`model` is what stands in the world; the ITEM has its own model, which is
	the fruit rather than the plant. Two entries share an item on purpose -
	their Banana Yucca and Banana Yucca Tree are the same fruit on a bush and on
	a tree.

	Every model here was checked with `resolve_asset.py`; they are all in
	`af_content_pack_6`. A missing model is an error box that still spawns,
	still saves and still works.
]]
ix.plants.types = {
	{
		id = "brocflower",
		name = "Broc Flower",
		model = "models/roadkill/fallout/clutter/plants/brocflower.mdl",
		item = "plant_brocflower"
	},
	{
		id = "xanderroot",
		name = "Xander Root",
		model = "models/roadkill/fallout/clutter/plants/xanderroot.mdl",
		item = "plant_xanderroot"
	},
	{
		id = "jalapeno",
		name = "Jalapeño",
		model = "models/roadkill/fallout/clutter/plants/jalepeno_root.mdl",
		item = "plant_jalapeno"
	},
	{
		id = "barrelcactus",
		name = "Barrel Cactus",
		model = "models/roadkill/fallout/clutter/plants/barrel_cactus.mdl",
		item = "plant_barrelcactus"
	},
	{
		id = "coyotetobacco",
		name = "Coyote Tobacco",
		model = "models/roadkill/fallout/clutter/plants/coyote_tobacco.mdl",
		item = "plant_coyotetobacco"
	},
	{
		id = "honeymesquite",
		name = "Honey Mesquite",
		model = "models/roadkill/fallout/clutter/plants/honey_mesquite.mdl",
		item = "plant_honeymesquite"
	},
	{
		id = "pricklypear",
		name = "Prickly Pear",
		model = "models/roadkill/fallout/clutter/plants/prickly_pear_cactus.mdl",
		item = "plant_pricklypear"
	},
	{
		id = "cavefungus",
		name = "Cave Fungus",
		model = "models/roadkill/fallout/clutter/plants/cave_fungus.mdl",
		item = "plant_cavefungus"
	},
	{
		id = "bananayucca",
		name = "Banana Yucca",
		model = "models/roadkill/fallout/clutter/plants/banana_yucca.mdl",
		item = "plant_bananayucca"
	},
	{
		id = "bananayuccatree",
		name = "Banana Yucca Tree",
		model = "models/roadkill/fallout/clutter/plants/yucca_tree.mdl",
		item = "plant_bananayucca"
	},
	{
		id = "brainfungus",
		name = "Brain Fungus",
		model = "models/roadkill/fallout/clutter/plants/brain_fungus.mdl",
		item = "plant_brainfungus"
	},
	{
		id = "maize",
		name = "Maize",
		model = "models/roadkill/fallout/clutter/plants/maize.mdl",
		item = "plant_maize"
	},
	{
		id = "nevadaagave",
		name = "Nevada Agave",
		model = "models/roadkill/fallout/clutter/plants/nevada_agave.mdl",
		item = "plant_nevadaagave"
	},
	{
		id = "pintoroot",
		name = "Pinto Root",
		model = "models/roadkill/fallout/clutter/plants/pinto_root.mdl",
		item = "plant_pintoroot"
	},
	{
		id = "sacreddatura",
		name = "Sacred Datura",
		model = "models/roadkill/fallout/clutter/plants/sacred_datura.mdl",
		item = "plant_sacreddatura"
	},
	{
		id = "buffalogourd",
		name = "Buffalo Gourd",
		model = "models/roadkill/fallout/clutter/plants/buffalo_guord.mdl",
		item = "plant_buffalogourd"
	},
	{
		id = "whitehorsenettle",
		name = "White Horsenettle",
		model = "models/roadkill/fallout/clutter/plants/whitehorse.mdl",
		item = "plant_whitehorsenettle"
	}
}

ix.plants.byID = {}

for _, plant in ipairs(ix.plants.types) do
	ix.plants.byID[plant.id] = plant
end

function ix.plants.Get(id)
	return ix.plants.byID[id or ""]
end

--- The default kind, used when a placed plant has no type on its record.
ix.plants.fallback = "xanderroot"

--------------------------------------------------------------------------------
-- The two effects their items need
--------------------------------------------------------------------------------

--[[
	Healing over time - Phoenix's `nut.rib:slowHeal(client, "xander", 1, 1, 10)`.

	Their `rib` library is not in the scrape, but the call sites are, and they
	are all the same shape: an id, an amount, an interval and a count. Ten
	seconds of one health a second, which is not a stimpak and is not meant to
	be - a plant is what you eat when you have no stimpak.

	KEYED BY THE ID, so eating two of the same plant restarts the healing
	rather than stacking two timers on one person. `timer.Create` replaces a
	timer of the same name, which is what is wanted.
]]
function ix.plants.SlowHeal(client, id, amount, interval, count)
	if (not SERVER or not IsValid(client)) then return end

	local key = "ixPlantHeal" .. id .. client:SteamID64()

	timer.Create(key, interval or 1, count or 10, function()
		if (not IsValid(client) or not client:Alive()) then
			timer.Remove(key)

			return
		end

		client:SetHealth(math.min(client:Health() + (amount or 1),
			client:GetMaxHealth()))
	end)
end

--[[
	Tripping - Phoenix's `nut.rib:makeSchizo(client, 60, <a catbox mp3>, true)`.

	Theirs streams an audio file from `files.catbox.moe`, which is not something
	this server is going to depend on: an external host going down would take
	the effect with it, and a URL in an item is a thing nobody can audit.

	So it is a BUFF, and the screen effects come from the chem system that is
	already wired to buffs - `ix.chemfx.chemEffects` below reads
	`ix.buff.Has(client, "Hallucinating")` on its own timer. That also means the
	HUD says what is happening to you, which their version does not.

	The small speed penalty is what makes it a buff rather than a flag: every
	buff names a stat, and being unable to walk straight is the honest one.
]]
function ix.plants.Hallucinate(client, seconds)
	if (not SERVER or not IsValid(client)) then return end

	ix.buff.Add(client, "SPD", -10, seconds or 60, "Hallucinating",
		"Hallucinating")
end

if (CLIENT) then
	--[[
		Registered into the chem system's own table rather than a second one.

		`ix.chemfx.Rebuild` clears everything and re-derives it from the buffs
		that are currently running, so an effect added any other way is wiped
		the next time somebody takes a chem. Adding the entry here means the
		rebuild finds it.
	]]
	timer.Simple(0, function()
		if (not ix.chemfx or not ix.chemfx.chemEffects) then return end

		ix.chemfx.chemEffects[#ix.chemfx.chemEffects + 1] = {
			id = "Hallucinating",
			effects = {"euphoria", "toytown", "blur"}
		}
	end)
end

if (SERVER) then
	ix.log.AddType("plantHarvest", function(client, name, count)
		return string.format("%s harvested %d %s.", client:Name(), count, name)
	end)
end

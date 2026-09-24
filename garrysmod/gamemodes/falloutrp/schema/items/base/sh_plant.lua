--[[
	Plant base item.

	Everything in `items/plant/` inherits this. The plants you pick off the
	world with E, and the crops the farming system will grow later - the same
	twenty items serve both, which is why they are a category of their own
	rather than food.

	IT IS THE FOOD BASE WITH A DECLARATION ON TOP.

	`ITEM.base = "base_food"` - a base item may itself have a base, and
	`ix.item.Register` merges it after the file is included. So eating, feeding
	somebody else, the sustenance and hydration numbers, the radiation and the
	`/me` line are all the food base's, unchanged, and this adds only the thing
	food does not have: the AFTER-EFFECT.

	WHY THE EFFECTS ARE DATA HERE AND WERE CODE IN PHOENIX.

	Theirs writes a closure per item:

	    ITEM.effectFunctions = {
	        SERVER = function(item, client)
	            nut.rib:slowHeal(client, "xander", 1, 1, 10)
	            timer.Simple(4, function() ... chem hint ... end)
	        end
	    }

	which is twenty copies of four shapes, each free to drift from the others -
	and two of theirs already have: the same hint timer appears with and without
	an `IsValid` check, and one plant's `eatMeText` describes a different plant.
	Here an item says `ITEM.heal = {1, 1, 10}` and this decides what that means,
	once.

	The four shapes, all of them Phoenix's:

	    heal          `nut.rib:slowHeal` - health back slowly
	    hallucinate   `nut.rib:makeSchizo` - see `ix.plants.Hallucinate`
	    knockout      `setRagdolled(true, 15, 15)` - you fall over
	    ignite        `Ignite` - the jalapeño, and only the jalapeño
	    gamble        Coyote Tobacco's coin flip: armour, or the floor
	    chemHint      the "this could be a chem ingredient" line
]]

ITEM.base = "base_food"

ITEM.name = "Plant"
ITEM.description = "Something that grew out of the ground."
ITEM.model = "models/roadkill/fallout/clutter/plants/xanderroot_model.mdl"
ITEM.category = "Plants"

ITEM.width = 1
ITEM.height = 1

--- The marker other systems key off, rather than a base name.
ITEM.isPlant = true

--[[
	Chewing, which the food base plays and no plant used to set.

	Phoenix's plant base emits this and a wet squelch on every Eat; the food
	base already has the mechanism (`useSound`, a function so an item can
	randomise), so a plant only has to name the sound. Without it, eating a
	plant was silent - the one thing about their version that was obviously
	missing in game.
]]
ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0"
		.. math.random(2) .. ".mp3"
end

--- `{amount, interval, count}`, or nil. Phoenix's is always `{1, 1, 10}`.
ITEM.heal = nil

--- Seconds of tripping, or nil.
ITEM.hallucinate = nil

--- Seconds face down, or nil.
ITEM.knockout = nil

--- `{min, max}` seconds on fire, or nil.
ITEM.ignite = nil

--- Coyote Tobacco's coin flip. `{chance, stat, value, duration, knockout}`.
ITEM.gamble = nil

--- Whether eating it hints that it is worth something at a chem bench.
ITEM.chemHint = false

local HINT = "( The flavor indicates this can be used as a chem ingredient )"

--[[
	THE HINT IS FOUR SECONDS LATE, which is Phoenix's timing and is worth
	keeping: it arrives after whatever the plant did to you, so it reads as an
	aftertaste rather than as part of the label.
]]
local function Hint(client)
	timer.Simple(4, function()
		if (not IsValid(client)) then return end

		client:ChatPrint(HINT)
	end)
end

ITEM.effectFunctions = {
	SERVER = function(item, client)
		if (not IsValid(client)) then return end

		if (item.heal) then
			ix.plants.SlowHeal(client, item.uniqueID, item.heal[1],
				item.heal[2], item.heal[3])
		end

		if (item.hallucinate) then
			ix.plants.Hallucinate(client, item.hallucinate)
		end

		if (item.knockout) then
			client:SetRagdolled(true, item.knockout, item.knockout)
			client:ChatPrint("You feel dizzy and pass out...")
		end

		if (item.ignite) then
			client:Ignite(math.random(item.ignite[1], item.ignite[2]))
		end

		if (item.gamble) then
			local gamble = item.gamble

			if (math.random() < (gamble.chance or 0.5)) then
				ix.buff.Add(client, gamble.stat, gamble.value,
					gamble.duration, item.uniqueID, item.name)

				client:Notify("That was the good half of the odds.")
			else
				client:SetRagdolled(true, gamble.knockout or 15,
					gamble.knockout or 15)
				client:ChatPrint("You feel dizzy and pass out...")
			end
		end

		if (item.chemHint) then Hint(client) end
	end
}

--[[
	ANY PLANT CAN BE EATEN, WHICH FOOD CANNOT SAY.

	The food base decides between Eat and Drink by the stats - anything with
	sustenance is eaten, anything that is purely hydration is drunk - and a
	plant like the Broc Flower has NEITHER. It restores nothing and does
	something else entirely, which under the food base's rule means no button at
	all: NINE of the twenty - counted, not guessed - would have been inedible.

	Only `OnCanRun` is replaced. `table.Merge` recurses into sub-tables, so
	this partial `Eat` keeps the food base's `OnRun` - the eating, the
	sustenance, the `/me` line and the after-effect are all still theirs.
]]
ITEM.functions.Eat = {
	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}

--[[
	The food base builds its description from sustenance, hydration and
	radiation. This adds what a plant does AFTERWARDS, because those three
	numbers do not tell you that the Brain Fungus will put you on the floor.
]]
function ITEM:GetDescription()
	--[[
		THE FOOD BASE IS CALLED BY NAME, not through `self.baseTable`.

		`ix.item.Register` sets `baseTable` to the item's OWN base - which for
		anything in `items/plant/` is this file - so `self.baseTable.GetDescription`
		here is this function, and calling it is a stack overflow rather than
		an inherited call. Registered bases are addressable, so it asks for the
		one it means.
	]]
	local food = ix.item.base and ix.item.base["base_food"]
	local description = food and food.GetDescription(self) or self.description
	local lines = {}

	if (self.heal) then
		lines[#lines + 1] = string.format(" - Heals %d over %d seconds",
			(self.heal[1] or 1) * (self.heal[3] or 10),
			(self.heal[2] or 1) * (self.heal[3] or 10))
	end

	if (self.hallucinate) then
		lines[#lines + 1] = string.format(" - Hallucinations for %d seconds",
			self.hallucinate)
	end

	if (self.knockout) then
		lines[#lines + 1] = string.format(" - Knocks you out for %d seconds",
			self.knockout)
	end

	if (self.ignite) then
		lines[#lines + 1] = " - Sets you on fire"
	end

	if (self.gamble) then
		lines[#lines + 1] = " - Even odds of something good or something bad"
	end

	if (#lines == 0) then return description end

	return description .. "\n" .. table.concat(lines, "\n")
end

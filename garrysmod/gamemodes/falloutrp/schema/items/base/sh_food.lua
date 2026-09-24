--[[
	Food base item.

	Everything in `items/food/` inherits this - `ix.item.LoadFromDir` gives
	items in `items/<folder>/` the base `base_<folder>`, so the folder name and
	this filename have to stay in step.

	The field contract is Phoenix's, so their 56 food items convert
	mechanically:

	    sustenance   hunger restored, 0-100
	    hydration    thirst restored, 0-100
	    radiation    rads taken on, 0-100
	    isAlcohol    triggers the drunk behaviour below
	    useSound     a FUNCTION returning a path, so an item can randomise
	    eatMeText    emoted as /me when consumed

	Their base item's own description says "An armor base, used to create armor
	items" - copied from the armour base and never corrected. Fixed here.
]]

ITEM.name = "Food"
ITEM.description = "Something to eat."
ITEM.model = "models/mosi/fallout4/props/food/cram.mdl"
ITEM.category = "Food"

ITEM.width = 1
ITEM.height = 1

--- The marker other systems key off, rather than a base name.
ITEM.isFood = true

ITEM.sustenance = 0
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.isAlcohol = false
ITEM.useSound = false
ITEM.eatMeText = false

ITEM.effectFunctions = {}

--[[
	Built rather than written, so an item's stats and its text cannot drift.
	Radiation is called out in red-flag language because a player reading a
	description is deciding whether to eat it.
]]
function ITEM:GetDescription()
	local description = self.description or ""
	local lines = {}

	if (self.sustenance and self.sustenance ~= 0) then
		lines[#lines + 1] = string.format(" - Sustenance: +%d", self.sustenance)
	end

	if (self.hydration and self.hydration ~= 0) then
		lines[#lines + 1] = string.format(" - Hydration: +%d", self.hydration)
	end

	if (self.radiation and self.radiation ~= 0) then
		lines[#lines + 1] = string.format(" - Radiation: +%d", self.radiation)
	end

	if (self.isAlcohol) then
		lines[#lines + 1] = " - Alcoholic"
	end

	if (#lines > 0) then
		description = description .. "\n\n" .. table.concat(lines, "\n")
	end

	return description
end

--[[
	What being drunk does.

	Ported from their base: a one-in-fifty chance per second, for sixty
	seconds, of stumbling over and blurting something out. The lines are
	theirs.
]]
local DRUNK_LINES = {
	"Hic!", "Hicc...", "H-Hic!", "Hiccup!", "Ughhh...", "Whaaa?",
	"I'm fine...", "I'm not drunk!", "You're drunk...",
	"Who put the floor there?", "The room's moving...",
	"I can walk straight...", "Watch this...", "I meant to do that.",
	"Where am I?", "Who are you again?", "I need another drink...",
	"No more... actually one more.", "My legs aren't working.",
	"Everything's blurry...", "Stop spinning...", "I feel amazing...",
	"I feel terrible...", "I can totally fight.", "Hold on... hold on...",
	"I'm gonna be sick...", "Don't tell the bartender.",
	"That wall came out of nowhere.", "I'm walking perfectly straight.",
	"Why are there two of you?", "This is tactical wobbling.",
	"I have never been more sober.", "I'm just chemically confident.",
	"My brain is loading...", "Who stole my balance?",
	"Hic... I regret nothing.", "Hic... maybe I regret something.",
	"The floor is my friend now.", "I'm taking a tactical nap.",
	"I can still drive a vertibird.", "This drink tastes like regret.",
	"I'm seeing in low FPS.", "My bones are lagging.",
	"I think my liver crashed.", "I've been poisoned... by fun.",
	"You look like trouble... or a chair.", "Permission to fall over?",
	"I'm not slurring, you're hearing wrong.",
	"I swear there was a door here.", "The universe is tilted.",
	"Hic... carry me."
}

local function Intoxicate(client)
	--[[
		Keyed by SteamID so a second drink RESTARTS the timer rather than
		running two of them - `timer.Create` replaces a timer of the same name,
		which is the behaviour wanted here.
	]]
	local key = "ixAlcohol" .. client:SteamID64()

	timer.Create(key, 1, 60, function()
		if (not IsValid(client) or not client:Alive() or not client:GetCharacter()) then
			timer.Remove(key)
			return
		end

		if (math.random(100) < 2) then
			client:SetRagdolled(true, 1, 1)
			client:Say(table.Random(DRUNK_LINES))
		end
	end)

	net.Start("ixAlcoholEffect")
	net.Send(client)
end

--[[
	Consuming it. Shared by Eat, Drink and Feed, so all three do exactly the
	same thing to whoever ends up swallowing it.
]]
local function Consume(item, target)
	local client = target or item.player

	if (not IsValid(client)) then return end

	if (item.eatMeText) then
		ix.chat.Send(client, "me", item.eatMeText)
	end

	if (item.useSound) then
		--[[
			A function, not a string - several items randomise between chew
			samples. Called defensively because an item could set a plain
			string and it should not take the server down.
		]]
		local sound = isfunction(item.useSound) and item.useSound() or item.useSound

		if (isstring(sound)) then
			client:EmitSound(sound)
		end
	end

	local character = client:GetCharacter()

	if (character) then
		character:AddHunger(item.sustenance or 0)
		character:AddThirst(item.hydration or 0)

		if (item.radiation and item.radiation ~= 0 and character.AddRadiation) then
			character:AddRadiation(item.radiation)
		end

		character:ApplyHungerThirst()
	end

	if (item.isAlcohol) then
		Intoxicate(client)
	end

	if (item.effectFunctions and item.effectFunctions.SERVER) then
		item.effectFunctions.SERVER(item, client)
	end
end

--[[
	Eat and Drink are the same action with different labels and icons.

	Their split is by stat: anything with sustenance is eaten, anything that is
	purely hydration is drunk. Kept, because it is what makes a bottle of water
	say "Drink" and a stew say "Eat" without either item declaring which.
]]
ITEM.functions.Eat = {
	name = "eat",
	icon = "icon16/cake.png",

	OnRun = function(item)
		Consume(item)

		return true
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
			and (item.sustenance or 0) > 0
	end
}

ITEM.functions.Drink = {
	name = "drink",
	icon = "icon16/drink.png",

	OnRun = function(item)
		Consume(item)

		return true
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
			and (item.sustenance or 0) == 0 and (item.hydration or 0) > 0
	end
}

--[[
	Feeding someone else.

	A five-second stared action, so both parties have to stand still and either
	can walk away from it. Phoenix used their recognition plugin for the names;
	that is not ported, so character names are used directly.
]]
ITEM.functions.Feed = {
	name = "feed",
	icon = "icon16/user_go.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client) or not client:Alive()) then return false end

		local target = client:GetEyeTrace().Entity

		if (not IsValid(target) or not target:IsPlayer()) then return false end

		local theirCharacter = target:GetCharacter()
		local ourCharacter = client:GetCharacter()

		if (not theirCharacter or not ourCharacter) then return false end

		local verb = item.feedFlavour or "feed"

		target:ChatPrint(string.format("%s is trying to %s you with %s.",
			ourCharacter:GetName(), verb, item.name))
		client:ChatPrint(string.format("You begin %sing %s with %s.",
			verb, theirCharacter:GetName(), item.name))

		client:SetAction(verb .. "ing...", 5)
		client:DoStaredAction(target, function()
			--[[
				Re-checked on completion. Five seconds is long enough for the
				item to have been dropped, traded or eaten by then, and feeding
				someone with an item that no longer exists would hand out free
				sustenance.
			]]
			if (not IsValid(target) or not item:GetOwner()) then return end

			target:ChatPrint(string.format("You have been fed %s.", item.name))
			client:ChatPrint(string.format("You fed %s with %s.",
				theirCharacter:GetName(), item.name))

			Consume(item, target)
			item:Remove()
		end, 5, function()
			client:ChatPrint(string.format("You stop %sing %s.",
				verb, theirCharacter:GetName()))
			client:SetAction()
		end, 200)

		return false
	end,

	OnCanRun = function(item)
		local client = item.player

		if (IsValid(item.entity) or not IsValid(client) or not client:Alive()) then
			return false
		end

		local target = client:GetEyeTrace().Entity

		return IsValid(target) and target:IsPlayer()
	end
}

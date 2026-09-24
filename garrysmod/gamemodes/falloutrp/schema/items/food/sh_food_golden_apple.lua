ITEM.name = "Golden Apple"
ITEM.description = "A shiny golden apple that radiates an unusual warmth. It is said to bestow great power upon those who consume it."
ITEM.category = "Food"

--[[
	The doubled `models/` is NOT a typo. The content pack really does ship this
	at `models/models/fallout/apple1.mdl`, and `models/fallout/apple1.mdl` does
	not exist - correcting it would break the item.
]]
ITEM.model = "models/models/fallout/apple1.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 1
ITEM.radiation = 0

ITEM.eatMeText = "eats a Golden Apple."

--[[
	A cheat item: Phoenix's version sets you to level 50 outright.

	Written against the XP rather than the level. Setting `level` directly -
	which is what theirs did - skips every level in between, and skill points
	are awarded per level crossed, so a player would arrive at 50 with nothing
	to spend. Giving them the XP and letting `CheckLevel` promote them means
	they get the fifty levels' worth of points they should have.
]]
ITEM.effectFunctions = {
	SERVER = function(item, client)
		local character = client:GetCharacter()

		if (not character or not ix.leveling) then return end

		local target = ix.leveling.spike

		if (character:GetLevel() >= target) then
			client:ChatPrint("The apple tastes incredible. You are already past it.")
			return
		end

		character:SetXP(math.max(character:GetXP(), ix.leveling.RequiredXP(target)))
		character:CheckLevel()
	end
}

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end

ITEM.name = "Super Mutant Oasis Hood"
ITEM.description = "Has the word Ooga stitched into it's cloth."
ITEM.model = "models/fallout/hoodoasis.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mutant/robeshood.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/robeshood.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 38
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Super Mutants"

ITEM.specialBonus = {
	agility = 2
}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = true,
    ["nightkin"] = true,
    ["securitron"] = false
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

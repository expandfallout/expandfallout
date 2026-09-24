ITEM.name = "Followers Mutant Labcoat"
ITEM.description = "A large coat worn by mutants of the FoA."
ITEM.model = "models/fallout/apparel/labcoat.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/mutant/FOASM.mdl"
ITEM.maleModel = "models/widowz/fallout/player/mutant/FOASM.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 32
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "FoA"

ITEM.specialBonus = {
	intelligence = 2
}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = true,
    ["nightkin"] = true,
    ["securitron"] = false
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

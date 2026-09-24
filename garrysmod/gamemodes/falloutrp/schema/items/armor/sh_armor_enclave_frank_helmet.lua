ITEM.name = "Modified Secret Service Power Armor Helmet"
ITEM.description = "A modified version of power armor, designed to fit a larger frame."
ITEM.model = "models/fallout/apparel/adpowerarmorhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mutant/frankhorriganhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/frankhorriganhelmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	intelligence = 3,
	agility = 3
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = true
}

ITEM.armorRace = {
    ["frankhorrigan"] = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

ITEM.name = "Modified Secret Service Power Armor"
ITEM.description = "A modified version of power armor, designed to fit a larger frame."
ITEM.model = "models/fallout/apparel/adpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mutant/frankhorrigan.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/frankhorrigan.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {
    [1] = 1,
    [2] = 1,
}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	perception = 3
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
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

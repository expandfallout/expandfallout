ITEM.name = "X-57 Wrath Helmet"
ITEM.description = "The matching helmet to the X-57 Wrath set."
ITEM.model = "models/fallout/apparel/enclave_power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/mutant/wrathpahelmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/mutant/wrathpahelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 55
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Unity"

ITEM.specialBonus = {}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = true,
    ["nightkin"] = true,
    ["securitron"] = false
}

ITEM.takesType = {
    hat = false,
    mask = true,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

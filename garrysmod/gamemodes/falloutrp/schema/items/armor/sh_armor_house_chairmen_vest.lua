ITEM.name = "Chairmen Security Vest"
ITEM.description = "A body armor used by the Chairmen."
ITEM.model = "models/fallout/apparel/tophat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "bodyAccessory"

ITEM.femaleModel = "models/widowz/fallout/player/faction/chairmenarmor.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/chairmenarmor.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "House"

ITEM.specialBonus = {
	strength = 2,
	endurance = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
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

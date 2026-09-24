ITEM.name = "West-Tek Corporate Uniform"
ITEM.description = "A corporate uniform associated with the pre-war government and it's contractors, this one is emblazoned with West-Tek decals."
ITEM.model = "models/fallout/apparel/combatranger.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/enclaveinteloutfit.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/enclaveinteloutfit.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "West-Tek"
ITEM.factionClass = "High Command - West-Tek"

ITEM.specialBonus = {
	endurance = 4,
	charisma = 3,
	intelligence = 3
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

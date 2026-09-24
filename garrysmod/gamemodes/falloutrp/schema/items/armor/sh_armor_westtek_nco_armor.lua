ITEM.name = "Happy Trails Caravaneer Outfit"
ITEM.description = "Travelling trader attire for any do-good caravaneer."
ITEM.model = "models/fallout/apparel/combatranger.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/mothmanhunteroutfit.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/mothmanhunteroutfit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Happy Trails"
ITEM.factionClass = "NCO - Happy Trails"

ITEM.specialBonus = {
	intelligence = 1,
	luck = 1
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

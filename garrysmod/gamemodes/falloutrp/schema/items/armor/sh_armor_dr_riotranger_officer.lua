ITEM.name = "Riot Ranger Advanced Riot Gear"
ITEM.description = "The standardized armor used by the combat engineers of the Riot Rangers. | Riot Ranger Officer Armor"
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/ranger/advancedriotgearf.mdl"
ITEM.maleModel = "models/galang/fallout/player/ranger/advancedriotgear.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = -10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Riot Rangers"

ITEM.specialBonus = {
	perception = 2
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

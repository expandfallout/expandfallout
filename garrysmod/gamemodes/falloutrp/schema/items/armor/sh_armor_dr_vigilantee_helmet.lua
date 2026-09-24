ITEM.name = "Vigilantee Ranger Helmet"
ITEM.description = "A modified rusty Ranger helmet, often a hand me down."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/rhys/fallout/player/shared/lone_ranger/models/loneranger_helmet.mdl"
ITEM.maleModel = "models/rhys/fallout/player/shared/lone_ranger/models/loneranger_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 66
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 40
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "DR"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = false,
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

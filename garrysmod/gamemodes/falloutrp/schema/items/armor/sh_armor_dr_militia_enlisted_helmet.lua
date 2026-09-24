ITEM.name = "Militia NCO Combat Helmet"
ITEM.description = "A standardized ranger helmet used by the Militia. | Militia NCO Armor"
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/widowz/fallout/player/faction/dr/militancohelmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/dr/militancohelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 69
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 40
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Militia"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

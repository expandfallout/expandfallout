ITEM.name = "Proto-Stealth Helmet"
ITEM.description = "A prototype stealth suit, much of its armor plating has been reduced in exchange for speed and manuverability. The helmet seems to be designed to handle bare minimum radiation exposure."
ITEM.model = "models/fallout/apparel/stealthsuithelm.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/rhys/fallout/player/shared/assassin_suit/models/assassinsuit_helmet.mdl"
ITEM.maleModel = "models/rhys/fallout/player/shared/assassin_suit/models/assassinsuit_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 15
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.hasStealth = true

ITEM.faction = "Boulder Dome"

ITEM.specialBonus = {}

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

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    ix.armor.SetStealth(client, false)
    return true
end

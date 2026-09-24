ITEM.name = "Pitt Raider Power Helmet"
ITEM.description =  "A power armor helmet used by the Raiders. | Pitt Raider Lead Armor"
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/powerarmor/f4/raiderpahelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/powerarmor/f4/raiderpahelmet.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Pitt Raiders"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

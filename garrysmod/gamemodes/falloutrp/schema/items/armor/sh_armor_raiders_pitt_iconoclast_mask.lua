ITEM.name = "Pitt Iconoclast Mask"
ITEM.description =  "A gas mask used by the Pitt Raiders. | Pitt Raider Officer Armor"
ITEM.model = "models/fallout/apparel/minerhelmetgo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/rhys/fallout/player/shared/raider_iconocast/minerhelmet.mdl"
ITEM.maleModel = "models/rhys/fallout/player/shared/raider_iconocast/minerhelmet.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 60
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Pitt Raiders"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
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

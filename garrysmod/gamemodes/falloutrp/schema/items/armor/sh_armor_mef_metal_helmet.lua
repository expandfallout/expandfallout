ITEM.name = "Metal Combat Armor Helmet"
ITEM.description = "Helmet made of scrap metal issued to enlisted within the MEF | ENLISTED ARMOR"
ITEM.model = "models/fallout/apparel/mark2combathelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/rhys/fallout/player/shared/classic_metal_mk2/models/classic_metal_helmet_mk2.mdl"
ITEM.maleModel = "models/rhys/fallout/player/shared/classic_metal_mk2/models/classic_metal_helmet_mk2.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "MEF"

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
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

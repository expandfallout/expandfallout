ITEM.name = "T-51b Helmet"
ITEM.description = "T-51b Power Armor Helmet"
ITEM.model = "models/fallout_4/actors/powerarmor/mods/t51/helm.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_helm"

ITEM.femaleModel = "models/fallout_4/actors/powerarmor/mods/t51/helm.mdl"
ITEM.maleModel = "models/fallout_4/actors/powerarmor/mods/t51/helm.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.isF4PA = true
ITEM.noCore = false

ITEM.faction = "Happy-Trails"

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
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

ITEM.name = "T-51 Power Armor Helmet"
ITEM.description =  "A T-51 power armor helmet. | West-Tek Officer Armor"
ITEM.model = "models/fallout/apparel/t51bpowerhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/powerarmor/f4/t51helmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/powerarmor/f4/t51helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 100
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "West Tek"

ITEM.specialBonus = {
	intelligence = 2
}

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

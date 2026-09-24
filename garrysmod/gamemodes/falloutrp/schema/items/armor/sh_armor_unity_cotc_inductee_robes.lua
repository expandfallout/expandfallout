ITEM.name = "COTC Inductee Robes"
ITEM.description = "A set of purple robes, fit for priests of the holy flame."
ITEM.model = "models/fallout/apparel/centuriongo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/cotcrobesf.mdl"
ITEM.maleModel = "models/galang/fallout/player/cotcrobesm.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Unity"

ITEM.specialBonus = {
	intelligence = 2
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

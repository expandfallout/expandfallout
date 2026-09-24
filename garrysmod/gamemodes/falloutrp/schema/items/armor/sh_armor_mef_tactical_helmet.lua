ITEM.name = "Tactical Power Armor Helmet"
ITEM.description = "A standard issue power armor helmet worn in the MEF. | OFFICER ARMOR"
ITEM.model = "models/fallout/apparel/mwpahelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mef/mwhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/mef/mwhelmet.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 78
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "MEF"

ITEM.specialBonus = {
	perception = 2
}

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
    return true
end

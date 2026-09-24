ITEM.name = "Zealot Power Armor Helmet"
ITEM.description = "A ramshackle power armor helmet used in the MEF | NCO ARMOR"
ITEM.model = "models/fallout/apparel/mwpahelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mef/zmwhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/mef/zmwhelmet.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 75
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

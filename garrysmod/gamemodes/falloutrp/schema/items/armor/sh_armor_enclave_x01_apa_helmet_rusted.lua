ITEM.name = "Wheathered X-01 Advanced Powered Helmet"
ITEM.description = "The matching helmet to the Enclave's APA. | HIGH COMMAND ARMOR"
ITEM.model = "models/fallout/apparel/adpowerarmorhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/remnant_helmet.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/remnant_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	perception = 4
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

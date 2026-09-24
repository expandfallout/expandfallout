ITEM.name = "Eyepatch"
ITEM.description = "A simple eyepatch."
ITEM.model = "models/fallout/glasses/glassesreading.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "eyes"

ITEM.femaleModel = "models/rhys/fallout/player/shared/eyepatch/models/eyepatch.mdl"
ITEM.maleModel = "models/rhys/fallout/player/shared/eyepatch/models/eyepatch.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	perception = 2,
	luck = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = true,
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

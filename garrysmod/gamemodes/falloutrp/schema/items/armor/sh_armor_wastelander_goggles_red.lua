ITEM.name = "Goggles, Red"
ITEM.description = "A pair of simple red goggles."
ITEM.model = "models/fallout/glasses/glassesreading.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "eyes"

ITEM.femaleModel = "models/roadkill/fallout/player/customorders/crab/male/armor/dragonskin_goggles.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/customorders/crab/male/armor/dragonskin_goggles.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

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

ITEM.name = "Coordinators Headset"
ITEM.description = "A simple cloth wrap for the head."
ITEM.model = "models/roadkill/fallout/player/customorders/crab/male/headgear/coordinatorheadset.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/customorders/crab/male/headgear/coordinatorheadset.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/customorders/crab/male/headgear/coordinatorheadset.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 40
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
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

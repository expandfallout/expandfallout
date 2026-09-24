ITEM.name = "Legion Backpack"
ITEM.description = "A backpack used by the Legion."
ITEM.model = "models/galang/fallout/clutter/classicbackpack.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "backpack"

ITEM.femaleModel = "models/rhys/fallout/player/shared/canvas_backpack/models/canvas_backpack.mdl"
ITEM.maleModel = "models/rhys/fallout/player/shared/canvas_backpack/models/canvas_backpack.mdl"

ITEM.skin = false
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

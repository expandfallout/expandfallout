ITEM.name = "Santa Hat"
ITEM.description = "A festive Santa hat to spread holiday cheer."
ITEM.model = "models/catmop/fallout/props/christmaspresent.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/santahat.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/santahat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 12
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

ITEM.name = "Van Graff HC Armor"
ITEM.description = "A set of combat armor used by the Van Graff."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/vgfrostwalker.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/vgfrostwalker.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "VG"

ITEM.specialBonus = {
	charisma = 3
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

ITEM.name = "Desert Ranger Vigilantee Armor"
ITEM.description = "Leather jacket bitch."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/rhys/fallout/player/male/armor/lone_ranger/models/loneranger.mdl"
ITEM.maleModel = "models/rhys/fallout/player/male/armor/lone_ranger/models/loneranger.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 66
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "DR"

ITEM.specialBonus = {
	perception = 1
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

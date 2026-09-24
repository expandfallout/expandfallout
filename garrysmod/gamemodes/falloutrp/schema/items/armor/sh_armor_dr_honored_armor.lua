ITEM.name = "Desert Ranger Honored Armor"
ITEM.description = "A sandy desert ranger armor used by those who have honored the past."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/nvdlc02/armor/desert_ranger_combat_armor.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/nvdlc02/armor/desert_ranger_combat_armor.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "DR"

ITEM.specialBonus = {
	perception = 3
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

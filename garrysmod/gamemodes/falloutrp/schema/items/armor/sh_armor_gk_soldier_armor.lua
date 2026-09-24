ITEM.name = "Great Khan Soldier Armor"
ITEM.description = "A modified Khan armor used by their soldiers in battle."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/greatkhan_soldier.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/greatkhan_soldier.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 65
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "GK"

ITEM.specialBonus = {
	perception = 1,
	endurance = 1
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

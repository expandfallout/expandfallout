ITEM.name = "Great Khan Papa Khan Armor"
ITEM.description = "An armor worn by Papa Khan."
ITEM.model = "models/catmop/fallout/props/papakhanarmor_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/papakhanarmor.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/papakhanarmor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "GK"

ITEM.specialBonus = {
	endurance = 4
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

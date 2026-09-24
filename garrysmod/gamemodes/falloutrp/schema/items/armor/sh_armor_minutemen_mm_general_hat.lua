ITEM.name = "Minutemen General Tricorne"
ITEM.description = "A hat worn by the leader of the minutemen"
ITEM.model = "models/galang/fallout/player/minutemengeneralhatgo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/minutemengeneralhat.mdl"
ITEM.maleModel = "models/galang/fallout/player/minutemengeneralhat.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Minutemen"

ITEM.specialBonus = {
	perception = 2
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

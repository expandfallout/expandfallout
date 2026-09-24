ITEM.name = "Militia NCO Gear"
ITEM.description = "The standardized armor used by the BRAVE HEROES of the Militia. | Militia NCO Armor"
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/faction/dr/militanco.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/dr/militanco.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 69
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Militia"

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
    hair = true,
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

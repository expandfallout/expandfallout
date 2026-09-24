ITEM.name = "Militia Lead Gear"
ITEM.description = "The elite armor used by the BRAVE HEROES of the Militia. | Militia Lead Armor"
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/faction/dr/militaflarmor.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/dr/militaflarmor.mdl"

ITEM.textureReplace = {
    ["galang/fallout/player/ranger/advancedelite/eliteriotgear"] = "galang/fallout/player/roguerangers/rogueranger2",
    ["galang/fallout/player/ranger/advancedelite/eliteriotgearcoat"] = "galang/fallout/player/roguerangers/rogueranger5",
    ["galang/fallout/player/ranger/riot/riotgearcoat"] = "galang/fallout/player/roguerangers/rogueranger5",
    ["galang/fallout/player/ranger/riot/riotgear"] = "galang/fallout/player/roguerangers/rogueranger2",
}


ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 20
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Militia"

ITEM.specialBonus = {
	perception = 2
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

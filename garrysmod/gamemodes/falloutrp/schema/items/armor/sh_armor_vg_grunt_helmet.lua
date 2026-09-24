ITEM.name = "Van Graff Grunt Helmet"
ITEM.description = "A combat helmet used by the Van Graff."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/combatarmor_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/combatarmor_helmet.mdl"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/headware/combatarmorhelmet"] = "catmop/fallout/player/male/headware/combatarmorhelmet",
}

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "VG"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = false,
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

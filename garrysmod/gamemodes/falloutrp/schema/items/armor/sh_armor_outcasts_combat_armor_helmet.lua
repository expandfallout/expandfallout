ITEM.name = "Outcasts Combat Armor Helmet"
ITEM.description = "A combat helmet used by the Outcasts."
ITEM.model = "models/roadkill/fallout/player/dropmodel/armor/bos_combat_helmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/bos_combat_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/bos_combat_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/bos_combat/helmet"] = "galang/fallout/player/outcasts/OutcastHelmet",
}

ITEM.resistance = 65
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 25
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Outcasts"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
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

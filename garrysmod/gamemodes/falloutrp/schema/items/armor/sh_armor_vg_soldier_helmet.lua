ITEM.name = "Van Graff Soldier Helmet"
ITEM.description = "A combat helmet used by the Van Graff."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/bos_combat_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/bos_combat_helmet.mdl"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/bos_combat/helmet"] = "catmop/fallout/player/male/armor/cbarmor/cbhelmet",
    ["roadkill/fallout/player/male/armor/bos_combat/visor"] = "catmop/fallout/player/male/armor/cbarmor/cbvisor",
}

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 30
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

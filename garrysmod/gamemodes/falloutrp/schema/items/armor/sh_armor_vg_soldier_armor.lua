ITEM.name = "Van Graff Soldier Armor"
ITEM.description = "A set of combat armor used by the Van Graff."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/bos_combat_armor_shoulderless.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/bos_combat_armor_shoulderless.mdl"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/bos_combat/armor_d"] = "catmop/fallout/player/male/armor/cbarmor/cbarmor",
    ["roadkill/fallout/player/male/armor/bos_combat/body_d"] = "catmop/fallout/player/male/armor/cbarmor/cbbody",
    ["roadkill/fallout/player/male/armor/bos_combat/pents"] = "catmop/fallout/player/male/armor/cbarmor/cblegs",
}

ITEM.skin = 2
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "VG"

ITEM.specialBonus = {
	intelligence = 1
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

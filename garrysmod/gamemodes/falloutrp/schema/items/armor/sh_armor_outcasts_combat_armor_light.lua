ITEM.name = "Outcast Light Combat Armor"
ITEM.description = "A light combat armor used by the Outcasts."
ITEM.model = "models/roadkill/fallout/player/dropmodel/armor/bos_combat_light.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/bos_combat_light_f.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/bos_combat_light_m.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/bos_combat/body_d"] = "galang/fallout/player/outcasts/OutcastBody",
    ["roadkill/fallout/player/male/armor/bos_combat/pents"] = "galang/fallout/player/outcasts/OutcastPants",
	["roadkill/fallout/player/male/armor/bos_combat/armor_d"] = "galang/fallout/player/outcasts/OutcastArmor"
}

ITEM.resistance = 63
ITEM.speedBoost = -13
ITEM.jumpBoost = 35
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Outcasts"

ITEM.specialBonus = {
	intelligence = 2
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

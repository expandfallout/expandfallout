ITEM.name = "Shi T-49 Armor"
ITEM.description = "A set of T-49 power armor used by the Shi."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/t-49.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/t-49.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/t-49/powerarmorbody"] = "galang/fallout/player/t45/shi/shit45",
    ["roadkill/fallout/player/male/armor/t-49/paglove_t45metal_d"] = "galang/fallout/player/t51/shi/shipaglove",
	["roadkill/fallout/player/male/armor/t-49/mark2combat"] = "galang/fallout/player/t49/shi/shit49combat",
	["roadkill/fallout/player/male/armor/t-49/adpowerarmorbody"] = "galang/fallout/player/t49/shi/shit49pauldron",
  	["roadkill/fallout/player/male/armor/t-49/ncr_powerarmor"] = "roadkill/fallout/player/male/armor/ncr/ncr_powerarmor",
}

ITEM.faction = "shi"

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

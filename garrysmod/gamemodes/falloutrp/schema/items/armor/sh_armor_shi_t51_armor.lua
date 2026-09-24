ITEM.name = "Shi T-51b Armor"
ITEM.description = "A set of T-51b power armor used by the Shi."
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "shi"

ITEM.textureReplace = {
	["roadkill/fallout/player/male/armor/t-51b/t-51b_powerarmor"] = "galang/fallout/player/t51/shi/shit51",
	["roadkill/fallout/player/male/armor/t-51b/paglove_t51metal_d"] = "galang/fallout/player/t51/shi/shipaglove"
}

ITEM.specialBonus = {
	intelligence = 3
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

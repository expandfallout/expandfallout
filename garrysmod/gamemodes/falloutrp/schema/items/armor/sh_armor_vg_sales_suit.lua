ITEM.name = "Van Graff Sales Suit"
ITEM.description = "A suit used by the Van Graff."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/pre-war_businesswear.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/pre-war_businesswear.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.textureReplace = {
	["roadkill/fallout/player/male/clothing/pre-war_businesswear/pre-war_businesswear_m"] = "galang/fallout/player/VGSuit",
}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "VG"

ITEM.specialBonus = {
	luck = 4
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

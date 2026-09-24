ITEM.name = "Metal Combat Armor"
ITEM.description = "Armor made of scrap metal issued to enlisted within the MEF | ENLISTED ARMOR"
ITEM.model = "models/fallout/apparel/metalarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/rhys/fallout/player/female/armor/classic_metal_mk2/models/classic_metal_mk2.mdl"
ITEM.maleModel = "models/rhys/fallout/player/male/armor/classic_metal_mk2/models/classic_metal_mk2.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = -8
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.textureReplace = {
    ["rhys/fallout/player/male/armor/classmetal_mk2/metal_mk2_body"] = "galang/fallout/player/mef/metalbody",
}

ITEM.faction = "MEF"

ITEM.specialBonus = {
	perception = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
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

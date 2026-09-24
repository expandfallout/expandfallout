ITEM.name = "House White Glove Mask"
ITEM.description = "A mask worn by members of House White Glove."
ITEM.model = "models/roadkill/fallout/player/dropmodel/armor/bos_combat_reinforced.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "mask"

ITEM.femaleModel = "models/roadkill/fallout/player/male/masks/white_mask.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/masks/white_mask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "House"

ITEM.specialBonus = {
	charisma = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = true,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

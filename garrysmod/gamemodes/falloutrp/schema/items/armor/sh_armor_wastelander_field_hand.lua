ITEM.name = "Field Hand Outfit"
ITEM.description = "An outfit worn by field hands in the wasteland."
ITEM.model = "models/thespireroleplay/items/clothes/group003.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/field_hand_outfit.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/field_hand_outfit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 45
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	endurance = 2
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

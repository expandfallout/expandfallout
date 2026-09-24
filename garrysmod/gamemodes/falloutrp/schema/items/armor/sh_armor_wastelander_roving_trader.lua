ITEM.name = "Roving Trader Outfit"
ITEM.description = "An outfit commonly worn by traders in the wasteland."
ITEM.model = "models/thespireroleplay/items/clothes/group104.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/roving_trader.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/roving_trader.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 50
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	endurance = 1,
	charisma = 1
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

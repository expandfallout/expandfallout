ITEM.name = "Naughty Nightware"
ITEM.description = "A comfortable set of nightware popular in the wasteland."
ITEM.model = "models/thespireroleplay/items/clothes/group001.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/naughty_nightwear.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/naughty_nightwear.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 40
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	luck = 2
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

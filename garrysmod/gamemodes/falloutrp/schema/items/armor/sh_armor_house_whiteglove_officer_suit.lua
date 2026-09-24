ITEM.name = "House White Glove NCO Suit"
ITEM.description = "A suit worn by higher rank employees of the White Gloves."
ITEM.model = "models/catmop/fallout/props/tuxedogo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/whitegloveofficerf.mdl"
ITEM.maleModel = "models/galang/fallout/player/whitegloveofficer.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 65
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

ITEM.name = "BoS Head Scribe Robes"
ITEM.description = "Robes worn by the head scribe of the Brotherhood of Steel."
ITEM.model = "models/thespireroleplay/items/clothes/group102.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/clothing/brotherhood_elder2.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/clothing/brotherhood_elder2.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 65
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 35
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "High Command - Scribe"

ITEM.specialBonus = {
	intelligence = 8
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

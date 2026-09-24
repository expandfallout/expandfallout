ITEM.name = "BoS Elder Robes"
ITEM.description = "Robes worn by the elders of the Brotherhood of Steel."
ITEM.model = "models/thespireroleplay/items/clothes/group102.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/clothing/brotherhood_elder.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/brotherhood_elder.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.textureReplace = {
	["roadkill/fallout/player/male/clothing/brotherhood_elder/brotherhood_elder"] = "galang/fallout/player/warlock/WarlockElder",
}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 35
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "High Command - Elder"

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

ITEM.name = "Outcasts Scribe Robes"
ITEM.description = "Robes worn by the scribes of the Outcasts."
ITEM.model = "models/thespireroleplay/items/clothes/group102.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/clothing/brotherhood_scribe.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/clothing/brotherhood_scribe.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/clothing/brotherhood_scribe/brotherhood_scribe_m"] = "galang/fallout/player/outcasts/ScribeOutcast",
	["roadkill/fallout/player/female/clothing/brotherhood_scribe/brotherhood_scribe_f"] = "galang/fallout/player/outcasts/ScribeOutcastF",
}

ITEM.resistance = 55
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 35
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Outcasts"

ITEM.specialBonus = {
	intelligence = 6
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

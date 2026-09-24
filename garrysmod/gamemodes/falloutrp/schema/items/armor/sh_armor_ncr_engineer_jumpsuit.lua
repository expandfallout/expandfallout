ITEM.name = "NCR Engineer Jumpsuit"
ITEM.description = "A standard jumpsuit worn by NCR Engineers."
ITEM.model = "models/thespireroleplay/items/clothes/group101.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/engineer_jumpsuit.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/engineer_jumpsuit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

ITEM.textureReplace = {
	["roadkill/fallout/player/male/clothing/engineer_jumpsuit/engineer_jumpsuit_m"] = "catmop/fallout/player/male/clothing/hooverdamjumpsuit/ncrhooverdamjumpsuitmale",
	["roadkill/fallout/player/female/clothing/engineer_jumpsuit/engineer_jumpsuit_m"] = "catmop/fallout/player/female/clothing/hooverdamjumpsuit/ncrhooverdamjumpsuitfemale"
}

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

ITEM.name = "Followers Scrubs"
ITEM.description = "Doctor Scrubs worn by officers within the FOA | Officer"
ITEM.model = "models/fallout/apparel/labcoat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/scientistscrubs.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/scientistscrubs.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 30
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/clothing/scientistscrubs/scientist_scrubs"] = "roadkill/fallout/player/male/clothing/scientistscrubs/scientist_scrubs_w",
}

ITEM.faction = "FOA"

ITEM.specialBonus = {
	intelligence = 3
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

ITEM.name = "Boulder Dome Red Scrubs"
ITEM.description = "A set of lab scrubs used by the brightest minds..."
ITEM.model = "models/fallout/apparel/leatherarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/scientistscrubs.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/scientistscrubs.mdl"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/clothing/scientistscrubs/scientist_scrubs"] = "roadkill/fallout/player/male/clothing/scientistscrubs/scientist_scrubs_r",
}

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Boulder Dome"

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

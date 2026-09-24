ITEM.name = "Zetan Spacesuit, No Helmet"
ITEM.description = "A spacesuit work by the Zetans, designed for use in hostile environments."
ITEM.model = "models/models/fallout/alienbox.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill_fallout/player/zetan/defaultbody.mdl"
ITEM.maleModel = "models/roadkill_fallout/player/zetan/defaultbody.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {
    [0] = 3
}

ITEM.armorRace = {
    ["zetan"] = true
}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Zetan"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

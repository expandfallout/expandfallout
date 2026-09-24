ITEM.name = "Old Cowboy Hat"
ITEM.description = "A weathered cowboy hat, perfect for keeping the sun out of your eyes."
ITEM.model = "models/fallout/apparel/cowboyhat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/old_cowboy_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/old_cowboy_hat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 45
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

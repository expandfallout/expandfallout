ITEM.name = "Rattan Cowboy Hat"
ITEM.description = "A rugged cowboy hat made from Rattan."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/rattan_cowboy_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/rattan_cowboy_hat.mdl"

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

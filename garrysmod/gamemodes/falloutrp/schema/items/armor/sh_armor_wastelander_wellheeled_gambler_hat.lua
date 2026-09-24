ITEM.name = "Well-Heeled Gambler Hat"
ITEM.description = "A fancy hat worn by high-stakes gamblers in the wasteland."
ITEM.model = "models/props_junk/trafficcone001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/well-heeled_gambler_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/well-heeled_gambler_hat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 50
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

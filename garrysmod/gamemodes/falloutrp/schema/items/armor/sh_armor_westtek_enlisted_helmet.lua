ITEM.name = "Tinkers Goggles"
ITEM.description = "Some thrown together welding goggles, effective but ugly."
ITEM.model = "models/models/fallout/supermgoggles.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/tinkerersgoggles.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/tinkerersgoggles.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Happy Trails"
ITEM.factionClass = "Enlisted - Happy Trails"

ITEM.specialBonus = {
	intelligence = 1,
	luck = 1
}

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

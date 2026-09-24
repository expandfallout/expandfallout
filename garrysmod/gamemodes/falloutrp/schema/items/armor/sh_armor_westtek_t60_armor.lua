ITEM.name = "T-60 Power Armor"
ITEM.description = "A set of T-60 power armor."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.playerHeight = 1.1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/powerarmor/f4/t60.mdl"
ITEM.maleModel = "models/galang/fallout/player/powerarmor/f4/t60.mdl"

ITEM.skin = 1

ITEM.resistance = 83
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "West Tek"

ITEM.specialBonus = {
	strength = 2,
	endurance = 2,
	intelligence = 2
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

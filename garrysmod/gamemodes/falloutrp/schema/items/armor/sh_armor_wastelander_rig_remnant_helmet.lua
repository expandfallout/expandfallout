ITEM.name = "Rig Remnant Power Armor Helmet"
ITEM.description = "A set if Pre-War power armor, model T-45, heavily rusted and in need of repairs."
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/rigremnanthelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/rigremnanthelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.specialBonus = {
	strength = 1,
	perception = 1,
	endurance = 1,
	charisma = 1,
	intelligence = 1,
	agility = 1,
	luck = 1
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
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

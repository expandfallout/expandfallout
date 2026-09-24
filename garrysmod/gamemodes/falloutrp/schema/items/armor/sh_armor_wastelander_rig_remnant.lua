ITEM.name = "Rig Remnant Armor"
ITEM.description = "Mottled and battle-scarred. Whoever wore this lived through tumultuous times, once it was symbol of evil, that will never change."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/rigremnant.mdl"
ITEM.maleModel = "models/galang/fallout/player/rigremnant.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = -40
ITEM.jumpBoost = 0
ITEM.radResistance = 70
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

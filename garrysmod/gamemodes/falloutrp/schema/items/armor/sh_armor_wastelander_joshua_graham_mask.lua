ITEM.name = "Old Warrior Mask"
ITEM.description = "A colorful mask that adds a touch of whimsy to any outfit."
ITEM.model = "models/props_junk/TrafficCone001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/catmop/fallout/player/male/masks/joshua_grahams_headwrap.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/masks/joshua_grahams_headwrap.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

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
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

ITEM.name = "Elite Proto-Combat Harness"
ITEM.description = "A next generation prototype combat harness, developed in use for covert operations by the U.S. Military pre-war. This variant bears a blue coloration with a reinforced layer of armor plating."
ITEM.model = "models/fallout/apparel/combatarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/boulder/protocombatharness.mdl"
ITEM.maleModel = "models/galang/fallout/player/boulder/protocombatharness.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Boulder Dome"

ITEM.specialBonus = {
	agility = 3
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

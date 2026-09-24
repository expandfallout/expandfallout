ITEM.name = "Advanced Proto-Combat Harness"
ITEM.description = "A next generation prototype combat harness, developed in use for covert operations by the U.S. Military pre-war. This variant bears a red coloration and the armor seems to have been layered with tri-weave graphene."
ITEM.model = "models/fallout/apparel/combatarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/boulder/protocombatharness.mdl"
ITEM.maleModel = "models/galang/fallout/player/boulder/protocombatharness.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = -5
ITEM.jumpBoost = 0
ITEM.radResistance = 15
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Boulder Dome"

ITEM.specialBonus = {
	agility = 2
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

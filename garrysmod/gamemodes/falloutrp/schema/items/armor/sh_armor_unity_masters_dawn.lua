ITEM.name = "The Master's Dawn"
ITEM.description = "A set of power armor fit for the Unity mutant supreme."
ITEM.model = "models/fallout/apparel/enclave_power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mutant/unitypowerarmor.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/unitypowerarmor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 57
ITEM.speedBoost = -30
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Unity"

ITEM.specialBonus = {
	strength = 7,
	agility = 2
}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = true,
    ["nightkin"] = true,
    ["securitron"] = false
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

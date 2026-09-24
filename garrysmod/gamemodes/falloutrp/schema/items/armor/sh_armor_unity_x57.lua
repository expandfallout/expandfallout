ITEM.name = "X-57 MPA"
ITEM.description = "Designed and created by CoTC of the Unity, thought to be lost it is being used once more by the Unity, with slight variation."
ITEM.model = "models/fallout/apparel/enclave_power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/mutant/mpa.mdl"
ITEM.maleModel = "models/widowz/fallout/player/mutant/mpa.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 53
ITEM.speedBoost = -30
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Unity"

ITEM.specialBonus = {
	endurance = 2
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

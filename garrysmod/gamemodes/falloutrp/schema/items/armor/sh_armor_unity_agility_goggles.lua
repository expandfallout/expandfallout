ITEM.name = "Mutant Agility Goggles"
ITEM.description = "A pair of goggles used by supermutants."
ITEM.model = "models/fallout/apparel/enclave_power_armor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "eyes"

ITEM.femaleModel = "models/roadkill/fallout/player/supermutant/goggle3.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/supermutant/goggle3.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Unity"

ITEM.specialBonus = {
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
    eyes = true,
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

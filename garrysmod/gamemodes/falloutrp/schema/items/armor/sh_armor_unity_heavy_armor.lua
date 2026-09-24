ITEM.name = "Unity Heavy Armor"
ITEM.description = "A set of heavy armor fitted for mutants, used by The Unity."
ITEM.model = "models/fallout/apparel/metalarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/supermutant/heavyarmor2.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/supermutant/heavyarmor2.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 45
ITEM.speedBoost = -13
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
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

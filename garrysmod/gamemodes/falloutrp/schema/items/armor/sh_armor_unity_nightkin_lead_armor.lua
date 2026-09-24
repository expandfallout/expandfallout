ITEM.name = "Nightkin Leader Armor"
ITEM.description = "A set of armor fit for the leader of the Master's Nightkin. | Officer Armor"
ITEM.model = "models/fallout/apparel/minerarmorgo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mutant/nightkinlead.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/nightkinlead.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 50
ITEM.speedBoost = 15
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
    ["supermutant"] = false,
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

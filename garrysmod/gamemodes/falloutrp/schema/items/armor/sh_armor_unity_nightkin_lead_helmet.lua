ITEM.name = "Nightkin Leader Helmet"
ITEM.description = "A set of armor fit for the leader of the Master's Nightkin."
ITEM.model = "models/fallout/apparel/minerarmorgo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "mask"

ITEM.femaleModel = "models/galang/fallout/player/mutant/nightkinleadhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/nightkinleadhelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 51
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Unity"

ITEM.specialBonus = {}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = false,
    ["nightkin"] = true,
    ["securitron"] = false
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
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

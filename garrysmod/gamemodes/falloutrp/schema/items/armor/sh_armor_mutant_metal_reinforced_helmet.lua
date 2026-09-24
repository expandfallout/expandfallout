ITEM.name = "Super Mutant Reinforced Metal Helmet"
ITEM.description = "A helmet crafted from metal for a large head."
ITEM.model = "models/fallout/apparel/helmetmetalarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mutant/metalhelmetreinforced.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/metalhelmetreinforced.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 47
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Super Mutants"

ITEM.specialBonus = {}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = true,
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
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

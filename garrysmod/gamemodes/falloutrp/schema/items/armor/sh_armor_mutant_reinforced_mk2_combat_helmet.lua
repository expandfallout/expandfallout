ITEM.name = "Super Mutant Reinforced Combat Helmet MK2"
ITEM.description = "A mark 2 reinforced combat helmet for a very large head."
ITEM.model = "models/fallout/apparel/mark2combathelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mutant/combathelmetMK2.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/combathelmetMK2.mdl"

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

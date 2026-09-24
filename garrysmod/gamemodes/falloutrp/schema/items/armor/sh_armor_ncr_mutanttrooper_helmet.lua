ITEM.name = "NCR Mutant Trooper Helmet"
ITEM.description = "A helmet worn by the New California Republic's Mutants."
ITEM.model = "models/fallout/apparel/trooperhelm.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/supermutant/ncrtrooperhelmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/supermutant/ncrtrooperhelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 35
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

ITEM.specialBonus = {
	perception = 2
}

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

ITEM.name = "NCR Mutant Bandoleer Armor"
ITEM.description = "A set of armor fitted for mutants, used by The New California Republic. | NCO"
ITEM.model = "models/fallout/apparel/trooper.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mutant/ncrbandoleer.mdl"
ITEM.maleModel = "models/galang/fallout/player/mutant/ncrbandoleer.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 40
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

ITEM.specialBonus = {
	endurance = 3
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
    body = true,
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

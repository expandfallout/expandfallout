ITEM.name = "NCR Mutant Ranger Hat"
ITEM.description = "A hat worn by the New Californian Republic's Mutant Rangers."
ITEM.model = "models/fallout/headgear/cowboyhat4.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/supermutant/ncrrangerhat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/supermutant/ncrrangerhat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 43
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

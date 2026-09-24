ITEM.name = "Legion Salvaged Armor"
ITEM.description = "A set of salvaged power armor worn by elite soldiers in Caesar's Legion."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/powerarmor.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/powerarmor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = -38
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 100

ITEM.isPA = false
ITEM.noCore = false
ITEM.isSalvagedPA = true

ITEM.faction = "Legion"
ITEM.factionClass = "NCO"

ITEM.specialBonus = {
	endurance = 3
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

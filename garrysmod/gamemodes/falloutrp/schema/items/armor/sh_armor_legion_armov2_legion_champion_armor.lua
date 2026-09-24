ITEM.name = "Legion Champion Power Armor"
ITEM.description = "A set of Power Armor worn by Champions in Caesar's Legion."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/powerarmor2.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/powerarmor2.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 78
ITEM.speedBoost = -38
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 100

ITEM.isPA = true
ITEM.noCore = false
ITEM.isSalvagedPA = false

ITEM.faction = "Legion"
ITEM.factionClass = "Officer"

ITEM.specialBonus = {
	agility = 2
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

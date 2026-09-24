ITEM.name = "Legion Praetorian Armor"
ITEM.description = "A set of armor worn by the Legions elite Praetorian Guard."
ITEM.model = "models/fallout/apparel/legiongo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/legion_praetorian.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/legion_praetorian.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 50

ITEM.isPA = false
ITEM.noCore = false

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

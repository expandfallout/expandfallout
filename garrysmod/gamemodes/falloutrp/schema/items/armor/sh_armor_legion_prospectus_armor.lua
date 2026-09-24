ITEM.name = "Legion Prospectus Armor"
ITEM.description = "A set of armor worn by Prospectus in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legiongo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/prime.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/prime.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 50

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Enlisted"

ITEM.specialBonus = {
	endurance = 2
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

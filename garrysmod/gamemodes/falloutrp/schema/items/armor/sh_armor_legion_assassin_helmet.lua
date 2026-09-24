ITEM.name = "Legion Assassin Helmet"
ITEM.description = "A set of armor worn by Assassins in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legionhelmetbase_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/assassin_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/assassin_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "NCO"

ITEM.specialBonus = {
	perception = 3
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

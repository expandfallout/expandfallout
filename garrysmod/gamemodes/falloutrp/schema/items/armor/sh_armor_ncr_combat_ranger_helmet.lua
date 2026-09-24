ITEM.name = "NCR Combat Ranger Helmet"
ITEM.description = "A helmet worn by NCR rangers, providing enhanced protection."
ITEM.model = "models/fallout/apparel/combatrangerhelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/ranger/vetrangerhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/ranger/vetrangerhelmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Officer - Rangers"

ITEM.specialBonus = {
	perception = 4
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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

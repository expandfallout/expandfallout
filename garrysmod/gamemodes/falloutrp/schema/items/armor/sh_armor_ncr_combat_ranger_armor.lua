ITEM.name = "NCR Combat Ranger Armor"
ITEM.description = "Armor worn by NCR rangers, providing enhanced protection."
ITEM.model = "models/fallout/apparel/combatranger.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/ranger/vetrangerf.mdl"
ITEM.maleModel = "models/galang/fallout/player/ranger/vetranger.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Officer - Rangers"

ITEM.specialBonus = {
	endurance = 4
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

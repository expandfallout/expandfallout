ITEM.name = "NCR Heavy Combat Armor"
ITEM.description = "An NCR tunic fitted with Combat Armor, including a facewrap to protect against harsh environments."
ITEM.model = "models/fallout/apparel/trooper.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/ncrcombatf.mdl"
ITEM.maleModel = "models/galang/fallout/player/ncrcombat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = -10
ITEM.jumpBoost = 0
ITEM.radResistance = 25
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "SNCO - Infantry"
ITEM.specialBonus = {
	endurance = 3
}

ITEM.takesType = {
    hat = false,
    mask = true,
    eyes = false,
    helmet = false,
    body = true,
}

ITEM.takesBody = {
    hair = false,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

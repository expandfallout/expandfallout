ITEM.name = "Minute Men Conscript Uniform"
ITEM.description = "Armor worn by enlisted of the minutemen"
ITEM.model = "models/thespireroleplay/items/clothes/group052.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/minutemenenlistedf.mdl"
ITEM.maleModel = "models/galang/fallout/player/minutemenenlisted.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Minutemen"

ITEM.specialBonus = {
	endurance = 1
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

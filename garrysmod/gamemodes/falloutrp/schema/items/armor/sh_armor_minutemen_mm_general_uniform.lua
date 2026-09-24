ITEM.name = "Minutemen General Uniform"
ITEM.description = "Blue Coat worn by leaders of the Minutemen"
ITEM.model = "models/thespireroleplay/items/clothes/group021.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/minutemengeneralf.mdl"
ITEM.maleModel = "models/galang/fallout/player/minutemengeneral.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Minutemen"

ITEM.specialBonus = {
	endurance = 4
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

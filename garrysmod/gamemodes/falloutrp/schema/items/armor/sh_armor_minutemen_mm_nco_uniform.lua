ITEM.name = "Minute Men NCO Sheriff Outfit"
ITEM.description = "A sheriff outfit inspired by the western law and order, adapted by the Minutemen."
ITEM.model = "models/thespireroleplay/items/clothes/group007.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/minutemensherriffemale.mdl"
ITEM.maleModel = "models/galang/fallout/player/minutemensherrif.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 15
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Minutemen"

ITEM.specialBonus = {
	endurance = 2
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

ITEM.name = "Powder Ganger Guard"
ITEM.description = "An armor set used by the Powder Gangers. | Powder Ganger Lead Armor"
ITEM.model = "models/fallout/apparel/raiderarmor01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/powder_gang_guard.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/powder_gang_guard.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 20
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Raider"

ITEM.specialBonus = {
	strength = 1,
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

ITEM.name = "Pitt Raider Power Armor"
ITEM.description = "A power armor set used by the leader of the Pitt Raiders. | Pitt Raider Lead Armor"
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/powerarmor/f4/raiderpa.mdl"
ITEM.maleModel = "models/galang/fallout/player/powerarmor/f4/raiderpa.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Pitt Raiders"

ITEM.specialBonus = {
	agility = 3
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

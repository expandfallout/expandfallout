ITEM.name = "Pitt Iconoclast Armor"
ITEM.description = "An armor set used by the Pitt raiders. | Pitt Raider Officer Armor"
ITEM.model = "models/fallout/apparel/raiderarmor03.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/rhys/fallout/player/male/armor/raider_iconocast/raidericonoclast_m_2.mdl"
ITEM.maleModel = "models/rhys/fallout/player/male/armor/raider_iconocast/raidericonoclast_m_2.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = -10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Pitt Raiders"

ITEM.specialBonus = {
	strength = 3
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

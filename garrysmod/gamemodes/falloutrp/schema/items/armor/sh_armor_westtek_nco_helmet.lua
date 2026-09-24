ITEM.name = "Happy Trails Caravaneer Hat"
ITEM.description = "Nice cowboy hat dude."
ITEM.model = "models/models/fallout/supermgoggles.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/mothmanhunterhat.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/mothmanhunterhat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Happy Trails"
ITEM.factionClass = "NCO - Happy Trails"

ITEM.specialBonus = {
	intelligence = 1,
	luck = 1
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

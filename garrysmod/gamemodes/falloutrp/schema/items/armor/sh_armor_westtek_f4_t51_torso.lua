ITEM.name = "T-51b Torso"
ITEM.description = "T-51b Power Armor Torso."
ITEM.model = "models/fallout_4/actors/powerarmor/mods/t51/torso.mdl"

ITEM.width = 2
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_torso"

ITEM.femaleModel = "models/fallout_4/actors/powerarmor/mods/t51/torso.mdl"
ITEM.maleModel = "models/fallout_4/actors/powerarmor/mods/t51/torso.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 17
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 10
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.isF4PA = true
ITEM.noCore = false

ITEM.faction = "Happy-Trails"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

ITEM.name = "Excavator Left Arm"
ITEM.description = "Excavator left arm."
ITEM.model = "models/fallout_4/actors/powerarmor/mods/exc17/larm.mdl"

ITEM.width = 1
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_larm"

ITEM.femaleModel = "models/fallout_4/actors/powerarmor/mods/exc17/larm.mdl"
ITEM.maleModel = "models/fallout_4/actors/powerarmor/mods/exc17/larm.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 15
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

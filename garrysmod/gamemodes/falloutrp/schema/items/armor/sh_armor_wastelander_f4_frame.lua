ITEM.name = "Power Armor Frame"
ITEM.description = "A powerarmor frame, compenents are fitted onto this frame to create a full suit of power armor."
ITEM.model = "models/fallout_4/actors/powerarmor/powerarmorframe.mdl"

ITEM.replaceAnimModel = "models/fallout_4/actors/powerarmor/powerarmorframe.mdl"
ITEM.playerHeight = 1.2

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"

ITEM.bodyType = "body"

ITEM.femaleModel = "models/fallout_4/actors/powerarmor/powerarmorframe.mdl"
ITEM.maleModel = "models/fallout_4/actors/powerarmor/powerarmorframe.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.isF4PA = true
ITEM.noCore = false

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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

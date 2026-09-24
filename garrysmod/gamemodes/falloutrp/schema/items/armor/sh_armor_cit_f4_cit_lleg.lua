ITEM.name = "C.I.T Left Leg"
ITEM.description = "C.I.T Power Armor."
ITEM.model = "models/roadkill/fallout76/powerarmor/mods/cit/lleg.mdl"

ITEM.width = 1
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_lleg"

ITEM.femaleModel = "models/roadkill/fallout76/powerarmor/mods/cit/lleg.mdl"
ITEM.maleModel = "models/roadkill/fallout76/powerarmor/mods/cit/lleg.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 17
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 10
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.isF4PA = true
ITEM.noCore = false

ITEM.faction = "C.I.T"

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

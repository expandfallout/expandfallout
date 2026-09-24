ITEM.name = "T-65 Right Leg"
ITEM.description = "T-65 Right Leg."
ITEM.model = "models/roadkill/fallout76/powerarmor/mods/t65/rleg.mdl"

ITEM.width = 1
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_rleg"

ITEM.femaleModel = "models/roadkill/fallout76/powerarmor/mods/t65/rleg.mdl"
ITEM.maleModel = "models/roadkill/fallout76/powerarmor/mods/t65/rleg.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 18
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 10
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.isF4PA = true
ITEM.noCore = false

ITEM.faction = "Enclave"

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

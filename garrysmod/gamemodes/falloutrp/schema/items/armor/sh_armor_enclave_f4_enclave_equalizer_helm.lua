ITEM.name = "USSS Equalizer Helmet"
ITEM.description = "USSS Equalizer Power Armor, used by the Enclave's Secret Service. Provides excellent protection."
ITEM.model = "models/roadkill/fallout76/powerarmor/mods/equalizer/helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_helm"

ITEM.femaleModel = "models/roadkill/fallout76/powerarmor/mods/equalizer/helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout76/powerarmor/mods/equalizer/helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 100
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

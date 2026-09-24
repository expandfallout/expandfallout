ITEM.name = "Gunners Widow Helmet"
ITEM.description = "USSS Equalizer Power Armor, used by the Enclave's Secret Service. Provides excellent protection."
ITEM.model = "models/fallout_4/actors/powerarmor/mods/t45/helm.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_helm"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/widgunnerhelm.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/widgunnerhelm.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 13
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 100
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.isF4PA = true
ITEM.noCore = false

ITEM.faction = "Gunners"

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

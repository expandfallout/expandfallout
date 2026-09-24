ITEM.name = "Gunners Widow Left Leg"
ITEM.description = "USSS Equalizer Power Armor, used by the Enclave's Secret Service. Provides excellent protection."
ITEM.model = "models/fallout_4/actors/powerarmor/mods/t45/lleg.mdl"

ITEM.width = 1
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "f4_lleg"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/widgunnerlleg.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/widgunnerlleg.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 13
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 10
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

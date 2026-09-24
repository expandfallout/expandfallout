ITEM.name = "Chinese Stealth Armor Helmet"
ITEM.description = "A set of chinese stealth armor used by those aboard the Shih-huang-ti."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/female/headgear/chinese_stealth_armor.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/chinese_stealth_armor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 15
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.hasStealth = true

ITEM.faction = "SHI"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
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
    ix.armor.SetStealth(client, false)
    return true
end

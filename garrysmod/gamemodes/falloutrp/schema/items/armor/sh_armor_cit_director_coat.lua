ITEM.name = "C.I.T Director Coat"
ITEM.description = "A labcoat and vest combination issued to C.I.T's Directors."
ITEM.model = "models/fallout/apparel/wastelandmerchant01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/mosi/fallout4/player/clothing/father.mdl"
ITEM.maleModel = "models/mosi/fallout4/player/clothing/father.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.faction = "C.I.T"

ITEM.resistance = 70
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	intelligence = 4
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
}

ITEM.armorRace = {
    ["human"] = true,
    ["citgen2"] = true,
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

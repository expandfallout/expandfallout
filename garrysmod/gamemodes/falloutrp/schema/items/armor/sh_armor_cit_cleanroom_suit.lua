ITEM.name = "C.I.T Cleanroom Suit"
ITEM.description = "An advanced cleanroom suit issued to C.I.T personnel."
ITEM.model = "models/fallout/apparel/wastelandmerchant01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/institutecleanroom.mdl"
ITEM.maleModel = "models/galang/fallout/player/institutecleanroom.mdl"

ITEM.skin = 0
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

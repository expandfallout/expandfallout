ITEM.name = "C.I.T Dirty G2 Heavy Helmet"
ITEM.description = "A shadowed heavy armor worn by C.I.T G2 Synths for enhanced protection."
ITEM.model = "models/fallout/apparel/wastelandmerchant01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/mosi/fallout4/player/gen2_helmet.mdl"
ITEM.maleModel = "models/mosi/fallout4/player/gen2_helmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = false

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

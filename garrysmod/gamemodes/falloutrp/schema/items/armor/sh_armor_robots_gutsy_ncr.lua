ITEM.name = "Gutsy MK 1 NCR Paint Coat"
ITEM.description = "A set of paint to designate a Gutsy as NCR property."
ITEM.model = "models/mosi/fallout4/props/junk/mrhandyfuel.mdl"

ITEM.width = 1
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/fallout/mistergutsy.mdl"
ITEM.maleModel = "models/fallout/mistergutsy.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.textureReplace = {
	["models/fallout/mistergutsy/mistergutsy"] = "galang/fallout/creatures/gutsy/NV/gutsyncr",
}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

ITEM.specialBonus = {}

ITEM.armorRace = {
    ["human"] = false,
    ["mistergutsy"] = true
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

ITEM.name = "House Securitron, House"
ITEM.description = "A Securitron, with the house screen"
ITEM.model = "models/roadkill/fallout/containers/enclavecrate01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill_fallout/robots/securitron.mdl"
ITEM.maleModel = "models/roadkill_fallout/robots/securitron.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {
    [1] = 2
}

ITEM.armorRace = {
    ["securitron"] = true
}

ITEM.resistance = 30
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "House"

ITEM.specialBonus = {
	charisma = 2
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

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

ITEM.name = "House Securitron, Victor"
ITEM.description = "A Securitron, with the victor screen"
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
    [1] = 3
}

ITEM.armorRace = {
    ["securitron"] = true
}

ITEM.resistance = 40
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "House"

ITEM.specialBonus = {
	perception = 1,
	luck = 1
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

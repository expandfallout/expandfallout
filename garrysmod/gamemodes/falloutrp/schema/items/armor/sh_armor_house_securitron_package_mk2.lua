ITEM.name = "Securitron MK 2 Package"
ITEM.description = "A software package containing upgrade software for the Securitrons OS"
ITEM.model = "models/roadkill/fallout/containers/enclavecrate01.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill_fallout/robots/securitron.mdl"
ITEM.maleModel = "models/roadkill_fallout/robots/securitron.mdl"

ITEM.skin = false
ITEM.bodyGroups = {
    [1] = 1
}

ITEM.armorRace = {
    ["securitron"] = true ,
    ["securitronexecutive"] = true
}

ITEM.resistance = 10
ITEM.speedBoost = 5
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "House"

ITEM.specialBonus = {
	intelligence = 2
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

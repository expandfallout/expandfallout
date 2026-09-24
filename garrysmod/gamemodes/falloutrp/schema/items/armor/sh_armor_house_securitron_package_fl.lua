ITEM.name = "Securitron MK 2 Developer Package"
ITEM.description = "An OS package for the MK 2 upgrade, this edition containing developer tools for software engineering."
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
    [1] = 2
}

ITEM.armorRace = {
    ["securitron"] = true,
    ["securitronexecutive"] = true
}

ITEM.resistance = 20
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "House"

ITEM.specialBonus = {
	intelligence = 3
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

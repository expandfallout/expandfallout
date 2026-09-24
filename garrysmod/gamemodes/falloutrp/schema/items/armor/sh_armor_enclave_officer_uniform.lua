ITEM.name = "Enclave Officer Uniform"
ITEM.description = "A uniform outfit worn by officers of the Enclave. | OFFICER ARMOR"
ITEM.model = "models/catmop/fallout/props/colonelautumn_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/enclave_officer.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/enclave_officer.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = -10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	intelligence = 3
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

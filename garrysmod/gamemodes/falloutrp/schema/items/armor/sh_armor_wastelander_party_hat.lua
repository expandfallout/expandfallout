ITEM.name = "Party Hat"
ITEM.description = "A hat worn for special celebrations and parties."
ITEM.model = "models/fallout/apparel/partyhat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/party_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/party_hat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 25
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	charisma = 1,
	agility = 1,
	luck = 1
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

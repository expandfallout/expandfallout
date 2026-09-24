ITEM.name = "FoA Responders Uniform"
ITEM.description = "A refitted pre-war firefighters uniform, used by Responders of the FoA."
ITEM.model = "models/fallout/apparel/wastelandclothing01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/Faction/FOAFirebaseF.mdl"
ITEM.maleModel = "models/widowz/fallout/player/Faction/FOAFirebase.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 40
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "FOA"

ITEM.specialBonus = {
	intelligence = 4
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

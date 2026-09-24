ITEM.name = "NCR Lead Combat Ranger Helmet"
ITEM.description = "Helmet worn by the leader of NCR rangers, providing enhanced protection."
ITEM.model = "models/fallout/apparel/combatrangerhelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/ranger/eliteriotgearhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/ranger/eliteriotgearhelmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.textureReplace = {
	["galang/fallout/player/ranger/advancedelite/elitehelm"] = "galang/fallout/player/ranger/NCR/RiotHelmetNCR",
	["galang/fallout/player/ranger/advancedelite/elitehelmglow"] = "galang/fallout/player/ranger/NCR/RiotHelmetNCRGlow",
	["galang/fallout/player/ranger/advancedelite/advancedriotparts"] = "galang/fallout/player/ranger/NCR/RiotHelmetNCRAddons",
}

ITEM.resistance = 73
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Lead - Rangers"

ITEM.specialBonus = {
	perception = 4
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

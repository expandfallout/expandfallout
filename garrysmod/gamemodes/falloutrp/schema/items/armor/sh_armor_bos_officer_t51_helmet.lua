ITEM.name = "BoS Officer T-51b Helmet"
ITEM.description =  "A T-51b power armor helmet used by the Officers of the Brotherhood of Steel. | BoS Officer Armor"
ITEM.model = "models/fallout/apparel/t51bpowerhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/t-51b.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.MaterialOverride = {
	["roadkill/fallout/player/male/armor/t-51b/t-51b_army"] = "rhys/fallout/player/male/armor/losthills/classict51pavar",
}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "BoS"
ITEM.factionClass = "Officer - Knights"

ITEM.specialBonus = {
	intelligence = 4
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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end

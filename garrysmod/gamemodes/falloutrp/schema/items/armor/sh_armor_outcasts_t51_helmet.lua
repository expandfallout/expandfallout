ITEM.name = "Outcasts T-51b Helmet"
ITEM.description =  "A T-51b power armor helmet used by the Paladins of the Outcasts."
ITEM.model = "models/fallout/apparel/t51bpowerhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/t-51b.mdl"

ITEM.skin = 2
ITEM.bodyGroups = {}

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/t-51b/t-51b_outcast"] = "galang/fallout/player/outcasts/outcastT51Fixed",
}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Outcasts"

ITEM.specialBonus = {
	intelligence = 2
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

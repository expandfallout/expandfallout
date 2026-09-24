ITEM.name = "BoS Star Paladin T-51b Helmet"
ITEM.description =  "A T-51b power armor helmet used by the star paladins of the Brotherhood of Steel."
ITEM.model = "models/fallout/apparel/t51bpowerhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/t-51b.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "BoS"
ITEM.factionClass = "Officer - Paladins"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/t-51b/t-51b_powerarmor"] = "catmop/fallout/player/male/armor/starpaladin/star51b",
}

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

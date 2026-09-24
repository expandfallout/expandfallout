ITEM.name = "BoS Officer T-51b Armor"
ITEM.description = "A set of T-51b power armor used by the Officers of the Brotherhood of Steel. | BoS Officer Armor"
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {
    [1] = 0
}

ITEM.textureReplace = {
	["roadkill/fallout/player/male/armor/t-51b/t-51b_army"] = "rhys/fallout/player/male/armor/losthills/classict51pavar",
}

ITEM.resistance = 80
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "Officer - Knights"

ITEM.specialBonus = {
	strength = 4
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

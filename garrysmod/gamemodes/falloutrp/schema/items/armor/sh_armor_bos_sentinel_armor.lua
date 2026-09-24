ITEM.name = "BoS Sentinel T-51b Armor"
ITEM.description = "A set of T-51b power armor worn by the sentinel of the Brotherhood of Steel."
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/male/armor/starpaladin.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/starpaladin.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "High Command"

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

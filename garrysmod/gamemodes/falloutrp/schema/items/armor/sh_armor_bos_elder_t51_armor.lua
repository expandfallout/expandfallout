ITEM.name = "BoS Elder T-51b Armor"
ITEM.description = "A set of T-51b power armor used by the elders of the Brotherhood of Steel."
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.textureReplace = {
	["roadkill/fallout/player/male/armor/t-51b/t-51b_powerarmor"] = "widowz/fallout/player/Faction/BOS/t-51bpowarmvarfl",
}

ITEM.resistance = 87
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "BoS"

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

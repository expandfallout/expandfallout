ITEM.name = "BoS T-51b Armor"
ITEM.description = "A set of T-51b power armor used by the Paladins of the Brotherhood of Steel."
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/t-51b.mdl"

ITEM.TextureReplace = {
	["roadkill/fallout/player/male/armor/t-51b/t-51b_powerarmor"] = "models/player/epsilon/t51pstar/star51parmor"
}

ITEM.skin = 0
ITEM.bodyGroups = {
    [0] = 0
}

ITEM.resistance = 78
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "NCO - Paladins"

ITEM.specialBonus = {
	strength = 3
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

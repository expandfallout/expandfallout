ITEM.name = "Outcasts Star Paladin T-51b Armor"
ITEM.description = "A set of T-51b power armor used by the star paladins of the Outcasts."
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/male/armor/starpaladin.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/starpaladin.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.textureReplace = {
    ["catmop/fallout/player/male/armor/starpaladin/star51b"] = "galang/fallout/player/outcasts/OutcastStarT51",
    ["catmop/fallout/player/male/armor/starpaladin/starrobe"] = "galang/fallout/player/outcasts/OutcastLyons",
	["catmop/fallout/player/male/armor/starpaladin/bosparts"] = "galang/fallout/player/outcasts/OutcastParts2",
	["catmop/fallout/player/male/armor/starpaladin/enclaveparts2"] = "galang/fallout/player/outcasts/OutcastParts",
}

ITEM.resistance = 83
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Outcasts"

ITEM.specialBonus = {
	intelligence = 2
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

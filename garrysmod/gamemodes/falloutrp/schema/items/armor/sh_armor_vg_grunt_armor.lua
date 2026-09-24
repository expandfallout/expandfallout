ITEM.name = "Van Graff Grunt Armor"
ITEM.description = "A set of combat armor used by the Van Graff."
ITEM.model = "models/catmop/fallout/props/advancedriotgear_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/combatgraff.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/combatgraff.mdl"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/combatgraff/combat_armor_m"] = "catmop/fallout/player/male/armor/vangraff/uniformm",
    ["roadkill/fallout/player/female/armor/combatgraff/combat_armor_f"] = "catmop/fallout/player/female/armor/vangraff/uniformf",
}

ITEM.skin = 2
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "VG"

ITEM.specialBonus = {
	intelligence = 1
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

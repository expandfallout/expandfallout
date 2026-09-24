ITEM.name = "BoS Light Combat Armor"
ITEM.description = "A light combat armor used by the Brotherhood of Steel."
ITEM.model = "models/roadkill/fallout/player/dropmodel/armor/bos_combat_light.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/bos_combat_light_f.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/bos_combat_light_m.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 35
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "Enlisted"

ITEM.specialBonus = {
	strength = 2
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

ITEM.name = "Legion 87th Tribe Armor"
ITEM.description = "A set of armor worn by blacksmiths in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legatearmor_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/nvdlc04/armor/tribeofthe87th.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/nvdlc04/armor/tribeofthe87th.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 50

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "High Command"

ITEM.specialBonus = {
	endurance = 4
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

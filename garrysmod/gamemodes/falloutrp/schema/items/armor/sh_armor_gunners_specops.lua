ITEM.name = "Gunners Spec-Ops Combat Armor"
ITEM.description = "A set of spec-ops armor worn by the Gunners. | OFFICER"
ITEM.model = "models/fallout/apparel/combatarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnersspecopsoutfitf.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnersspecopsoutfit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Gunners"
ITEM.factionClass = "OFFICER"

ITEM.specialBonus = {
	endurance = 3
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

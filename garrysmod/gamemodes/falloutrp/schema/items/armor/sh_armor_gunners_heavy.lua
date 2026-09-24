ITEM.name = "Gunners Heavy Combat Fatigues"
ITEM.description = "A set of heavy combat fatigues worn by the Gunners. | NCO"
ITEM.model = "models/fallout/apparel/combatarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnerheavycombatoutfitf.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnerheavycombatoutfit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = -8
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Gunners"
ITEM.factionClass = "NCO"

ITEM.specialBonus = {
	perception = 3
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

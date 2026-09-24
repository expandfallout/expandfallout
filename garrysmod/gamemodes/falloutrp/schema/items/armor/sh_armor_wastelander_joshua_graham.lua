ITEM.name = "Old Warrior Garb"
ITEM.description = "Scholar, Warrior, Fanatic. All these words describe the long-lost memory of a man who wore this garb, this armor signifies the ability to turn from your path of evil and step into the light."
ITEM.model = "models/fallout/apparel/formalsuit.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/male/armor/joshua_graham.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/joshua_graham.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	strength = 1,
	perception = 1,
	endurance = 1,
	charisma = 1,
	intelligence = 1,
	agility = 1,
	luck = 1
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
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

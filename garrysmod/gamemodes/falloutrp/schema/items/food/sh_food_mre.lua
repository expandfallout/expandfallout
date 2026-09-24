ITEM.name = "MRE"

ITEM.description = "A military-grade meal."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/food/mre.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.iconCam = {
    pos = Vector(58.465508, 31.797882, 44.101677),
    ang = Angle(-686.521, 928.965, 0.000),
    fov = 13.75
}

ITEM.sustenance = 50 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "eats an MRE."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end

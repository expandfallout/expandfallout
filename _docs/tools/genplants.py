#!/usr/bin/env python
"""
genplants.py

Writes the plant and seed items:

    schema/items/plant/sh_plant_*.lua      20 harvestable / edible plants
    schema/items/seed/sh_seed_*.lua        17 bags of seeds

The DATA is Phoenix's, read out of
`plugins/plants/items/plant/` and `plugins/farming/items/farming/` in the
client scrape. The EFFECTS are declarations rather than closures - see
`items/base/sh_plant.lua` for what each field means and why theirs are twenty
copies of four shapes.

Two model paths are ours rather than theirs: their Tarberry and Tato are at
`models/fallout/consumables/`, which this server does not have. The same two
models exist in `phoenix_dickmosi_stuff` and those paths are used instead -
checked with `resolve_asset.py`, like every other model here.

Run from anywhere:

    python _docs/tools/genplants.py
"""
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.abspath(os.path.join(
    HERE, "..", "..", "garrysmod", "gamemodes", "falloutrp", "schema"))

PLANT_DIR = os.path.join(SCHEMA, "items", "plant")
SEED_DIR = os.path.join(SCHEMA, "items", "seed")

RK = "models/roadkill/fallout/clutter/plants/%s.mdl"
MOSI = "models/mosi/fallout4/props/food/%s.mdl"

#  id: what the file is called and therefore the uniqueID (`plant_<id>`).
#
#  sustenance / hydration / radiation are Phoenix's numbers exactly.
#  heal / hallucinate / knockout / ignite / gamble / hint are their
#  `effectFunctions.SERVER` bodies, read as data.
PLANTS = [
    dict(id="bananayucca", name="Banana Yucca",
         desc="A nutritious plant with medicinal effects.",
         model=RK % "banana_yucca_fruit",
         eat="chews on some raw Banana Yucca . . .",
         rad=3, heal=(1, 1, 10), hint=True),

    dict(id="barrelcactus", name="Barrel Cactus",
         desc="A sweet fruit harvested from a barrel cactus.",
         model=RK % "barrel_cactus_fruit",
         eat="chews on some raw Barrel Cactus Fruit . . .",
         hallucinate=60),

    dict(id="brainfungus", name="Brain Fungus",
         desc="Looks like it might make for a tasty snack.",
         model=RK % "brain_fungus_fungus",
         eat="chews on some strange Fungus . . .",
         rad=10, knockout=15, hint=True),

    dict(id="brocflower", name="Broc Flower",
         desc="A resilient blossom, known for its natural healing qualities.",
         model=RK % "brocflower_bud",
         eat="chews on some raw Broc Flower . . .",
         hint=True),

    dict(id="buffalogourd", name="Buffalo Gourd",
         desc="A 'seed' from a Buffalo Gourd plant.",
         model=RK % "buffalo_guord_fruit",
         eat="tears open and devours an entire Melon . . .",
         food=10, rad=5, heal=(1, 1, 10)),

    dict(id="carrot", name="Carrot",
         desc="Tasty fresh produce.",
         model="models/mosi/fnv/props/food/crops/carrot.mdl",
         eat="chews on some raw Carrot . . .",
         food=10, rad=1),

    dict(id="cavefungus", name="Cave Fungus",
         desc="Fungus pulled off a cave wall. It smells like the cave.",
         model=RK % "cave_fungus_fungus",
         eat="chews on some strange Fungus . . .",
         rad=20, knockout=15),

    dict(id="coyotetobacco", name="Coyote Tobacco",
         desc="Even odds of either shrugging off blows for two minutes or "
              "falling unconscious.",
         model=RK % "coyote_tobacco_fruit",
         eat="chews on some raw Coyote Tobacco . . .",
         rad=3, gamble=("DR", 10, 120, 15), hint=True),

    dict(id="honeymesquite", name="Honey Mesquite",
         desc="The honey mesquite pod grows on a short tree with willow-like "
              "branches.",
         model=RK % "honey_mesquite_fruit",
         eat="chews on some raw Honey Pods . . .",
         rad=5, hint=True),

    dict(id="jalapeno", name="Jalapeño",
         desc="A very hot pepper.",
         model=RK % "jalepeno_root_fruit",
         eat="chews on some raw Jalapeño . . .",
         food=10, rad=4, ignite=(5, 10), hint=True),

    dict(id="maize", name="Maize",
         desc="A stalk of maize.",
         model=RK % "maize_fruit",
         eat="chews on some raw Maize . . .",
         food=20, rad=10, heal=(1, 1, 10)),

    dict(id="mutfruit", name="Mutfruit",
         desc="Tasty fresh produce.",
         model=MOSI % "mutfruit",
         eat="chews on some raw Mutfruit . . .",
         food=15, rad=1),

    dict(id="nevadaagave", name="Nevada Agave",
         desc="A rare wasteland plant often used for healing skin blemishes.",
         model=RK % "nevada_agave_fruit",
         eat="chews on some raw Nevada Agave . . .",
         food=10, rad=5, heal=(1, 1, 10), hint=True),

    dict(id="pintoroot", name="Pinto Pod",
         desc="A pod of Pinto beans.",
         model=RK % "pinto_root_fruit",
         eat="chews on some raw Pinto Pods . . .",
         food=10, rad=5, heal=(1, 1, 10), hint=True),

    dict(id="pricklypear", name="Prickly Pear",
         desc="A sweet fruit harvested from a prickly pear cactus.",
         model=RK % "prickly_pear_cactus_fruit",
         eat="chews on some raw Prickly Pear . . .",
         hallucinate=40),

    dict(id="sacreddatura", name="Sacred Datura",
         desc="A flowering plant with psychoactive properties. Often used in "
              "rituals and rites of passage.",
         model=RK % "sacred_datura_flower",
         eat="chews on some raw Sacred Datura . . .",
         rad=5, hallucinate=60),

    dict(id="tarberry", name="Tarberry",
         desc="Tasty fresh produce.",
         model=MOSI % "tarberry",
         eat="chews on some raw Tarberry . . .",
         food=10, rad=1),

    dict(id="tato", name="Tato",
         desc="Tasty fresh produce.",
         model=MOSI % "tato",
         eat="chews on some raw Tato . . .",
         food=10, rad=1),

    dict(id="whitehorsenettle", name="White Horsenettle",
         desc="A bunch of Horsenettle seeds.",
         model=RK % "whitehorse_berrys",
         eat="chews on a bunch of random seeds . . .",
         food=10, rad=4),

    dict(id="xanderroot", name="Xander Root",
         desc="A hardy desert herb with medicinal properties.",
         model=RK % "xanderroot_model",
         eat="chews on some raw Xanderroot . . .",
         food=10, rad=10, heal=(1, 1, 10), hint=True)
]

#  Phoenix's seventeen seeds, and what each grows. Their file names are kept
#  where they are sensible and corrected where they are not - theirs has both
#  `seed_agave` and `seed_nevadaagave` for the same crop, and `seed_goard`.
SEEDS = [
    ("bananayucca", "Banana Yucca"),
    ("barrelcactus", "Barrel Cactus"),
    ("brocflower", "Broc Flower"),
    ("buffalogourd", "Buffalo Gourd"),
    ("carrot", "Carrot"),
    ("cavefungus", "Cave Fungus"),
    ("coyotetobacco", "Coyote Tobacco"),
    ("honeymesquite", "Honey Mesquite"),
    ("jalapeno", "Jalapeño"),
    ("maize", "Maize"),
    ("mutfruit", "Mutfruit"),
    ("nevadaagave", "Nevada Agave"),
    ("pintoroot", "Pinto Root"),
    ("tato", "Tato"),
    ("whitehorsenettle", "White Horsenettle"),
    ("xanderroot", "Xander Root"),
    ("tarberry", "Tarberry")
]

HEADER = """--[[
	%s.

	Generated by `_docs/tools/genplants.py` from Phoenix's own numbers - edit
	the table there rather than this file, or the next run will overwrite you.
]]

"""


def lua_string(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def lua_assign(field, text, width=76):
    """`ITEM.x = "..."`, wrapped at the project's line width.

    Long descriptions are split across concatenated strings rather than
    running off the side of the file - every hand-written item here does the
    same, and a generator that produces something nobody would have typed is
    a generator whose output gets rewritten by hand.
    """
    line = "%s = %s" % (field, lua_string(text))

    if len(line) <= width:
        return line + "\n"

    words = text.split(" ")
    lines = []
    current = ""

    #  The first line carries `ITEM.x = `, the rest carry a tab and `.. `.
    room = width - len(field) - 6

    for word in words:
        candidate = (current + " " + word) if current else word

        if len(candidate) > room and current:
            lines.append(current)
            current = word
            room = width - 8
        else:
            current = candidate

    if current:
        lines.append(current)

    #  Every piece but the last keeps the space that joined it to the next.
    out = "%s = %s\n" % (field, lua_string(lines[0] + " "))

    for index, piece in enumerate(lines[1:]):
        last = index == len(lines) - 2
        out += "\t.. %s\n" % lua_string(piece + ("" if last else " "))

    return out


def plant_file(plant):
    out = [HEADER % plant["name"]]
    add = out.append

    add("ITEM.name = %s\n" % lua_string(plant["name"]))
    add(lua_assign("ITEM.description", plant["desc"]))
    add("ITEM.model = %s\n" % lua_string(plant["model"]))
    add("\n")

    if plant.get("food"):
        add("ITEM.sustenance = %d\n" % plant["food"])

    if plant.get("water"):
        add("ITEM.hydration = %d\n" % plant["water"])

    if plant.get("rad"):
        add("ITEM.radiation = %d\n" % plant["rad"])

    add("\n")
    add("ITEM.eatMeText = %s\n" % lua_string(plant["eat"]))

    effects = []

    if plant.get("heal"):
        effects.append("ITEM.heal = {%d, %d, %d}"
                       % plant["heal"])

    if plant.get("hallucinate"):
        effects.append("ITEM.hallucinate = %d" % plant["hallucinate"])

    if plant.get("knockout"):
        effects.append("ITEM.knockout = %d" % plant["knockout"])

    if plant.get("ignite"):
        effects.append("ITEM.ignite = {%d, %d}" % plant["ignite"])

    if plant.get("gamble"):
        stat, value, duration, knockout = plant["gamble"]
        effects.append(
            "ITEM.gamble = {chance = 0.5, stat = %s, value = %d,\n"
            "\tduration = %d, knockout = %d}"
            % (lua_string(stat), value, duration, knockout))

    if plant.get("hint"):
        effects.append("ITEM.chemHint = true")

    if effects:
        add("\n")
        add("\n".join(effects))
        add("\n")

    return "".join(out)


def seed_file(seed_id, name):
    return (HEADER % ("%s seeds" % name)
            + 'ITEM.name = %s\n' % lua_string("%s Seeds" % name)
            + 'ITEM.description = %s\n'
              % lua_string("A bag of %s seeds." % name.lower())
            + '\n'
            + 'ITEM.plantType = %s\n' % lua_string("plant_" + seed_id))


def write(path, content):
    io.open(path, "w", encoding="utf-8", newline="").write(content)


def main():
    for directory in (PLANT_DIR, SEED_DIR):
        if not os.path.isdir(directory):
            os.makedirs(directory)

    for plant in PLANTS:
        write(os.path.join(PLANT_DIR, "sh_plant_%s.lua" % plant["id"]),
              plant_file(plant))

    for seed_id, name in SEEDS:
        write(os.path.join(SEED_DIR, "sh_seed_%s.lua" % seed_id),
              seed_file(seed_id, name))

    print("%d plants, %d seeds" % (len(PLANTS), len(SEEDS)))


if __name__ == "__main__":
    main()

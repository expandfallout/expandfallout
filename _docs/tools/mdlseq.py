"""Read the sequence names out of a Source .mdl, following $includemodel.

Why this exists: an animation class is a table of SEQUENCE NAMES, and Helix
plays them by name. Point a model at a class whose names it does not have and
the model falls back to sequence 0 - which for these packs is the reference
pose. That is the T-pose, and the spasm is it flicking between a name that
exists and one that does not.

So "which class fits this model" is a question about the model file, not about
what the creature is called. This answers it by reading the sequence table.

    python _docs/tools/mdlseq.py <model path or race class> ...
    python _docs/tools/mdlseq.py --match          score every race's model
    python _docs/tools/mdlseq.py --act <model> [substring ...]
                                                  activity and frames per sequence
"""

import io, os, struct, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
ADDONS = ROOT + "/addons"
SCHEMA = ROOT + "/gamemodes/falloutrp/schema"

# studiohdr_t offsets, MDL version 44-49. The header is fixed up to numlocalseq;
# everything after it varies by version and is not needed here.
OFF_NUMLOCALSEQ = 188
OFF_LOCALSEQINDEX = 192
# numincludemodels / includemodelindex sit at the far end of the header, past
# the texture, bodypart, flex, ik and pose-parameter blocks. Counted rather
# than guessed - 232 is numbodyparts, and reading there gives plausible-looking
# nonsense (`ant_reference.SMD`) instead of an error.
OFF_INCLUDEMODEL_COUNT = 336
OFF_INCLUDEMODEL_INDEX = 340

# mstudioseqdesc_t: baseptr, szlabelindex, szactivitynameindex, ...
SEQDESC_SIZE = 212


def _cstring(data, offset):
    if offset <= 0 or offset >= len(data):
        return ""

    end = data.find(b"\0", offset)

    return data[offset:end if end >= 0 else len(data)].decode(
        "ascii", "replace")


def _resolve(path):
    """A game-relative model path to a file on disk, following junctions."""
    path = path.replace("\\", "/").lstrip("/")

    for base in (ROOT, ADDONS):
        if base == ROOT:
            candidate = os.path.join(base, path)
            if os.path.isfile(candidate):
                return candidate
            continue

        if not os.path.isdir(base):
            continue

        for addon in os.listdir(base):
            candidate = os.path.join(base, addon, path)
            if os.path.isfile(candidate):
                return candidate

    return None


def sequences(path, _seen=None):
    """Every sequence name in the model, plus the ones it includes.

    `$includemodel` is the whole reason this recurses: `supermutant.mdl` has
    exactly one activity of its own and gets its 200-odd sequences from
    `supermutant_animations.mdl`. Reading only the file named by the race would
    say the model has no animations at all, which is wrong and would send you
    looking in the wrong place.
    """
    _seen = _seen if _seen is not None else set()

    disk = _resolve(path) if not os.path.isfile(path) else path

    if not disk or disk in _seen:
        return set(), []

    _seen.add(disk)

    data = io.open(disk, "rb").read()

    if len(data) < 256 or data[:4] not in (b"IDST", b"MDLZ"):
        return set(), []

    names = set()

    count = struct.unpack_from("<i", data, OFF_NUMLOCALSEQ)[0]
    index = struct.unpack_from("<i", data, OFF_LOCALSEQINDEX)[0]

    if 0 < count < 20000 and 0 < index < len(data):
        for i in range(count):
            start = index + i * SEQDESC_SIZE

            if start + 8 > len(data):
                break

            label = struct.unpack_from("<i", data, start + 4)[0]
            name = _cstring(data, start + label)

            if name:
                names.add(name.lower())

    includes = []
    icount = struct.unpack_from("<i", data, OFF_INCLUDEMODEL_COUNT)[0]
    iindex = struct.unpack_from("<i", data, OFF_INCLUDEMODEL_INDEX)[0]

    if 0 < icount < 64 and 0 < iindex < len(data):
        for i in range(icount):
            start = iindex + i * 8
            # mstudiomodelgroup_t: szlabelindex, sznameindex. The offsets are
            # documented as relative to the group, and are relative to the
            # header in some compiles - so both are tried and the one that
            # names a model wins.
            offset = struct.unpack_from("<i", data, start + 4)[0]
            included = _cstring(data, start + offset)

            if not included.lower().endswith(".mdl"):
                included = _cstring(data, offset)

            if included.lower().endswith(".mdl"):
                includes.append(included)
                more, deeper = sequences(included, _seen)
                names |= more
                includes += deeper

    return names, includes


# ---------------------------------------------------------------- activities
OFF_NUMLOCALANIM = 180
OFF_LOCALANIMINDEX = 184
ANIMDESC_SIZE = 100


def activities(path, wanted=()):
    """`(index, name, activity, weight, frames)` per sequence, off the file.

    The activity is what the engine's `SelectWeightedSequence` answers to, and
    it is what `Schema:TranslateActivity` hands back after playing a sequence
    by name. A sequence with no activity round-trips as -1 and the direct
    `SetSequence` stands; one WITH an activity is re-selected by it. On the
    human model only `mtjumpstart` (ACT_MP_JUMP) and a handful of idles carry
    one, which is how to know the round-trip is harmless there.
    """
    disk = _resolve(path) if not os.path.isfile(path) else path

    if not disk:
        return []

    data = io.open(disk, "rb").read()
    count = struct.unpack_from("<i", data, OFF_NUMLOCALSEQ)[0]
    index = struct.unpack_from("<i", data, OFF_LOCALSEQINDEX)[0]
    nanim = struct.unpack_from("<i", data, OFF_NUMLOCALANIM)[0]
    aindex = struct.unpack_from("<i", data, OFF_LOCALANIMINDEX)[0]
    wanted = [w.lower() for w in wanted]
    out = []

    for i in range(count):
        start = index + i * SEQDESC_SIZE

        if start + SEQDESC_SIZE > len(data):
            break

        name = _cstring(data, start + struct.unpack_from("<i", data, start + 4)[0])

        if wanted and not any(w in name.lower() for w in wanted):
            continue

        activity = _cstring(
            data, start + struct.unpack_from("<i", data, start + 8)[0])
        weight = struct.unpack_from("<i", data, start + 20)[0]

        # animindexindex points at the blend table; its first entry names the
        # mstudioanimdesc_t whose numframes is at +16.
        animindexindex = struct.unpack_from("<i", data, start + 60)[0]
        anim = struct.unpack_from("<h", data, start + animindexindex)[0]
        frames = 0

        if 0 <= anim < nanim:
            frames = struct.unpack_from(
                "<i", data, aindex + anim * ANIMDESC_SIZE + 16)[0]

        out.append((i, name, activity, weight, frames))

    return out


# ------------------------------------------------------------------ matching
def anim_classes():
    """`[class] = set of sequence names` from the generated shared file."""
    import re

    path = os.path.join(SCHEMA, "libs", "sh_raceanims.lua")

    if not os.path.isfile(path):
        return {}

    text = io.open(path, encoding="utf-8").read()
    out = {}

    for match in re.finditer(r"^ix\.anim\.(\w+) = \{", text, re.M):
        name = match.group(1)
        depth, i = 0, match.end() - 1

        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1

        body = text[match.end():i]
        out[name] = {s.lower() for s in re.findall(r'"([^"]+)"', body)}

    # The human set lives in its own file, being hand-written rather than
    # generated.
    path = os.path.join(SCHEMA, "libs", "sh_anims.lua")

    if os.path.isfile(path):
        text = io.open(path, encoding="utf-8").read()

        for match in re.finditer(r"^ix\.anim\.(\w+) = \{", text, re.M):
            name = match.group(1)
            depth, i = 0, match.end() - 1

            while i < len(text):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1

            out.setdefault(name, set()).update(
                {s.lower() for s in re.findall(r'"([^"]+)"', text[match.end():i])})

    return out


def races():
    """`[class] = animationModel` for every race."""
    import re

    out = {}
    directory = os.path.join(SCHEMA, "races")

    for f in sorted(os.listdir(directory)):
        text = io.open(os.path.join(directory, f), encoding="utf-8").read()
        klass = re.search(r'RACE\.class = "([^"]+)"', text)
        model = re.search(r'RACE\.animationModel = "([^"]+)"', text)

        if klass and model:
            out[klass.group(1)] = model.group(1).lower()

    return out


def registrations():
    """`[model] = anim class`, from every SetModelClass call in the schema."""
    import re

    out = {}

    for root, _, files in os.walk(SCHEMA):
        for f in files:
            if not f.endswith(".lua"):
                continue

            text = io.open(os.path.join(root, f), encoding="utf-8",
                           errors="replace").read()

            for model, klass in re.findall(
                    r'SetModelClass\(\s*"([^"]+)"\s*,\s*"([^"]+)"', text):
                out[model.lower()] = klass

            for model, klass in re.findall(
                    r'\["([^"]+)"\]\s*=\s*"(\w+)"', text):
                if model.endswith(".mdl"):
                    out.setdefault(model.lower(), klass)

    return out


def main():
    args = sys.argv[1:]

    if args and args[0] == "--match":
        classes = anim_classes()
        registered = registrations()
        cache = {}

        print("%-24s %-46s %s" % ("RACE", "ANIMATION MODEL", "COVERAGE"))

        for klass, model in sorted(races().items()):
            if model not in cache:
                cache[model] = sequences(model)[0]

            have = cache[model]

            if not have:
                print("%-24s %-46s  no sequences readable" % (klass, model))
                continue

            current = registered.get(model)
            scored = []

            for name, wanted in classes.items():
                if not wanted:
                    continue

                hit = len(wanted & have)
                scored.append((hit / float(len(wanted)), name, hit, len(wanted)))

            scored.sort(reverse=True)
            best = scored[0]

            flag = ""

            if current:
                mine = [s for s in scored if s[1] == current]
                got = mine[0][0] if mine else 0.0
                flag = "  now=%s %.0f%%" % (current, got * 100)

                if got < 0.5 and best[0] > got + 0.2:
                    flag += "   <-- WRONG, best is %s %.0f%%" % (
                        best[1], best[0] * 100)
            else:
                flag = "  now=none, best is %s %.0f%%" % (best[1], best[0] * 100)

            print("%-24s %-46s %3d seqs%s" % (klass, model, len(have), flag))

        return

    if args and args[0] == "--act":
        for row in activities(args[1], args[2:]):
            print("%4d %-28s %-24s weight %2d  %3d frames"
                  % (row[0], row[1], row[2] or "-", row[3], row[4]))

        return

    for path in args:
        names, includes = sequences(path)
        print("== %s" % path)

        if includes:
            print("   includes: %s" % ", ".join(includes))

        print("   %d sequences: %s"
              % (len(names), ", ".join(sorted(names))))


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""
luaglobals.py <dir-or-file> [...] [--learn <dir> ...]

Finds reads of names that are never bound anywhere in the file - the class of
bug `luacheck.py` structurally cannot see, because the file still parses fine.

The case that motivated it:

    local startX = math.floor(...)      -- deleted during a refactor
    ...
    pos = {startX + (w * 0.01), ...}    -- still here

`startX` silently becomes a read of a nil global. Lua raises only when the value
is used - so it is a runtime error, inside a HUD paint, firing every frame.

How it works: collects every name BOUND in the file (locals, function
parameters, loop variables, function names, assignment targets and table keys),
then reports any identifier read that is neither bound there nor a known global.

Known globals come from two places:
  * a curated Lua/GMod base list, below
  * --learn <dir>, which harvests every global assigned anywhere in that tree.
    Point it at the Helix gamemode to pick up ix, Schema, PLUGIN, SWEP, and so
    on. The harvested set is cached next to this script as luaglobals.cache.

This is FILE-level, not scope-level. It will not catch a name that is local to a
different function in the same file, so it under-reports rather than crying
wolf. That is the intended trade.
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "luaglobals.cache")

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return",
    "then", "true", "until", "while", "continue"
}

BASE_GLOBALS = {
    # Lua
    "_G", "assert", "collectgarbage", "dofile", "error", "getfenv",
    "getmetatable", "ipairs", "load", "loadstring", "next", "pairs", "pcall",
    "print", "rawequal", "rawget", "rawlen", "rawset", "require", "select",
    "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack",
    "xpcall", "coroutine", "debug", "io", "math", "os", "string", "table",
    "bit", "jit", "SortedPairs", "SortedPairsByValue", "SortedPairsByMemberValue",
    "PairsSortedByMemberValue",
    # GMod core
    "CLIENT", "SERVER", "MENU_DLL", "GM", "GAMEMODE", "Entity", "NULL",
    "Vector", "Angle", "Color", "ColorAlpha", "HSVToColor", "ColorToHSV",
    "Material", "CreateMaterial", "CreateClientConVar", "CreateConVar",
    "GetConVar", "cvars", "concommand", "hook", "net", "util", "file",
    "timer", "surface", "draw", "render", "cam", "vgui", "derma", "gui",
    "input", "system", "engine", "game", "player", "team", "ents", "sound",
    "properties", "spawnmenu", "list", "language", "killicon", "usermessage",
    "umsg", "resource", "http", "steamworks", "achievements", "chat",
    "notification", "markup", "matproxy", "duplicator", "cleanup", "undo",
    "constraint", "physenv", "navmesh", "widgets", "scripted_ents",
    "weapons", "effects", "particles", "CreateParticleSystem", "ParticleEmitter",
    "ParticleEffect", "ParticleEffectAttach", "DynamicLight", "ProjectedTexture",
    "LocalPlayer", "IsValid", "IsEntity", "IsFirstTimePredicted", "CurTime",
    "RealTime", "SysTime", "FrameTime", "RealFrameTime", "ScrW", "ScrH",
    "ScreenScale", "Lerp", "LerpVector", "LerpAngle", "FrameNumber",
    "AddCSLuaFile", "include", "RunString", "RunConsoleCommand", "MsgN", "Msg",
    "MsgC", "ErrorNoHalt", "Error", "PrintTable", "AccessorFunc", "FindMetaTable",
    "DeriveGamemode", "EmitSound", "CreateSound", "SoundDuration", "band",
    "istable", "isstring", "isnumber", "isbool", "isfunction", "isvector",
    "isangle", "isentity", "ispanel", "ismatrix", "isarray", "IsColor",
    "Format",
    "string_format", "TypeID", "DamageInfo", "EffectData", "Matrix",
    "LocalToWorld", "WorldToLocal", "VectorRand", "AngleRand", "RandomPairs",
    "Either", "tobool", "table_insert", "CompileString", "SafeRemoveEntity",
    "SafeRemoveEntityDelayed", "DisableClipping", "ScreenshotRequest",
    "CloseDermaMenus", "RegisterDermaMenuForClose", "UnPredictedCurTime",
    "GetHostName", "VGUIFrameTime", "JS_Utility",
    # colours / constants
    "color_white", "color_black", "color_transparent", "Angle_Zero",
    "vector_origin", "vector_up", "angle_zero",
    # surfaced by running this against Helix - all real, just not in the
    # hand-written list above
    "BaseClass", "baseclass", "Schema", "pac", "Sound", "Model", "utf8",
    "gmod", "gameevent", "gamemode", "sql", "mysqloo", "dragndrop", "finish",
    "DermaMenu", "Derma_StringRequest", "Derma_Query", "Derma_Message",
    "ClientsideModel", "ClientsideScene", "ClientsideRagdoll",
    "PositionSpawnIcon", "SetClipboardText", "g_ContextMenu", "g_SpawnMenu",
    "RestoreCursorPosition", "RememberCursorPosition", "CreateContextMenu",
    "SScale", "ScreenScaleH", "LocalToScreen", "AddOriginToPVS",
    "GetViewEntity", "RecipientFilter", "PrecacheParticleSystem",
    "CreateSprite", "LocalToWorldAngles", "OrderVectors", "util_TraceLine",
    "ConVarExists", "debugoverlay", "DrawSunbeams", "ErrorNoHaltWithStack", "GetConVarString",
    "GetRenderTarget", "GetRenderTargetEx", "DButton", "Player", "Players",
    "EyePos", "EyeAngles", "RenderAngles", "DrawColorModify", "DrawBloom",
    "DrawMaterialOverlay", "DrawToyTown", "DrawSharpen", "DrawMotionBlur",
    # confirmed real: garrysmod/lua/postprocess/sobel.lua defines DrawSobel
    "DrawSobel", "DrawSunbeams", "DrawTexturize", "DrawBokehDOF",
}
# Constant families that are all-caps engine enums.
ENUM_RE = re.compile(r'^[A-Z][A-Z0-9_]*$')


def strip_and_tokens(text):
    """Yield (prev_char, name, next_char) for each identifier, skipping strings
    and comments."""
    i, n = 0, len(text)

    def long_bracket(start):
        if start >= n or text[start] != "[":
            return None
        j, level = start + 1, 0
        while j < n and text[j] == "=":
            level += 1
            j += 1
        if j < n and text[j] == "[":
            return level, j + 1
        return None

    line = 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if text.startswith("--", i) or text.startswith("//", i):
            if text.startswith("--", i):
                lb = long_bracket(i + 2)
                if lb:
                    level, body = lb
                    close = "]" + "=" * level + "]"
                    end = text.find(close, body)
                    if end == -1:
                        return
                    line += text.count("\n", i, end)
                    i = end + len(close)
                    continue
            nl = text.find("\n", i)
            i = n if nl == -1 else nl
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end == -1:
                return
            line += text.count("\n", i, end)
            i = end + 2
            continue
        lb = long_bracket(i)
        if lb:
            level, body = lb
            close = "]" + "=" * level + "]"
            end = text.find(close, body)
            if end == -1:
                return
            line += text.count("\n", i, end)
            i = end + len(close)
            continue
        if c in "\"'":
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == c or text[j] == "\n":
                    break
                j += 1
            i = j + 1
            continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            prev = text[i - 1] if i else ""
            k = j
            while k < n and text[k] in " \t":
                k += 1
            nxt = text[k:k + 2]
            yield line, prev, text[i:j], nxt
            i = j
            continue
        i += 1


def bound_names(text):
    """Every name the file binds. Deliberately generous."""
    names = set()
    names |= set(re.findall(r'\blocal\s+function\s+([A-Za-z_]\w*)', text))
    for m in re.finditer(r'\blocal\s+([A-Za-z_][\w\s,]*)', text):
        names |= set(re.findall(r'[A-Za-z_]\w*', m.group(1)))
    for m in re.finditer(r'\bfunction\s*[A-Za-z_.:\w]*\s*\(([^)]*)\)', text):
        names |= set(re.findall(r'[A-Za-z_]\w*', m.group(1)))
    for m in re.finditer(r'\bfor\s+([A-Za-z_][\w\s,]*?)\s*(?:=|\bin\b)', text):
        names |= set(re.findall(r'[A-Za-z_]\w*', m.group(1)))
    names |= set(re.findall(r'\bfunction\s+([A-Za-z_]\w*)', text))
    # assignment targets and table keys
    names |= set(re.findall(r'(?<![.:\w])([A-Za-z_]\w*)\s*=(?!=)', text))
    names |= set(re.findall(r'\[\s*"([A-Za-z_]\w*)"\s*\]', text))
    return names


def learn(dirs):
    found = set()
    for d in dirs:
        for root, _, files in os.walk(d):
            for f in files:
                if not f.endswith(".lua"):
                    continue
                t = io.open(os.path.join(root, f), encoding="utf-8",
                            errors="replace").read()
                # Only GENUINE globals. Harvesting every `name =` sweeps up
                # every local in the codebase too, which poisons the known set
                # and makes the whole check silently pass - which is exactly
                # what it did on the first attempt.
                found |= set(re.findall(r'(?m)^([A-Za-z_]\w*)\s*=(?!=)', t))
                found |= set(re.findall(r'\bfunction\s+([A-Za-z_]\w*)[.:]', t))
                # global function declarations: `function falloutFactionSet(...)`
                # but NOT `local function foo(...)`
                found |= set(re.findall(r'(?m)^function\s+([A-Za-z_]\w*)\s*\(', t))
                found |= set(re.findall(r'(?m)^\s*([A-Za-z_]\w*)\.[A-Za-z_]\w*\s*=(?!=)', t))
    return found


def check(path, known):
    text = io.open(path, encoding="utf-8", errors="replace").read()
    bound = bound_names(text)
    problems = []
    seen = set()

    for line, prev, name, nxt in strip_and_tokens(text):
        # A name directly after a digit is a number suffix (0xFF -> "xFF").
        if prev.isdigit():
            continue
        if name in KEYWORDS or prev in ".:" or nxt.startswith("=") and not nxt.startswith("=="):
            continue
        if name in bound or name in known or name in BASE_GLOBALS:
            continue
        if ENUM_RE.match(name):
            continue
        if (name, line) in seen:
            continue
        seen.add((name, line))
        problems.append("line %d: '%s' is read but never bound in this file" % (line, name))

    return problems


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    known = set()

    if "--learn" in sys.argv:
        idx = sys.argv.index("--learn")
        dirs = [a for a in sys.argv[idx + 1:] if not a.startswith("--")]
        known = learn(dirs)
        io.open(CACHE, "w", encoding="utf-8").write("\n".join(sorted(known)))
        print("learned %d globals -> %s\n" % (len(known), os.path.basename(CACHE)))
        args = [a for a in args if a not in dirs]
    elif os.path.exists(CACHE):
        known = set(io.open(CACHE, encoding="utf-8").read().split())

    if not args:
        return 0

    files = []
    for t in args:
        if os.path.isfile(t):
            files.append(t)
        else:
            for root, _, names in os.walk(t):
                for nm in sorted(names):
                    if nm.endswith(".lua"):
                        files.append(os.path.join(root, nm))

    bad = 0
    for path in files:
        problems = check(path, known)
        if problems:
            bad += 1
            print("  %s" % path.replace("\\", "/"))
            for p in problems:
                print("      %s" % p)

    print("\nchecked %d lua files, %d with unbound reads" % (len(files), bad))
    return 1 if bad else 0


sys.exit(main())

#!/usr/bin/env python
"""
vmtcheck.py [dir ...] [--fix]

Finds and repairs malformed .vmt files - the ones that make the engine spew

    KeyValues Error: LoadFromBuffer: missing { in file ...
    KeyValues Error: RecursiveLoadFromBuffer: got EOF instead of keyname ...

These come from KeyValues, not Lua, so luacheck.py never sees them and nothing
else in the project catches them. They are almost always typos in third-party
workshop content, not our code.

Faults that have actually occurred in this install:

  extra closing brace at EOF   -> "missing {"   the stray } is read as a new
                                  root key, then EOF arrives before its block
  missing closing brace        -> "got EOF instead of keyname"
  doubled quote,  ""path"      -> "got EOF instead of keyname"
  missing opening quote, $phong" -> the key swallows the rest of the file
  missing closing quote at EOL -> same
  extra trailing quote, "..."" -> same

Everything above is auto-fixable with --fix. Anything else is reported only.

Run after installing or updating any content addon:

    python _docs/tools/vmtcheck.py garrysmod --fix
"""
import os, re, sys

# "$bumpmap" ""path"   ->   "$bumpmap" "path"
DOUBLED_OPEN = re.compile(r'("\$?[A-Za-z0-9_]+"\s*)""(?=[^"\s])')
# leading $key" with no opening quote
MISSING_OPEN = re.compile(r'(?m)^([ \t]*)\$([A-Za-z0-9_]+)"')
# a value ending in two quotes
TRAILING_DOUBLE = re.compile(r'(?m)""[ \t]*$')


def strip_comment(line):
    """Return the line with any // comment outside quotes removed, plus the
    number of quote characters seen before that point."""
    out = []
    q = 0
    i = 0
    while i < len(line):
        c = line[i]
        if c == '"':
            q += 1
            out.append(c)
            i += 1
            continue
        if q % 2 == 0 and line[i:i + 2] == "//":
            break
        out.append(c)
        i += 1
    return "".join(out), q


def scan(text):
    """(opens, closes, depth, went_negative, [lines with odd quote counts])"""
    depth = opens = closes = 0
    neg = False
    oddq = []
    for n, line in enumerate(text.split("\n"), 1):
        seg, q = strip_comment(line)
        if q % 2 == 1:
            oddq.append(n)
        # brace counting must ignore anything inside quotes
        bare = re.sub(r'"[^"]*"', "", seg)
        opens += bare.count("{")
        closes += bare.count("}")
        for c in bare:
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth < 0:
                    neg = True
    return opens, closes, depth, neg, oddq


def repair(text):
    """Apply every known fix. Returns (new_text, [descriptions])."""
    faults = []
    new = text

    if DOUBLED_OPEN.search(new):
        faults.append('doubled quote (""path")')
        new = DOUBLED_OPEN.sub(r'\1"', new)

    if MISSING_OPEN.search(new):
        faults.append('missing opening quote ($key")')
        new = MISSING_OPEN.sub(r'\1"$\2"', new)

    if TRAILING_DOUBLE.search(new):
        faults.append('extra trailing quote ("...""")')
        new = TRAILING_DOUBLE.sub('"', new)

    # any line still holding an odd number of quotes is missing its closer
    lines = new.split("\n")
    patched = []
    for n, line in enumerate(lines, 1):
        seg, q = strip_comment(line)
        if q % 2 == 1 and not line.rstrip().endswith('"'):
            faults.append("missing closing quote on line %d" % n)
            line = line.rstrip() + '"'
        patched.append(line)
    new = "\n".join(patched)

    o, c, d, neg, _ = scan(new)
    if neg or d < 0:
        faults.append("extra closing brace (opens=%d closes=%d)" % (o, c))
        s = new.rstrip()
        while s.endswith("}"):
            _, _, dd, nn, _ = scan(s)
            if dd >= 0 and not nn:
                break
            s = s[:-1].rstrip()
        new = s + "\n"
    elif d > 0:
        faults.append("unclosed block (opens=%d closes=%d)" % (o, c))
        new = new.rstrip() + "\n" + "}\n" * d

    return new, faults


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fix = "--fix" in sys.argv
    total = bad = fixed = 0

    for root_dir in (args or ["."]):
        for root, dirs, files in os.walk(root_dir):
            for f in files:
                if not f.lower().endswith(".vmt"):
                    continue
                p = os.path.join(root, f)
                total += 1
                try:
                    raw = open(p, "rb").read()
                except Exception as e:
                    print("  UNREADABLE %s (%s)" % (p, e))
                    continue

                text = raw.decode("utf-8", "replace")
                new, faults = repair(text)
                if not faults:
                    continue

                bad += 1
                print("  %s\n      %s" % (p.replace("\\", "/"), "; ".join(faults)))

                if fix:
                    o, c, d, neg, oddq = scan(new)
                    if d == 0 and not neg and not oddq:
                        nl = "\r\n" if b"\r\n" in raw else "\n"
                        body = new.replace("\r\n", "\n").replace("\n", nl)
                        open(p, "wb").write(body.encode("utf-8"))
                        fixed += 1
                        print("      -> fixed")
                    else:
                        print("      -> NOT auto-fixable, edit by hand")

    print("\nchecked %d vmt files, %d malformed%s" %
          (total, bad, (", %d fixed" % fixed) if fix else ""))
    return 0

sys.exit(main())

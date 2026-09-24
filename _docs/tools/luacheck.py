#!/usr/bin/env python
"""
luacheck.py <dir-or-file> [...]

Structural syntax check for GLua. There is no Lua interpreter in this
environment and the server cannot be booted from tool context, so this is the
only pre-flight check available - run it after every edit.

It is a real tokenizer, not a grep. It understands:

  * long brackets at any level: [[...]], [==[...]==]
  * long comments: --[[...]], --[==[...]==]
  * line comments, including GLua's C-style //  and /* */
  * single and double quoted strings with escapes
  * Lua block structure

and reports, with line numbers:

  * unbalanced ( ) [ ] { }, including the wrong closer for the open bracket
  * unterminated strings and long comments
  * unbalanced block keywords, naming the line the unclosed block opened on

Block rules, for reference - only these four open a block:

    function / if / do / repeat        closed by  end / end / end / until

`for` and `while` do not open a block themselves; their `do` does. `else`,
`elseif` and `then` never open one.

It also flags ADJACENT STRING LITERALS - `"a" "b"` with nothing between them.
That is never valid Lua and is what a missing table separator looks like:

    RACE.races = {
        "caucasian"          <- the ',' went missing
        "african"
    }

which is perfectly BALANCED, so every bracket rule above passes it happily.
Four generated race files shipped like that and the checker said zero problems;
the server then refused to load them. A name followed by a string is NOT
flagged, because `Model "x"` is a valid call.

What it still cannot catch: anything semantic. A balanced file can still be a
runtime error - wrong argument order, a nil global, a typo'd method name.
"""
import io
import re
import os
import sys


OPENERS = {"function", "if", "do", "repeat"}
CLOSERS = {"end": ("function", "if", "do"), "until": ("repeat",)}
PAIRS = {")": "(", "]": "[", "}": "{"}


class Problem(Exception):
    def __init__(self, line, message):
        self.line = line
        self.message = message


def tokenize(text):
    """Yield (line, kind, value). kind is 'name', 'sym' or 'str'."""
    i, line, n = 0, 1, len(text)

    def long_bracket(start):
        """If text[start] opens a long bracket, return (level, body_start)."""
        if text[start] != "[":
            return None
        j = start + 1
        level = 0
        while j < n and text[j] == "=":
            level += 1
            j += 1
        if j < n and text[j] == "[":
            return level, j + 1
        return None

    while i < n:
        c = text[i]

        if c == "\n":
            line += 1
            i += 1
            continue

        if c in " \t\r":
            i += 1
            continue

        # comments
        if text.startswith("--", i) or text.startswith("//", i):
            if text.startswith("--", i):
                lb = long_bracket(i + 2)
                if lb:
                    level, body = lb
                    close = "]" + "=" * level + "]"
                    end = text.find(close, body)
                    if end == -1:
                        raise Problem(line, "unterminated long comment --[%s[" % ("=" * level))
                    line += text.count("\n", i, end)
                    i = end + len(close)
                    continue
            nl = text.find("\n", i)
            i = n if nl == -1 else nl
            continue

        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end == -1:
                raise Problem(line, "unterminated /* comment")
            line += text.count("\n", i, end)
            i = end + 2
            continue

        # long strings
        lb = long_bracket(i)
        if lb:
            level, body = lb
            close = "]" + "=" * level + "]"
            end = text.find(close, body)
            if end == -1:
                raise Problem(line, "unterminated long string [%s[" % ("=" * level))
            line += text.count("\n", i, end)
            yield line, "str", ""
            i = end + len(close)
            continue

        # quoted strings
        if c in "\"'":
            start_line = line
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    if text[j + 1:j + 2] == "\n":
                        line += 1
                    j += 2
                    continue
                if text[j] == c:
                    break
                if text[j] == "\n":
                    raise Problem(start_line, "unterminated string")
                j += 1
            else:
                raise Problem(start_line, "unterminated string")
            yield start_line, "str", ""
            i = j + 1
            continue

        # numbers - consumed so 0x1f and 1e-3 don't emit stray name tokens
        if c.isdigit():
            j = i
            while j < n and (text[j].isalnum() or text[j] == "." or
                             (text[j] in "+-" and text[j - 1] in "eE")):
                j += 1
            i = j
            continue

        # names / keywords
        if c.isalpha() or c == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            yield line, "name", text[i:j]
            i = j
            continue

        yield line, "sym", c
        i += 1


#[[
#   GMod's Lua adds `continue` as a real KEYWORD, which standard Lua does not
#   have. That makes `::continue::` a label named after a keyword, and the
#   parser refuses the whole file:
#
#       '=' expected near 'continue'
#
#   This checker parses ordinary Lua, where the same code is perfectly legal -
#   so it passed a file the game could not load and the schema went down on
#   start. Anything valid in Lua but invalid in GMOD Lua has to be listed here
#   explicitly, because the parser will never object to it.
#
#   IT READS TOKENS, NOT LINES. The first version scanned raw text and flagged
#   the COMMENT explaining this very rule - documentation that discusses a
#   mistake is not the mistake, and a checker that cannot tell the difference
#   is one people learn to ignore. `tokenize` already drops comments.
#]]
#[[
#   A METHOD IS NOT A VALUE.
#
#   `character:GetThirst` on its own is a syntax error - the colon is call
#   syntax and Lua demands the argument list follows it. Written by mistake in
#   place of a dot it reads perfectly:
#
#       character:GetThirst and character:GetThirst() or 0
#
#   and it took the whole schema down at load with "function arguments expected
#   near 'and'", which is one of the few errors that stops the framework
#   loading rather than breaking one feature. It is exactly the mistake this
#   tool exists to catch and the tokenizer walked straight past it.
#
#   WHAT MAY FOLLOW A METHOD NAME: `(`, a string literal or a table
#   constructor - `obj:method"x"` and `obj:method{...}` are both legal calls.
#   Anything else is this bug.
#]]
def method_problems(text):
    """`obj:method` used as a value rather than called."""
    out = []
    toks = list(tokenize(text))

    for i, tok in enumerate(toks):
        line, kind, value = tok

        if kind != "sym" or value != ":":
            continue

        #[[
        #   A GOTO LABEL IS NOT A METHOD. `::skip::` tokenises as two separate
        #   `:` symbols around a name, so both of its colons would otherwise
        #   report the label as an uncalled method. Either neighbour being a
        #   colon is enough to know which of the two this is.
        #]]
        if i > 0 and toks[i - 1][1] == "sym" and toks[i - 1][2] == ":":
            continue

        if i + 1 < len(toks) and toks[i + 1][1] == "sym"                 and toks[i + 1][2] == ":":
            continue

        if i + 1 >= len(toks) or toks[i + 1][1] != "name":
            continue

        name = toks[i + 1][2]
        after = toks[i + 2] if i + 2 < len(toks) else None

        legal = (after is not None
                 and (after[1] == "str"
                      or (after[1] == "sym" and after[2] in ("(", "{"))))

        if not legal:
            out.append((toks[i + 1][0],
                        "`:%s` is a method call with no arguments - use a "
                        "dot if you meant the function itself" % name))

    return out


def gmod_problems(text):
    """Things GMod's Lua rejects that ordinary Lua accepts."""
    out = []
    previous = None

    for line, kind, value in tokenize(text):
        if kind != "sym" and kind != "name":
            previous = value
            continue

        #[[
        #   Both forms are caught by what comes immediately BEFORE the name.
        #   `goto continue` is two tokens; `::continue::` tokenises as two
        #   separate `:` symbols and then the name, not as one `::`, so the
        #   test is a single colon.
        #
        #   A single colon cannot precede `continue` in any legal GMod Lua
        #   anyway - `foo:continue()` would be a method named after a keyword,
        #   which the parser rejects for the same reason - so this cannot fire
        #   on anything that would otherwise have loaded.
        #]]
        if value == "continue" and (previous == "goto" or previous == ":"):
            out.append((line, "`continue` is a GMod keyword and cannot be a "
                              "goto label - use plain `continue`"))

        previous = value

    return out


#[[
#   Helix's own tables, which exist before any schema file runs. Writing to
#   these needs no declaration.
#]]
FRAMEWORK_TABLES = set("""
    util config command log char item inventory faction class chat option
    currency date anim menu meta gui data net plugin lang schema type flag
    bar hud attributes""".split())

DECLARE = re.compile(r"^\s*ix\.(\w+)\s*=\s*(?:ix\.\1\s+or\s+)?\{")
FILE_WRITE = re.compile(r"^(?:function\s+ix\.(\w+)[.:]|ix\.(\w+)\.\w+\s*=)")


def table_problems(path, text):
    """
    A `cl_` file writing to an `ix` table it has not declared.

    `ix.util.IncludeDir` walks a folder in alphabetical order, so every `cl_`
    file in `libs/` runs BEFORE the `sh_` file that creates the table it wants
    to hang a function on:

        function ix.live.ToggleSights()      -- cl_live.lua, ix.live is nil

    which is an error at FILE SCOPE - and `IncludeDir` has no pcall, so the
    whole rest of the directory is never included either. One missing
    `ix.live = ix.live or {}` presented as five unrelated features being
    broken, twice.

    Only `cl_` files are checked. An `sv_` file sorts after its `sh_` partner,
    which is why they may write freely; `sh_` files are the ones that declare.
    """
    name = os.path.basename(path)

    if not name.startswith("cl_"):
        return []

    out = []
    declared = set()

    for index, line in enumerate(text.split("\n"), 1):
        match = DECLARE.match(line)

        if match:
            declared.add(match.group(1))
            continue

        match = FILE_WRITE.match(line)

        if not match:
            continue

        table = match.group(1) or match.group(2)

        if table in declared or table in FRAMEWORK_TABLES:
            continue

        declared.add(table)   # once per table per file is enough
        out.append((index,
                    "writes to ix.%s at file scope without declaring it - a "
                    "cl_ file loads BEFORE the sh_ file that creates the "
                    "table, so add `ix.%s = ix.%s or {}` above"
                    % (table, table, table)))

    return out


#[[
#   Hooks whose listeners have nothing to say.
#
#   GMod's `hook.Call` returns the FIRST NON-NIL answer and then stops - it
#   runs no further listeners and does not call the gamemode's own function.
#   For a hook that exists to ask a question (CanPlayerX, PlayerShouldTakeDamage)
#   that is the entire point. For these, which exist to say something HAPPENED,
#   a return value silently cancels everything after it.
#
#   `hook.Add("PlayerInitialSpawn", "...", ix.observer.Apply)` - a housekeeping
#   function that happened to answer true - stopped `GM:PlayerInitialSpawn`,
#   which is what calls `client:LoadData` and ends the loading screen. Every
#   client sat on a black "Loading" for ever. See gotcha 27.
#]]
QUIET_HOOKS = set("""
    InitializedPlugins InitializedSchema InitPostEntity OnReloaded
    PlayerInitialSpawn PlayerDisconnected LoadData PostLoadData SaveData
    CharacterLoaded PlayerLoadedCharacter ShutDown
    PlayerDeath DoPlayerDeath PlayerSpawn PlayerHurt PlayerSilentDeath
    KeyPress KeyRelease PhysgunDrop OnPhysgunReload
    PostPlayerSay OnCharacterDisconnect OnCharacterCreated
    OnEntityCreated EntityRemoved
    PlayerSpawnedProp PlayerSpawnedSENT PlayerSpawnedRagdoll""".split())

HOOK_NAMED = re.compile(r'hook\.Add\("(\w+)",\s*"[^"]*",\s*([A-Za-z_][\w.]*)\s*\)')
HOOK_INLINE = re.compile(r'hook\.Add\("(\w+)",\s*"[^"]*",\s*function\s*\(')


def hook_problems(text):
    """A listener on a hook that only reports events, returning a value."""
    out = []
    lines = text.split("\n")

    #[[
    #   Which functions in this file answer something. Only a `return` at the
    #   function's own top level counts - a return inside a nested closure
    #   belongs to that closure, not to the listener.
    #]]
    answers = set()
    current = None
    depth_marker = None

    for line in lines:
        match = re.match(r"(?:local\s+)?function\s+([A-Za-z_][\w.]*)\s*\(", line)

        if match:
            current = match.group(1)
            depth_marker = "\treturn "
            continue

        if line == "end":
            current = None
            continue

        if current and line.startswith(depth_marker) and line.strip() != "return":
            answers.add(current)

    for index, line in enumerate(lines, 1):
        match = HOOK_NAMED.search(line)

        if match and match.group(1) in QUIET_HOOKS and match.group(2) in answers:
            out.append((index,
                        "`%s` returns a value and `%s` stops at the first "
                        "non-nil - wrap it in `function() %s() end` or nothing "
                        "after it runs"
                        % (match.group(2), match.group(1), match.group(2))))
            continue

        match = HOOK_INLINE.search(line)

        if not match or match.group(1) not in QUIET_HOOKS:
            continue

        indent = len(line) - len(line.lstrip("\t"))
        closing = "\t" * indent + "end)"
        inside = "\t" * (indent + 1) + "return "

        for offset in range(index, min(index + 400, len(lines))):
            if lines[offset] == closing:
                break

            if lines[offset].startswith(inside) \
                    and lines[offset].strip() != "return":
                out.append((offset + 1,
                            "a `%s` listener returning a value stops the hook "
                            "- nothing after it runs, including the gamemode's "
                            "own function" % match.group(1)))
                break

    return out


BLOCK_OPENERS = ("function", "if", "for", "while")

#[[
#   A line ending in one of these is unfinished, so the next line continues it
#   rather than starting a new field. `)` and `}` are deliberately NOT here: a
#   line ending in `Vector(1, 2, 3)` is a COMPLETE field and still needs its
#   comma.
#]]
OPEN_ENDINGS = (",", ";", "{", "(", "[", "..", "=", "then", "do", "or", "and",
                "not", "function", "return", "+", "-", "*", "/", "==", "~=",
                "<", ">", "<=", ">=")


def comma_problems(text):
    """
    Two table fields on consecutive lines with no comma between them.

    ```lua
    {key = "Primary.Cone", name = "Spread cone", kind = "number",
        min = 0, max = 1, decimals = 3, default = 0.03
        note = "radians of inaccuracy per shot"},
    ```

    is a syntax error, and everything else in this file is blind to it: every
    bracket balances and every block closes. A scripted edit inserted thirteen
    of these at once and the only thing between that and a schema which would
    not load was reading the diff afterwards.

    WORKED IN TOKENS, not in text, so a `--` or `//` comment at the end of a
    line cannot be mistaken for the end of the line - which is exactly what a
    first version did, on somebody else's addon.

    WHICH LINES COUNT: only those whose innermost open construct is a `{`. A
    plain `x = 1` in a function body looks identical and is fine, and so does
    the body of a `function` value inside a table - so blocks are tracked as
    well as brackets, and a line is a table field only when nothing has been
    opened since the brace.
    """
    stack = []
    context = {}      # line -> innermost open construct
    firsts = {}       # line -> first two tokens
    lasts = {}        # line -> last token

    for line, kind, value in tokenize(text):
        if line not in context:
            context[line] = stack[-1] if stack else None

        firsts.setdefault(line, []).append((kind, value))
        lasts[line] = (kind, value)

        if kind == "sym":
            if value in "{([":
                stack.append(value)
            elif value in "})]" and stack:
                stack.pop()
        elif kind == "name":
            if value in BLOCK_OPENERS:
                stack.append(value)
            elif value == "end" and stack:
                stack.pop()

    def IsField(line):
        tokens = firsts.get(line) or []

        return (len(tokens) >= 2 and tokens[0][0] == "name"
                and tokens[1] == ("sym", "="))

    #[[
    #   THE END OF THE LINE, WITHOUT ITS COMMENT.
    #
    #   The tokenizer does not emit numbers - it has never needed to - so the
    #   last TOKEN of `default = 0.03` is the `=`, and a check that trusted it
    #   would think the line was unfinished. So the ending is read from the
    #   text, with the comment taken off.
    #
    #   A `--` or `//` inside a string is left alone: if the quotes before it
    #   are unbalanced it is part of a string ("http://..."), not a comment.
    #]]
    def Ending(text_):
        for marker in ("--", "//"):
            at = text_.find(marker)

            while at != -1:
                if (text_.count('"', 0, at) % 2 == 0
                        and text_.count("'", 0, at) % 2 == 0):
                    text_ = text_[:at]

                    break

                at = text_.find(marker, at + 1)

        return text_.rstrip()

    out = []
    lines = text.split("\n")

    for line in sorted(lasts):
        following = line + 1

        while following <= len(lines) and following not in lasts:
            following += 1

        if following not in lasts:
            continue

        if context.get(line) != "{" or context.get(following) != "{":
            continue

        if not IsField(line) or not IsField(following):
            continue

        ending = Ending(lines[line - 1])

        if not ending or ending.endswith(OPEN_ENDINGS):
            continue

        out.append((line,
                    "table field with no comma after it - the next line "
                    "starts another field, so this is a syntax error"))

    return out


def check(path):
    """Return a list of problem strings for one file."""
    try:
        text = io.open(path, encoding="utf-8", errors="replace").read()
    except Exception as e:
        return ["unreadable (%s)" % e]

    brackets = []   # (line, char)
    blocks = []     # (line, keyword)
    problems = []
    adjacent = []   # lines where one string literal follows another
    lastWasString = False

    try:
        for line, kind, value in tokenize(text):
            if kind == "str":
                if lastWasString:
                    adjacent.append(line)
                lastWasString = True
                continue

            lastWasString = False

            if kind == "sym":
                if value in "([{":
                    brackets.append((line, value))
                elif value in PAIRS:
                    if not brackets:
                        problems.append("line %d: stray closing '%s'" % (line, value))
                    elif brackets[-1][1] != PAIRS[value]:
                        oline, ochar = brackets.pop()
                        problems.append(
                            "line %d: '%s' closes '%s' opened on line %d"
                            % (line, value, ochar, oline))
                    else:
                        brackets.pop()
                continue

            if value in OPENERS:
                blocks.append((line, value))
            elif value in CLOSERS:
                if not blocks:
                    problems.append("line %d: stray '%s'" % (line, value))
                    continue
                oline, okw = blocks[-1]
                if okw not in CLOSERS[value]:
                    problems.append(
                        "line %d: '%s' cannot close '%s' opened on line %d"
                        % (line, value, okw, oline))
                blocks.pop()
    except Problem as p:
        problems.append("line %d: %s" % (p.line, p.message))
        return problems

    for line, char in brackets:
        problems.append("line %d: unclosed '%s'" % (line, char))
    for line, kw in blocks:
        problems.append("line %d: unclosed '%s' block" % (line, kw))

    # Adjacent string literals, found while tokenising above.
    #
    # The first version of this scanned raw text with a regex and was
    # wrong: in `f("a", "b")` it happily matched the `", "` BETWEEN the
    # two strings as if that were itself a string, and reported 131
    # files. Only the tokeniser knows which quotes are real boundaries.
    for line in adjacent:
        problems.append(
            "line %d: two string literals with nothing between them "
            "- a missing ',' ?" % line)

    # Valid Lua that GMod's own parser rejects; see GMOD_ILLEGAL.
    for line, message in gmod_problems(text):
        problems.append("line %d: %s" % (line, message))

    # A method used as a value - see method_problems.
    for line, message in method_problems(text):
        problems.append("line %d: %s" % (line, message))

    # A cl_ file hanging a function on a table that does not exist yet.
    for line, message in table_problems(path, text):
        problems.append("line %d: %s" % (line, message))

    # A listener that answers a hook which was not asking - see hook_problems.
    for line, message in hook_problems(text):
        problems.append("line %d: %s" % (line, message))

    # Two table fields with no comma between them - see comma_problems.
    for line, message in comma_problems(text):
        problems.append("line %d: %s" % (line, message))

    return problems


def main():
    targets = sys.argv[1:] or ["."]
    files = []

    for t in targets:
        if os.path.isfile(t):
            files.append(t)
            continue
        for root, dirs, names in os.walk(t):
            for nm in sorted(names):
                if nm.endswith(".lua"):
                    files.append(os.path.join(root, nm))

    bad = 0
    for path in files:
        problems = check(path)
        if problems:
            bad += 1
            print("  %s" % path.replace("\\", "/"))
            for p in problems:
                print("      %s" % p)

    print("\nchecked %d lua files, %d with problems" % (len(files), bad))
    return 1 if bad else 0


sys.exit(main())

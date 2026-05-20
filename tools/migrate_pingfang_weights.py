"""
One-shot migration: replace FontWeight.wXXX with AppFont.wXXX inside every
`TextStyle(...)` block whose body contains `fontFamily: 'PingFang SC'`.

Rules:
- Only weights 300/400/500/600 are touched (PingFang OTF in pubspec tops at 600).
- If the modified block was prefixed with `const`, drop the `const` keyword
  (because `AppFont.wXXX` resolves at runtime via `defaultTargetPlatform`).
- Insert `import 'package:the_road_of_music_flutter/core/theme/app_font.dart';`
  into any file that ended up touched.
- Skip the helper file itself.

The scanner handles nested parens and Dart string literals (single/double,
triple-quoted) plus line/block comments. It does NOT handle string-interpolation
expressions that themselves contain unbalanced parens — none of those exist in
the repo for our target blocks.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(r"c:\Users\nw663\Desktop\music2\the-road-of-music-flutter\lib")
SKIP_FILES = {ROOT / "core" / "theme" / "app_font.dart"}
PINGFANG_TOKEN = "fontFamily: 'PingFang SC'"
PACKAGE = "the_road_of_music_flutter"
IMPORT_LINE = f"import 'package:{PACKAGE}/core/theme/app_font.dart';"

WEIGHT_RE = re.compile(r"\bFontWeight\.w(300|400|500|600)\b")
TEXTSTYLE_RE = re.compile(r"\bTextStyle\s*\(")
CONST_PREFIX_RE = re.compile(r"\bconst\s+$")


def find_balanced(src: str, open_paren_idx: int) -> int:
    """Given index of '(' return index just AFTER the matching ')'.

    Returns -1 if no match (malformed input).
    """
    assert src[open_paren_idx] == "("
    i = open_paren_idx
    depth = 0
    n = len(src)
    while i < n:
        c = src[i]
        # Comments
        if c == "/" and i + 1 < n:
            nxt = src[i + 1]
            if nxt == "/":
                end = src.find("\n", i)
                if end == -1:
                    return -1
                i = end + 1
                continue
            if nxt == "*":
                end = src.find("*/", i + 2)
                if end == -1:
                    return -1
                i = end + 2
                continue
        # Strings
        if c == "'" or c == '"':
            quote = c
            # Triple-quoted?
            if src[i : i + 3] == quote * 3:
                end_seq = quote * 3
                j = i + 3
                while j < n:
                    if src[j] == "\\":
                        j += 2
                        continue
                    if src[j : j + 3] == end_seq:
                        j += 3
                        break
                    j += 1
                i = j
                continue
            # Simple string
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == quote:
                    j += 1
                    break
                if src[j] == "\n":
                    # Dart single-line strings can't contain raw newline; bail.
                    break
                j += 1
            i = j
            continue
        if c == "(":
            depth += 1
            i += 1
            continue
        if c == ")":
            depth -= 1
            i += 1
            if depth == 0:
                return i
            continue
        i += 1
    return -1


def transform(src: str) -> tuple[str, int]:
    """Return (new_src, replacements_count)."""
    if PINGFANG_TOKEN not in src:
        return src, 0

    out: list[str] = []
    cursor = 0
    n = len(src)
    total_repls = 0
    pos = 0

    while pos < n:
        m = TEXTSTYLE_RE.search(src, pos)
        if not m:
            break
        ts_kw_start = m.start()
        paren_idx = m.end() - 1
        end = find_balanced(src, paren_idx)
        if end == -1:
            pos = paren_idx + 1
            continue
        block = src[ts_kw_start:end]

        if PINGFANG_TOKEN not in block:
            pos = end
            continue

        new_block, n_repl = WEIGHT_RE.subn(r"AppFont.w\1", block)
        if n_repl == 0:
            # No weight in 300-600 to bump (could be only w100/w200/w700+, or none).
            pos = end
            continue

        # Check for `const` prefix immediately before TextStyle.
        # We look in the slice [cursor, ts_kw_start] so we don't strip
        # a `const` that belongs to a block we already emitted.
        before = src[cursor:ts_kw_start]
        cm = CONST_PREFIX_RE.search(before)
        emit_before_end = ts_kw_start
        if cm is not None:
            # Strip the `const ` keyword from emitted text.
            emit_before_end = cursor + cm.start()

        out.append(src[cursor:emit_before_end])
        out.append(new_block)
        cursor = end
        pos = end
        total_repls += n_repl

    if total_repls == 0:
        return src, 0

    out.append(src[cursor:])
    new_src = "".join(out)
    return new_src, total_repls


_CONST_CTOR_RE = re.compile(
    # `const` keyword + one identifier (optionally `.name`, optionally `<...>`)
    # followed by `(`. Captures the keyword span so we can strip it cleanly.
    r"\bconst\s+(?=[A-Z_])\w+(?:\.\w+)?(?:<[^>]*>)?\s*\("
)


def strip_broken_consts(src: str) -> tuple[str, int]:
    """Drop the `const` keyword from any constructor whose body now contains
    `AppFont.` (a runtime expression). Repeats until stable so nested const
    chains all get cleaned in one go.

    Returns (new_src, strips_count).
    """
    total = 0
    while True:
        # Collect all positions to strip in this pass.
        strips: list[tuple[int, int]] = []
        pos = 0
        while pos < len(src):
            m = _CONST_CTOR_RE.search(src, pos)
            if not m:
                break
            paren_idx = m.end() - 1
            end = find_balanced(src, paren_idx)
            if end == -1:
                pos = paren_idx + 1
                continue
            body = src[paren_idx + 1 : end - 1]
            if "AppFont." in body:
                # Strip the `const ` (keyword + following whitespace) from
                # [m.start(), <ident_start>). The match always starts on
                # `const` (\b ensures word boundary).
                const_end = m.start() + len("const")
                ws_end = const_end
                while ws_end < len(src) and src[ws_end] in " \t\r\n":
                    ws_end += 1
                strips.append((m.start(), ws_end))
            # Continue searching INSIDE the body so nested `const X(` also
            # get a chance to be stripped in the same pass.
            pos = paren_idx + 1
        if not strips:
            break
        # Apply strips back-to-front so earlier indices stay valid.
        strips.sort(reverse=True)
        # Deduplicate (same position can match if regex overlaps; shouldn't).
        seen = set()
        out_chunks = [src]
        for s, e in strips:
            if s in seen:
                continue
            seen.add(s)
            buf = out_chunks[0]
            out_chunks[0] = buf[:s] + buf[e:]
        src = out_chunks[0]
        total += len(seen)
    return src, total


def insert_import(src: str) -> str:
    if IMPORT_LINE in src:
        return src
    lines = src.split("\n")
    last_import = -1
    for idx, line in enumerate(lines):
        s = line.lstrip()
        if s.startswith("import ") or s.startswith("export "):
            last_import = idx
            continue
        if s == "" or s.startswith("//") or s.startswith("/*"):
            continue
        if s.startswith("library ") or s.startswith("part "):
            last_import = idx
            continue
        # First non-import-non-blank statement; stop.
        break
    if last_import == -1:
        lines.insert(0, IMPORT_LINE)
    else:
        lines.insert(last_import + 1, IMPORT_LINE)
    return "\n".join(lines)


def main() -> int:
    touched: list[tuple[Path, int]] = []
    skip_resolved = {f.resolve() for f in SKIP_FILES}
    for p in ROOT.rglob("*.dart"):
        if p.resolve() in skip_resolved:
            continue
        raw = p.read_bytes()
        # Preserve original newline style by detecting CRLF and normalising
        # the working buffer to LF for transformation.
        is_crlf = b"\r\n" in raw
        try:
            src = raw.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if is_crlf:
            src = src.replace("\r\n", "\n")
        if PINGFANG_TOKEN not in src:
            continue
        new_src, n = transform(src)
        new_src, _strips = strip_broken_consts(new_src)
        if n > 0:
            new_src = insert_import(new_src)
        if new_src == src:
            continue
        if is_crlf:
            new_src = new_src.replace("\n", "\r\n")
        p.write_bytes(new_src.encode("utf-8"))
        touched.append((p, n + _strips))

    print(f"Modified {len(touched)} files, total {sum(n for _, n in touched)} weight replacements.")
    for p, n in touched:
        try:
            rel = p.relative_to(ROOT.parent)
        except ValueError:
            rel = p
        print(f"  {rel}  ({n})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

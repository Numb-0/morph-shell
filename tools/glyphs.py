#!/usr/bin/env python3
"""Builds assets/glyphs.tsv, what the emoji picker searches.

One glyph a line, as `glyph<TAB>name<TAB>keywords`: every fully-qualified
emoji in Unicode's emoji-test.txt order, less the skin tone variants,
then the symbols CLDR has English names for -- arrows, maths, quotes,
dashes and the like -- in code point order. The keywords are CLDR's,
less any word the name already has.

Regenerate after a Unicode or CLDR release:

    python3 tools/glyphs.py \\
        $(nix build --no-link --print-out-paths nixpkgs#unicode-emoji)/share/unicode/emoji/emoji-test.txt \\
        $(nix build --no-link --print-out-paths nixpkgs#cldr-annotations)/share/unicode/cldr/common/annotations/en.xml \\
        > assets/glyphs.tsv
"""

import re
import sys
import xml.etree.ElementTree as ET

SKIN_TONES = {chr(c) for c in range(0x1F3FB, 0x1F400)}
VS16 = "️"


def annotations(path):
    names, keywords = {}, {}
    for a in ET.parse(path).getroot().iter("annotation"):
        cp, text = a.get("cp"), (a.text or "").strip()
        if a.get("type") == "tts":
            names[cp] = text
        else:
            keywords[cp] = [k.strip() for k in text.split("|") if k.strip()]
    return names, keywords


def clean(text):
    return re.sub(r"\s+", " ", text).strip()


def row(glyph, name, keywords):
    words = set(name.lower().split())
    extra = []
    for k in keywords:
        k = k.lower()
        if k not in words and k != name.lower() and k not in extra:
            extra.append(k)
    return f"{glyph}\t{clean(name)}\t{clean(' '.join(extra))}"


def main(emoji_test, cldr):
    names, keywords = annotations(cldr)
    rows, seen = [], set()

    line = re.compile(r"^[0-9A-F ]+;\s*fully-qualified\s*#\s*(\S+)\s+E\d+\.\d+\s+(.+)$")
    with open(emoji_test, encoding="utf-8") as f:
        for text in f:
            m = line.match(text.strip())
            if not m:
                continue
            glyph, name = m.groups()
            if any(c in SKIN_TONES for c in glyph):
                continue
            bare = glyph.replace(VS16, "")
            rows.append(row(glyph, name, keywords.get(bare, keywords.get(glyph, []))))
            seen.add(bare)

    # ASCII is on every keyboard already.
    symbols = [cp for cp in names if cp.replace(VS16, "") not in seen and not all(ord(c) < 0x80 for c in cp)]
    for cp in sorted(symbols, key=lambda s: [ord(c) for c in s]):
        rows.append(row(cp, names[cp], keywords.get(cp, [])))

    sys.stdout.write("\n".join(rows) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

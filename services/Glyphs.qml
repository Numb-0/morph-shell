pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Morph.Search

// What the dock's emoji panel picks from: every emoji, and the symbols
// a keyboard lacks -- arrows, dashes, maths, quotes -- each with its
// name and the words people search it by. Picking one puts it on the
// clipboard, and keeps it among the recent ones the panel opens on.
//
// The table is assets/glyphs.tsv, built from Unicode's and CLDR's data
// by tools/glyphs.py. It is only read the first time the panel opens.
Singleton {
    id: root

    // Every glyph, as { glyph, name, keywords }, in the table's order:
    // emoji as Unicode groups them, then the symbols.
    property var all: []

    // Set by the panel opening, which is when the table is first wanted.
    property bool wanted: false

    readonly property var recent: state.recent

    // Enough to fill the first few rows of the panel's grid.
    readonly property int recentMax: 27

    // Straight to wl-copy, as the clipboard panel's copies are, and to
    // the front of the recent ones.
    function pick(entry: var): void {
        if (!entry)
            return;

        Quickshell.execDetached(["wl-copy", "--", entry.glyph]);
        state.recent = [entry.glyph, ...state.recent.filter(g => g !== entry.glyph)].slice(0, recentMax);
    }

    // A word of the name or the keywords that starts with what was typed
    // beats one that only contains it, and a name beats a keyword, so
    // "heart" puts ❤️ ahead of 😍, which only lists it. The fuzzy match
    // is held back until a few letters are in, and to glyphs no plain
    // match found, so a typo still finds something without drowning
    // the real matches in near misses.
    readonly property int fuzzyFrom: 4

    function score(entry: var, typed: string): real {
        if (entry.lname === typed)
            return 5;
        if (entry.lname.startsWith(typed))
            return 4;
        if (entry.lname.includes(" " + typed))
            return 3.5;
        if (entry.keywords.startsWith(typed) || entry.keywords.includes(" " + typed))
            return 3;
        if (entry.lname.includes(typed))
            return 2.5;
        if (entry.keywords.includes(typed))
            return 2;

        return 0;
    }

    // The recent ones first, then the whole table, when nothing is typed.
    function search(query: string): var {
        const typed = (query ?? "").trim().toLowerCase();

        if (typed.length === 0) {
            const recentSet = new Set(recent);
            const recents = recent.map(g => byGlyph[g]).filter(e => e !== undefined);
            return [...recents, ...all.filter(e => !recentSet.has(e.glyph))];
        }

        // Ties go to the recent ones, then to the table's own order.
        const rank = g => {
            const i = recent.indexOf(g);
            return i < 0 ? recentMax : i;
        };

        let found = all.map((entry, i) => ({
                    entry,
                    i,
                    score: score(entry, typed)
                })).filter(r => r.score > 0);

        if (found.length === 0 && typed.length >= fuzzyFrom)
            found = all.map((entry, i) => ({
                        entry,
                        i,
                        score: Math.max(Fuzzy.score(typed, entry.lname), Fuzzy.score(typed, entry.keywords) * 0.9)
                    })).filter(r => r.score >= 0.8);

        return found.sort((a, b) => b.score - a.score || rank(a.entry.glyph) - rank(b.entry.glyph) || a.i - b.i).map(r => r.entry);
    }

    property var byGlyph: ({})

    function parse(text: string): void {
        const entries = text.split("\n").filter(line => line.length > 0).map(line => {
            const [glyph, name, keywords] = line.split("\t");
            return {
                glyph,
                name,
                lname: name.toLowerCase(),
                keywords: keywords ?? ""
            };
        });

        const index = {};
        for (const e of entries)
            index[e.glyph] = e;

        byGlyph = index;
        all = entries;
    }

    FileView {
        path: root.wanted ? Quickshell.shellPath("assets/glyphs.tsv") : ""

        onLoaded: root.parse(text())
        onLoadFailed: error => console.warn(`glyphs: could not read the glyph table (${error}); the emoji panel is empty.`)
    }

    FileView {
        path: Quickshell.statePath("glyphs.json")

        // Missing until the first pick, which is no error.
        printErrors: false

        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state

            property var recent: []
        }
    }
}

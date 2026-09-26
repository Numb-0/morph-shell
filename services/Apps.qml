pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// The desktop's applications, as the dock and the launcher want them:
// a list to search, a way to start one, and a way to tell which are
// already running.
Singleton {
    id: root

    // DesktopEntries and ToplevelManager are both built on first access
    // and fill in a moment later, so a cold read returns nothing at all.
    // Holding them here means they are already indexing by the time
    // anything asks, rather than coming up empty on the first frame the
    // dock is drawn.
    readonly property var model: DesktopEntries.applications
    readonly property var toplevelModel: ToplevelManager.toplevels

    // Plain arrays rather than typed list properties: a list<T> reaches
    // JavaScript as a list reference, which indexes but has no map or
    // filter, and every use here is an array operation.
    readonly property var all: model.values
    readonly property var toplevels: toplevelModel.values

    // An id as a .desktop file spells it, lowercased and without the
    // suffix, which is what a toplevel's app id usually turns out to be.
    function normalise(id: string): string {
        return (id ?? "").toLowerCase().replace(/\.desktop$/, "");
    }

    // Pinned apps are configured by id, which is exact and survives a
    // rename of the application's display name. The heuristic lookup
    // catches the near misses -- "code" for "code-url-handler", a
    // vendor-prefixed id -- so a pin does not silently vanish.
    function byId(id: string): DesktopEntry {
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? null;
    }

    // Every window belonging to an app, so the dock can mark it running
    // and focus it rather than starting a second copy.
    function windowsFor(entry: DesktopEntry): var {
        if (!entry)
            return [];

        const id = normalise(entry.id);
        const cls = normalise(entry.startupClass);

        return toplevels.filter(t => {
            const appId = normalise(t.appId);
            return appId === id || (cls.length > 0 && appId === cls);
        });
    }

    function isRunning(entry: DesktopEntry): bool {
        return windowsFor(entry).length > 0;
    }

    function launch(entry: DesktopEntry): void {
        entry?.execute();
    }

    // What a click on a dock icon does: raise what is already there, and
    // only start something when there is nothing to raise. Cycles
    // through an app's windows on repeat clicks rather than sticking on
    // the first, so a second click on a focused app moves to its next
    // window.
    function activate(entry: DesktopEntry): void {
        const windows = windowsFor(entry);
        if (windows.length === 0) {
            launch(entry);
            return;
        }

        const active = ToplevelManager.activeToplevel;
        const current = windows.indexOf(active);
        windows[(current + 1) % windows.length].activate();
    }

    // Ranked rather than filtered: an exact name beats a name that
    // starts with the query, which beats one that merely contains it,
    // and the metadata fields -- what the app calls itself generically,
    // its keywords, its categories -- rank below all of those. Ties go
    // to the shorter name, so "Files" outranks "Files (Nautilus)".
    function score(entry: DesktopEntry, query: string): real {
        const name = (entry.name ?? "").toLowerCase();
        const penalty = Math.min(name.length, 60) / 100;

        if (name === query)
            return 1000;
        if (name.startsWith(query))
            return 900 - penalty;
        if (name.split(/[\s\-_]+/).some(word => word.startsWith(query)))
            return 800 - penalty;
        if (name.includes(query))
            return 700 - penalty;

        const generic = (entry.genericName ?? "").toLowerCase();
        if (generic.includes(query))
            return 600 - penalty;

        if ((entry.keywords ?? []).some(k => k.toLowerCase().includes(query)))
            return 500 - penalty;

        if (normalise(entry.id).includes(query))
            return 400 - penalty;

        if ((entry.categories ?? []).some(c => c.toLowerCase().includes(query)))
            return 300 - penalty;

        if ((entry.comment ?? "").toLowerCase().includes(query))
            return 200 - penalty;

        // Last resort: the query's letters in order but not adjacent, so
        // "gimp" still finds GNU Image Manipulation Program and a typed
        // "fx" finds Firefox.
        return subsequence(name, query) ? 100 - penalty : 0;
    }

    function subsequence(text: string, query: string): bool {
        let at = 0;
        for (const ch of query) {
            at = text.indexOf(ch, at) + 1;
            if (at === 0)
                return false;
        }
        return true;
    }

    // Empty query lists everything alphabetically -- the launcher opens
    // on the whole menu rather than on nothing.
    function search(query: string): var {
        const trimmed = (query ?? "").trim().toLowerCase();

        if (trimmed.length === 0)
            return [...all].sort((a, b) => a.name.localeCompare(b.name));

        return all.map(entry => ({
                entry,
                score: score(entry, trimmed)
            })).filter(r => r.score > 0).sort((a, b) => b.score - a.score).map(r => r.entry);
    }
}

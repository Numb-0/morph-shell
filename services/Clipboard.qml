pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The clipboard's history, as the dock's clipboard panel wants it: what
// was copied, newest first, a way to search it, and a way to put an
// entry back on the clipboard.
//
// cliphist keeps the history; the shell only feeds it and reads it. The
// feeding is two wl-paste watchers, one for text and one for images, as
// cliphist's own docs set them up -- held here rather than left to the
// compositor config, so the history is there wherever the shell runs.
// One already started from the compositor does no harm: cliphist drops
// an entry it already has rather than storing it twice.
Singleton {
    id: root

    // Without cliphist there is no history to keep, and the dock's
    // clipboard button is not drawn.
    property bool available: false

    // Every entry, newest first, as { id, text, image, format, width,
    // height, size, path }: `text` is cliphist's one-line preview, and
    // the rest only mean anything for an image -- `path` being the
    // thumbnail decoded into the cache.
    property var entries: []

    // Decoded images, one file per entry, named by its id. The listing
    // fills in any that are missing and drops any whose entry is gone.
    readonly property string thumbDir: Quickshell.cachePath("clipboard")

    // Wide enough to fill the panel's two lines and to give a search
    // more than the first few words to go on.
    readonly property int previewWidth: 200

    // A search is a plain substring match rather than the launcher's
    // fuzzy one: a query held up against a whole paragraph scores low
    // however well it matches a part of it.
    function search(query: string): var {
        const trimmed = (query ?? "").trim().toLowerCase();
        if (trimmed.length === 0)
            return entries;

        return entries.filter(e => e.text.toLowerCase().includes(trimmed));
    }

    // Straight to wl-copy, which tells text from an image by itself. The
    // watcher then hands the entry back to cliphist, which moves it to
    // the top of the history rather than storing it again.
    function copy(entry: var): void {
        if (!entry)
            return;

        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "morph-shell-clipboard", entry.id]);
    }

    // Taken off the list at once, so the row leaves under the pointer
    // rather than when cliphist is done.
    function remove(entry: var): void {
        if (!entry)
            return;

        entries = entries.filter(e => e.id !== entry.id);
        run(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "morph-shell-clipboard", entry.id]);
    }

    function wipe(): void {
        entries = [];
        run(["cliphist", "wipe"]);
    }

    // Changes go through one at a time, each one listing afresh when it
    // is done. A change landing while one runs waits its turn, so two
    // quick deletes both happen.
    property var queue: []

    function run(command: var): void {
        queue = [...queue, command];
        if (!changer.running)
            next();
    }

    function next(): void {
        if (queue.length === 0) {
            refresh();
            return;
        }

        changer.command = queue[0];
        queue = queue.slice(1);
        changer.running = true;
    }

    // A listing asked for while one is running is not dropped: the one
    // running may already have read the history from before the change.
    property bool stale: false

    function refresh(): void {
        if (!available)
            return;

        if (lister.running) {
            stale = true;
            return;
        }

        lister.running = true;
    }

    // An image's preview reads `[[ binary data 12 KiB png 1920x1080 ]]`;
    // binary data cliphist could not read as an image has no format or
    // size after the byte count.
    readonly property var binary: /^\[\[ binary data (\S+ \S+)(?: (\w+) (\d+)x(\d+))? \]\]$/

    // Entries that were already listed are handed back as the same
    // objects, so the panel's list only animates what actually changed
    // rather than every row on every listing.
    function parse(output: string): var {
        const known = new Map(entries.map(e => [e.id, e]));

        return output.split("\n").filter(line => line.length > 0).map(line => {
            const tab = line.indexOf("\t");
            const id = line.slice(0, tab);
            const text = line.slice(tab + 1);

            const old = known.get(id);
            if (old && old.text === text)
                return old;

            const match = text.match(binary);
            if (!match)
                return {
                    id,
                    text,
                    image: false
                };

            const format = match[2] ?? "";
            return {
                id,
                text,
                image: format.length > 0,
                format,
                width: Number(match[3] ?? 0),
                height: Number(match[4] ?? 0),
                size: match[1],
                path: format.length > 0 ? `${thumbDir}/${id}.${format}` : ""
            };
        });
    }

    // Lists the history, decoding any image that has no thumbnail yet
    // before printing, so every path the listing names is already a file
    // by the time the panel loads it. Thumbnails whose entry has gone --
    // deleted, wiped, or pushed out by cliphist's own cap -- go with it.
    readonly property string listScript: `
        dir="$1"
        mkdir -p "$dir" || exit 1
        list=$(cliphist -preview-width ${previewWidth} list) || exit 1

        printf '%s\\n' "$list" | while IFS="$(printf '\\t')" read -r id preview; do
            format=$(printf '%s' "$preview" | sed -n 's/^\\[\\[ binary data [^ ]* [^ ]* \\([a-z0-9]*\\) [0-9]*x[0-9]* \\]\\]$/\\1/p')
            [ -n "$format" ] || continue
            [ -s "$dir/$id.$format" ] || cliphist decode "$id" > "$dir/$id.$format"
        done

        for file in "$dir"/*; do
            [ -e "$file" ] || continue
            id=\${file##*/}
            id=\${id%%.*}
            printf '%s\\n' "$list" | grep -q "^$id$(printf '\\t')" || rm -f "$file"
        done

        printf '%s\\n' "$list"
    `

    Process {
        running: true

        command: ["cliphist", "version"]

        onExited: code => {
            root.available = code === 0;
            if (root.available)
                root.refresh();
            else
                console.warn("clipboard: cliphist is not installed; the clipboard history is off.");
        }
    }

    Process {
        id: lister

        command: ["sh", "-c", root.listScript, "morph-shell-clipboard", root.thumbDir]

        stdout: StdioCollector {
            onStreamFinished: root.entries = root.parse(text)
        }

        onExited: {
            if (root.stale) {
                root.stale = false;
                root.refresh();
            }
        }
    }

    Process {
        id: changer

        onExited: root.next()
    }

    // The watchers. Each says a line once cliphist has stored what was
    // copied, which is the cue to list the history again -- so the panel
    // follows the clipboard even while it is open.
    Variants {
        model: root.available ? ["text", "image"] : []

        Process {
            required property string modelData

            running: true

            command: ["wl-paste", "--type", modelData, "--watch", "sh", "-c", "cliphist store && echo stored"]

            stdout: SplitParser {
                onRead: root.refresh()
            }
        }
    }
}

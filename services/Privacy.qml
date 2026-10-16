pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Who is listening and watching: the applications taking the
// microphone, the camera or the screen right now, by name.
//
// The microphone and the screen come from Pipewire's links. A capture
// stream fed from a real input counts as the microphone; one fed from
// an output's monitor -- a recorder, the mixer's own peak meters -- is
// not. A screen share is a video stream fed from something other than
// a camera, which on Hyprland is the portal's cast.
//
// The camera is mostly opened directly, so it also comes from asking
// which processes hold a /dev/video* open. Pipewire holding one stands
// for whoever it is feeding, and those are found through its links.
Singleton {
    id: root

    readonly property var mic: names(Pipewire.linkGroups.values.filter(g => g.source?.type === PwNodeType.AudioSource && isStream(g.target)))

    readonly property var screen: names(Pipewire.linkGroups.values.filter(g => isVideo(g.source) && !isCamera(g.source) && isStream(g.target)))

    readonly property var camera: unique([...names(Pipewire.linkGroups.values.filter(g => isCamera(g.source) && isStream(g.target))), ...holders])

    readonly property bool micInUse: mic.length > 0
    readonly property bool cameraInUse: camera.length > 0
    readonly property bool screenInUse: screen.length > 0
    readonly property bool any: micInUse || cameraInUse || screenInUse

    // Every application at it, once each, for saying who in one line.
    readonly property var everyone: unique([...mic, ...camera, ...screen])

    function isStream(node: PwNode): bool {
        return node?.isStream ?? false;
    }

    function isVideo(node: PwNode): bool {
        return ((node?.type ?? 0) & PwNodeType.Video) !== 0;
    }

    // Pipewire names the camera nodes after the device API that found
    // them; anything else sending video is not a camera.
    function isCamera(node: PwNode): bool {
        return isVideo(node) && /^(v4l2|libcamera)_/.test(node?.name ?? "");
    }

    function names(groups: var): var {
        return unique(groups.map(g => {
            const props = g.target?.properties ?? {};
            return pretty(props["application.name"] || props["application.process.binary"] || g.target?.name || "");
        }));
    }

    function unique(list: var): var {
        return list.filter((name, i) => name !== "" && list.indexOf(name) === i);
    }

    // What the desktop entry calls the application, when there is one:
    // processes and streams go by the binary's name, and on NixOS that
    // can be .firefox-wrapped.
    function pretty(id: string): string {
        const bare = id.replace(/^\./, "").replace(/-wrapped$/, "");
        return Apps.byId(Apps.normalise(bare))?.name || bare;
    }

    // The application names need the streams' properties, which
    // Pipewire only keeps current for nodes something is tracking.
    PwObjectTracker {
        objects: Pipewire.linkGroups.values.filter(g => root.isStream(g.target)).map(g => g.target)
    }

    // Processes with a camera open, by name -- Pipewire and its session
    // manager aside, as they only ever hold one for someone else.
    property var holders: []

    Process {
        id: scan

        command: ["sh", "-c", "find /proc/[0-9]*/fd -lname '/dev/video*' 2>/dev/null | cut -d/ -f3 | sort -u | while read -r pid; do cat \"/proc/$pid/comm\" 2>/dev/null; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = root.unique(text.split("\n").filter(name => name !== "" && !/^(pipewire|wireplumber)/.test(name)).map(name => root.pretty(name)));
                if (JSON.stringify(found) !== JSON.stringify(root.holders))
                    root.holders = found;
            }
        }
    }

    // Opening a device says nothing anywhere a shell can hear, so this
    // asks every couple of seconds. The scan reads only link names, and
    // takes a few tens of milliseconds.
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 2000

        onTriggered: scan.running = true
    }
}

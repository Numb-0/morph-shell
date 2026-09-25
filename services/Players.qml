pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var all: Mpris.players.values

    // Whatever is actually playing, else the first player that exists.
    readonly property var active: {
        const playing = all.find(p => p.isPlaying);
        if (playing)
            return playing;
        return all.length > 0 ? all[0] : null;
    }

    readonly property bool available: active !== null
    readonly property bool playing: active?.isPlaying ?? false

    // Quickshell reports `length` as the current position when the player
    // publishes no duration -- Firefox and most browser sources do not.
    // Taking it at face value makes progress permanently 1.0, so treat an
    // unsupported length as no length at all.
    readonly property bool lengthKnown: (active?.lengthSupported ?? false) && (active?.length ?? 0) > 0
    readonly property real length: lengthKnown ? active.length : 0

    readonly property bool seekable: (active?.canSeek ?? false) && (active?.positionSupported ?? false) && lengthKnown

    // The player's own declared capabilities. Browsers in particular
    // support almost none of these, so the UI is built from them rather
    // than from assumptions.
    readonly property bool canControl: active?.canControl ?? false
    readonly property bool canTogglePlaying: active?.canTogglePlaying ?? false
    readonly property bool canGoNext: active?.canGoNext ?? false
    readonly property bool canGoPrevious: active?.canGoPrevious ?? false

    // Where a seek was dropped, held until the player catches up. MPRIS
    // reports the old position for a while after a seek, so without this
    // the handle snaps back to where it was and then jumps forwards.
    property real pendingSeek: -1

    readonly property real position: pendingSeek >= 0 ? pendingSeek : (active?.position ?? 0)
    readonly property real progress: lengthKnown ? Math.max(0, Math.min(1, position / length)) : 0

    function seek(fraction: real): void {
        if (!seekable)
            return;

        const target = Math.max(0, Math.min(1, fraction)) * length;

        pendingSeek = target;
        active.position = target;
        seekGuard.restart();
    }

    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const mins = Math.floor(total / 60);
        const secs = total % 60;
        return `${mins}:${secs < 10 ? "0" : ""}${secs}`;
    }

    Timer {
        id: seekGuard

        interval: 700
        onTriggered: root.pendingSeek = -1
    }

    // MPRIS only reports position when asked. Once per frame while
    // playing, so the handle glides instead of stepping -- a timer at any
    // sane interval makes it visibly tick along.
    FrameAnimation {
        running: root.playing

        onTriggered: root.active?.positionChanged()
    }

    // While paused nothing asks, so the position would sit at whatever it
    // last happened to be -- zero, if we never played. Poll slowly to keep
    // the readout honest, and refresh once whenever the player changes.
    Timer {
        running: root.available && !root.playing

        interval: 1000
        repeat: true
        triggeredOnStart: true

        onTriggered: root.active?.positionChanged()
    }

    onActiveChanged: active?.positionChanged()
}

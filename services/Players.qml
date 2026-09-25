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

    // Which track is loaded. MPRIS publishes an id for it; the player's
    // own uniqueId is no use here, as it numbers players rather than
    // tracks and so never moves when one song follows another. The
    // metadata stands in for the players that publish no id.
    readonly property string trackId: {
        if (!active)
            return "";

        const id = active.metadata?.["mpris:trackid"];
        return id ? String(id) : `${active.trackTitle}\u001f${active.trackArtist}\u001f${active.length}`;
    }

    // A position to report instead of the player's own, held until the
    // player catches up. MPRIS keeps reporting the old position for a
    // moment after a seek and after a track change, so without this the
    // handle stays where it was -- or, when the new track is shorter than
    // the point we left the old one at, pins itself to the end -- before
    // jumping to where it belongs.
    property real heldPosition: -1

    // What the player was reporting when the hold began, so a report that
    // is genuinely about the new track can be told from the stale one it
    // keeps repeating.
    property real heldFrom: 0

    readonly property real position: heldPosition >= 0 ? heldPosition : (active?.position ?? 0)
    readonly property real progress: lengthKnown ? Math.max(0, Math.min(1, position / length)) : 0

    function seek(fraction: real): void {
        if (!seekable)
            return;

        const target = Math.max(0, Math.min(1, fraction)) * length;

        hold(target);
        active.position = target;
    }

    function hold(pos: real): void {
        heldFrom = active?.position ?? 0;
        heldPosition = pos;
        holdGuard.restart();
    }

    function release(): void {
        heldPosition = -1;
        holdGuard.stop();
    }

    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const mins = Math.floor(total / 60);
        const secs = total % 60;
        return `${mins}:${secs < 10 ? "0" : ""}${secs}`;
    }

    property string lastTrackId: ""

    // A new track starts at zero, and the player will not say so for
    // another round trip or two -- so say it here, and hold it there
    // until it does. Not for the first track we see, though: a player
    // that was already going is playing from wherever it was.
    onTrackIdChanged: {
        if (lastTrackId && trackId)
            hold(0);

        lastTrackId = trackId;
        active?.positionChanged();
    }

    // The hold ends as soon as the player either agrees with where it was
    // put, or reports a position that has gone backwards -- which after a
    // skip means the new track, since the stale one only ever climbs.
    Connections {
        target: root.active

        function onPositionChanged(): void {
            if (root.heldPosition < 0)
                return;

            const pos = root.active.position;
            if (Math.abs(pos - root.heldPosition) < 1 || pos < root.heldFrom - 1)
                root.release();
        }
    }

    Timer {
        id: holdGuard

        interval: 700
        onTriggered: root.release()
    }

    // MPRIS only reports position when asked. Sixty times a second while
    // playing, so the handle glides instead of stepping.
    //
    // A timer rather than a FrameAnimation, which is what this wants to
    // be: a FrameAnimation fires inside the animation system's own tick,
    // and anything animating towards a value refreshed from in there is
    // retargeted at the very instant it should be advancing. Its elapsed
    // time never leaves zero, so it never moves at all -- which is to say
    // the progress handle would sit frozen wherever it first appeared.
    Timer {
        running: root.playing

        interval: 16
        repeat: true

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

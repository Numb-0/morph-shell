pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default output, as the bar wants it: one volume, one mute, and the
// glyph that goes with them.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink

    readonly property bool available: sink?.ready ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    // What the device calls itself. The node's own name is a pipewire
    // id -- alsa_output.pci-0000_00_1f.3.analog-stereo and the like --
    // so the description comes first, with the nickname behind it for
    // the sinks that publish no description.
    readonly property string description: sink?.description || sink?.nickname || ""

    readonly property string icon: {
        if (muted || volume <= 0)
            return "volume_off";
        if (volume < 0.33)
            return "volume_mute";
        if (volume < 0.66)
            return "volume_down";
        return "volume_up";
    }

    function setVolume(value: real): void {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    // Turning it up while muted would move a slider that makes no sound,
    // so that gesture unmutes as well. Turning it down does not: quiet
    // is what mute was for.
    function changeVolume(delta: real): void {
        if (!sink?.audio)
            return;

        if (delta > 0 && sink.audio.muted)
            sink.audio.muted = false;

        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    // Pipewire only keeps a node's properties current while something is
    // tracking it. Without this the volume reads zero and never moves.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}

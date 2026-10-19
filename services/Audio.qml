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

    // The default input: its mute for the OSD, and its level for the
    // slider in the panel's device picker.
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool micAvailable: source?.ready ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // What the device calls itself. The node's own name is a pipewire
    // id -- alsa_output.pci-0000_00_1f.3.analog-stereo and the like --
    // so the description comes first, with the nickname behind it for
    // the sinks that publish no description.
    readonly property string description: sink?.description || sink?.nickname || ""

    // Every application playing sound, as the mixer lists them. Output
    // streams only: a recorder or the peak meters' own capture streams
    // are not something you would turn down.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream && n.audio)

    // The devices that could be made the default, for the panel's
    // picker. Hardware and virtual sinks and sources alike, but never a
    // stream: those are applications, and the mixer has them.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    // Asked of pipewire rather than forced: the session manager takes
    // it as the user's choice and remembers it across reboots.
    function setSink(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    // As description does for the default, for any device.
    function deviceName(node: PwNode): string {
        return node?.description || node?.nickname || node?.name || qsTr("Unknown");
    }

    // Guessed from the node's name, which carries the bus it hangs off:
    // bluez_output.*, alsa_output.*.hdmi-stereo and so on.
    function deviceIcon(node: PwNode): string {
        const name = (node?.name ?? "").toLowerCase();
        if (node?.isSink) {
            if (name.startsWith("bluez"))
                return "headphones";
            if (name.includes("hdmi") || name.includes("displayport"))
                return "tv";
            if (name.includes("usb"))
                return "headset";
            return "speaker";
        }
        if (name.startsWith("bluez") || name.includes("usb"))
            return "headset_mic";
        return "mic";
    }

    // What a stream is called. Pipewire's own name for one is whatever
    // the client typed into its connect call -- "playback", "audio
    // stream #3" -- so the application's name comes first.
    function streamName(node: PwNode): string {
        const props = node?.properties ?? {};
        return props["application.name"] || node?.description || node?.nickname || node?.name || qsTr("Unknown");
    }

    // The icon the stream asks for, else the one its desktop entry has,
    // found from the binary it is running as. Empty when neither turns
    // anything up, and the mixer draws a glyph instead.
    function streamIcon(node: PwNode): string {
        const props = node?.properties ?? {};
        const named = props["application.icon-name"];
        if (named) {
            const path = Quickshell.iconPath(named, true);
            if (path)
                return path;
        }

        for (const id of [props["application.process.binary"], props["application.id"], props["application.name"]]) {
            const entry = id ? Apps.byId(Apps.normalise(id)) : null;
            if (entry?.icon)
                return Quickshell.iconPath(entry.icon, true);
        }

        return "";
    }

    // As changeVolume does for the output: turning a muted stream up
    // unmutes it.
    function setStreamVolume(node: PwNode, value: real): void {
        if (!node?.audio)
            return;

        const v = Math.max(0, Math.min(1, value));
        if (v > node.audio.volume && node.audio.muted)
            node.audio.muted = false;

        node.audio.volume = v;
    }

    function toggleStreamMute(node: PwNode): void {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

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

    // As changeVolume does for the output: turning a muted microphone
    // up unmutes it.
    function setMicVolume(value: real): void {
        if (!source?.audio)
            return;

        const v = Math.max(0, Math.min(1, value));
        if (v > source.audio.volume && source.audio.muted)
            source.audio.muted = false;

        source.audio.volume = v;
    }

    function toggleMicMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Pipewire only keeps a node's properties current while something is
    // tracking it. Without this the volume reads zero and never moves.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }
}

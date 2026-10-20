pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services.launcher
import qs.services.system

// Screen recordings, through wf-recorder. The shell picks the region --
// the screenshot picker, in its recording colours -- and wf-recorder
// does the rest, into a file under Videos/Recordings, until it is told
// to stop.
//
// Stopped with SIGINT, as Ctrl+C in a terminal would: wf-recorder takes
// that as the end of the recording and finishes the file, where SIGTERM
// leaves it without its index and unplayable.
Singleton {
    id: root

    // Checked once, as the power profile widget checks for its daemon:
    // without wf-recorder the commands are not offered at all.
    property bool available: false

    readonly property bool recording: proc.running

    // Whether the running recording takes the output's sound as well.
    property bool audio: false

    property string file: ""

    // Seconds since it started, for the bar's timer. Counted from when
    // wf-recorder actually started rather than from the request, so the
    // timer starts at zero with the recording.
    property int elapsed: 0
    property real startedAt: 0

    // Set by stop(), so the exit that follows is told apart from
    // wf-recorder dying on its own.
    property bool stopping: false

    // A region, as the picker hands it over and as grim -g reads it.
    function start(region: string, withAudio: bool): void {
        record(["-g", region], withAudio);
    }

    // A whole output, by name, without picking anything.
    function startOutput(output: string, withAudio: bool): void {
        record(["-o", output], withAudio);
    }

    function record(target: var, withAudio: bool): void {
        if (!available || proc.running)
            return;

        const videos = Quickshell.env("XDG_VIDEOS_DIR") || `${Quickshell.env("HOME")}/Videos`;
        file = `${videos}/Recordings/${Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")}.mp4`;

        // The output's own monitor: what is playing, not the microphone.
        const sink = Audio.sink?.name ?? "";
        audio = withAudio && sink !== "";

        const args = ["-y", ...target];
        if (audio)
            args.push(`--audio=${sink}.monitor`);

        stopping = false;
        elapsed = 0;
        proc.command = ["sh", "-c", `mkdir -p "$(dirname "$1")" || exit 1; file=$1; shift; exec wf-recorder -f "$file" "$@"`, "morph-shell-record", file, ...args];
        proc.running = true;
    }

    function stop(): void {
        if (!proc.running)
            return;

        stopping = true;
        proc.signal(2);
    }

    Process {
        id: proc

        onStarted: root.startedAt = Date.now()

        // wf-recorder says what went wrong on stderr; only read if it
        // fails, so the notification can say why.
        stderr: StdioCollector {
            id: errors
        }

        onExited: code => {
            if (root.stopping || code === 0)
                Quickshell.execDetached(["sh", "-c", root.saved, "morph-shell-record", root.file]);
            else
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-u", "critical", qsTr("Recording failed"), errors.text.trim().split("\n").pop() || qsTr("wf-recorder exited with code %1").arg(code)]);

            root.stopping = false;
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 250

        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    // Announces the file, with a way to it: a click or Open plays it,
    // Show in folder opens where it was saved. notify-send waits on the
    // notification for the action, as the screenshot's does.
    readonly property string saved: `
        [ -s "$1" ] || exit 1

        action=$(notify-send -a "Screen recorder" -t 8000 \\
            -A default=Open -A open=Open -A folder="Show in folder" \\
            "Recording saved" "$(basename "$1")")

        case "$action" in
            default|open) exec xdg-open "$1" ;;
            folder) exec xdg-open "$(dirname "$1")" ;;
        esac
    `

    Process {
        running: true

        command: ["sh", "-c", "command -v wf-recorder"]

        onExited: code => root.available = code === 0
    }

    //   morph-shell ipc call recorder toggle
    IpcHandler {
        target: "recorder"

        // Picks a region to record, or stops the recording under way.
        function toggle(): void {
            if (root.recording)
                root.stop();
            else
                Commands.recordRequested(false);
        }

        function region(): void {
            Commands.recordRequested(false);
        }

        // The focused screen, whole, for a keybind: nothing to pick.
        function screen(): void {
            root.startOutput(Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "", false);
        }

        function screenWithAudio(): void {
            root.startOutput(Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "", true);
        }

        function regionWithAudio(): void {
            Commands.recordRequested(true);
        }

        function stop(): void {
            root.stop();
        }

        function isRecording(): bool {
            return root.recording;
        }
    }
}

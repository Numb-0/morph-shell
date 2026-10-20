pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's calculator: a search that reads as maths or as a unit
// conversion gets its answer, worked out by qalc, as the top result.
//
// qalc reads nearly anything as something -- "firefox" comes back as
// "0 B", a few units multiplied together -- so a search is only handed
// over when it looks like it was meant for it: arithmetic, a number
// converted to another unit, or anything at all after a leading "=".
Singleton {
    id: root

    // Without qalc there is no calculator, and searches stay searches.
    property bool available: false

    readonly property string prefix: "="

    // The answer to the last expression asked about, or "" when it had
    // none worth showing. Kept up while the next one is worked out, so
    // the row reads on through typing rather than blinking out at every
    // keystroke.
    property string result: ""
    property string expression: ""

    // The launcher's row stands for whatever the answer is, rather than
    // carrying it: one object for good, so the list keeps the same row
    // and only its text changes as the answer does.
    readonly property var row: ({
            calc: true
        })

    // Whether a search asks for the calculator outright.
    function forced(query: string): bool {
        return (query ?? "").replace(/^\s+/, "").startsWith(prefix);
    }

    // Digits, operators and brackets, and nothing else: "12*7", "(3+4)/2".
    readonly property var arithmetic: /^[\d\s.,+\-*\/×÷^%()]*\d[\d\s.,+\-*\/×÷^%()]*$/

    // A number and a unit, then "to" or "in" and another unit:
    // "5 km in mi", "100 °F to °C", "10usd to eur".
    readonly property var conversion: /^\s*[-+]?\d[\d.,]*\s*\S.*?\s+(?:to|in|→)\s+\S+\s*$/i

    // What a search would have qalc work out, or "" when it is not one
    // for the calculator. qalc takes "in" as inches, so a conversion's
    // "in" is spelled the way qalc means it.
    function expressionFor(query: string): string {
        const trimmed = (query ?? "").trim();

        if (forced(trimmed))
            return trimmed.slice(prefix.length).trim();
        if (arithmetic.test(trimmed))
            return trimmed;
        if (conversion.test(trimmed))
            return trimmed.replace(/\s+in\s+(\S+)\s*$/i, " to $1");

        return "";
    }

    // Asks qalc about a search, or forgets the last answer when the
    // search is not one for it.
    function evaluate(query: string): void {
        const next = available ? expressionFor(query) : "";
        wanted = next.length > 0;
        if (!wanted) {
            pending = "";
            expression = "";
            result = "";
            return;
        }

        pending = next;
        if (!calc.running)
            start();
    }

    // Whether the search is still one for the calculator, so an answer
    // that lands after it stopped being is dropped rather than shown.
    property bool wanted: false

    // Asked for while qalc was still on the last one: run once that is
    // done, rather than killing it and reading a half-written answer.
    property string pending: ""

    function start(): void {
        if (pending.length === 0)
            return;

        // qalc follows the locale's decimal separator, so with a comma
        // locale "1.5" reads as fifteen. A dot between digits is never
        // meant as grouping in a launcher, so it is read as a point.
        const dot = /\d\.\d/.test(pending);

        calc.asked = pending;
        calc.command = ["qalc", "-t", "-m", "1000", "-s", "conv 0", ...(dot ? ["-s", "decimal comma 0"] : []), pending];
        pending = "";
        calc.running = true;
    }

    // An answer worth showing says something the search did not: "2048"
    // and "90 min" come back as they went in, and "1/0" as "1 / 0".
    function worthShowing(asked: string, answer: string): bool {
        if (answer.length === 0 || /^(error|warning):/i.test(answer))
            return false;

        const squash = s => s.replace(/\s+/g, "");
        return squash(answer) !== squash(asked);
    }

    // Straight to wl-copy, as the clipboard panel's copies are.
    function copy(): void {
        if (result.length > 0)
            Quickshell.execDetached(["wl-copy", "--", result]);
    }

    Process {
        running: true

        command: ["qalc", "-v"]

        onExited: code => {
            root.available = code === 0;
            if (!root.available)
                console.warn("calc: qalc is not installed; the launcher's calculator is off.");
        }
    }

    Process {
        id: calc

        property string asked

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.wanted)
                    return;

                const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                const answer = lines[lines.length - 1] ?? "";

                root.expression = calc.asked;
                root.result = root.worthShowing(calc.asked, answer) ? answer : "";
            }
        }

        onExited: root.start()
    }
}

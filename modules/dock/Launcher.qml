import QtQuick
import Quickshell
import qs.config
import qs.modules.dock.components
import qs.services.launcher

// What the dock grows into to start something: a search over everything
// installed. Lives inside the dock's own shape rather than in a window
// of its own, so opening it is the dock changing form.
//
// A search starting with ":" is for the shell's own commands instead,
// and a bare colon lists them all. Typing the whole name of one that
// opens another panel -- ":cliphist" -- goes straight there.
//
// A search that reads as maths or a unit conversion gets its answer as
// the top result, over whatever applications it also finds, and one
// starting with "=" is for the calculator alone.
SearchPanel {
    id: root

    // Asks the dock to turn into another of its panels.
    signal panelRequested(string panel)

    readonly property bool commandMode: Commands.matches(query)
    readonly property bool calcMode: !commandMode && Calc.forced(query)
    readonly property bool hasAnswer: !commandMode && Calc.result.length > 0

    function run(entry: DesktopEntry): void {
        if (!entry)
            return;

        Apps.launch(entry);
        root.dismissed();
    }

    function copyAnswer(): void {
        Calc.copy();
        root.dismissed();
    }

    // Put away before the command runs, so the dock is already on its
    // way down when the lock or the screenshot picker comes up.
    function runCommand(command: var): void {
        if (!command)
            return;

        if (command.panel) {
            root.panelRequested(command.panel);
            return;
        }

        root.dismissed();
        command.run();
    }

    results: {
        if (commandMode)
            return Commands.search(query);

        const answer = hasAnswer ? [Calc.row] : [];
        return calcMode ? answer : [...answer, ...Apps.search(query)];
    }
    placeholder: Calc.available ? qsTr("Search, : or =") : qsTr("Search, or :")
    emptyText: commandMode ? qsTr("No commands match") : calcMode ? qsTr("Nothing to work out") : qsTr("No applications match")

    delegate: commandMode ? commandResult : appResult

    // Typing the colon swaps the list over to the commands, and the
    // field's glyph with it, rather than sorting one into the other.
    kind: commandMode ? "commands" : calcMode ? "calc" : "apps"
    icon: commandMode ? "terminal" : calcMode ? "calculate" : "search"

    onAccepted: result => {
        if (commandMode)
            runCommand(result);
        else if (result === Calc.row)
            copyAnswer();
        else
            run(result);
    }

    // So a launcher opening again never shows the last answer for the
    // frame before its emptied search reaches the calculator.
    onActiveChanged: if (!active)
        Calc.evaluate("")

    // Only a panel is opened on the name alone. Anything that acts waits
    // for Enter, so ":lock" is never run halfway through ":lockscreen".
    //
    // A beat later rather than on the spot: the query also changes while
    // the dock is still opening the launcher, and switching panels from
    // inside that change would loop back into it.
    onQueryChanged: Qt.callLater(() => {
        Calc.evaluate(root.active && !root.commandMode ? root.query : "");

        const command = root.active ? Commands.exact(root.query) : null;
        if (command?.panel)
            root.panelRequested(command.panel);
    })

    // An application, or the calculator's answer heading them.
    Component {
        id: appResult

        Item {
            id: result

            required property int index
            required property var modelData

            width: ListView.view.width
            implicitHeight: Config.dock.resultHeight

            Loader {
                anchors.fill: parent

                sourceComponent: result.modelData === Calc.row ? calcRow : appRow
            }

            Component {
                id: appRow

                AppResult {
                    index: result.index
                    modelData: result.modelData
                    width: result.width

                    onPointed: root.currentIndex = result.index
                    onActivated: root.run(result.modelData)
                }
            }

            Component {
                id: calcRow

                CalcResult {
                    width: result.width

                    onPointed: root.currentIndex = result.index
                    onActivated: root.copyAnswer()
                }
            }
        }
    }

    Component {
        id: commandResult

        CommandResult {
            onPointed: root.currentIndex = index
            onActivated: root.runCommand(modelData)
        }
    }
}

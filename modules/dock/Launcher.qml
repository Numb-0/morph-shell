import QtQuick
import Quickshell
import qs.config
import qs.modules.dock.components
import qs.services

// What the dock grows into to start something: a search over everything
// installed. Lives inside the dock's own shape rather than in a window
// of its own, so opening it is the dock changing form.
//
// A search starting with ":" is for the shell's own commands instead,
// and a bare colon lists them all. Typing the whole name of one that
// opens another panel -- ":cliphist" -- goes straight there.
SearchPanel {
    id: root

    // Asks the dock to turn into another of its panels.
    signal panelRequested(string panel)

    readonly property bool commandMode: Commands.matches(query)

    function run(entry: DesktopEntry): void {
        if (!entry)
            return;

        Apps.launch(entry);
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

    results: commandMode ? Commands.search(query) : Apps.search(query)
    placeholder: qsTr("Search applications, or : for commands")
    emptyText: commandMode ? qsTr("No commands match") : qsTr("No applications match")

    delegate: commandMode ? commandResult : appResult

    onAccepted: result => commandMode ? runCommand(result) : run(result)

    // Only a panel is opened on the name alone. Anything that acts waits
    // for Enter, so ":lock" is never run halfway through ":lockscreen".
    //
    // A beat later rather than on the spot: the query also changes while
    // the dock is still opening the launcher, and switching panels from
    // inside that change would loop back into it.
    onQueryChanged: Qt.callLater(() => {
        const command = root.active ? Commands.exact(root.query) : null;
        if (command?.panel)
            root.panelRequested(command.panel);
    })

    Component {
        id: appResult

        AppResult {
            onPointed: root.currentIndex = index
            onActivated: root.run(modelData)
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

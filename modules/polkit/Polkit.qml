pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.components
import qs.config

// The polkit agent, standing in for hyprpolkitagent. Quickshell does the
// talking to polkitd; this only puts the request in front of you: every
// screen dims, and the dialog comes up on the one you were working on.
//
// Requests queue in the agent and come through one at a time, so there
// is only ever one flow to show. A wrong password starts the agent on a
// fresh attempt by itself; the flow only goes away once the request has
// succeeded or been cancelled, by you or by polkitd.
//
// Only one agent can hold the session. The agent hands its registration
// on across a shell reload rather than dropping it, but if another agent
// got there first this one stays unregistered (Quickshell logs it) --
// turn the other off.
Scope {
    id: root

    // The screen the dialog and the keyboard go to, chosen once when a
    // request comes in rather than following focus around.
    property string keyScreen: ""

    // The request on show. Follows the agent onto each new one, but not
    // back to null when the last is done: the agent lets go of the flow
    // a moment before the windows are unloaded, and the dialog would
    // spend that moment reading from nothing.
    property AuthFlow flow: null

    // Set by the right password, and held a moment after the agent has
    // moved on so the dialog can show the tick before it goes.
    property bool succeeded: false

    // The last stretch of that moment, as the dim and the card fade.
    property bool leaving: false

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: root.keyScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

        onFlowChanged: if (flow) {
            root.flow = flow;
            root.succeeded = false;
            root.leaving = false;
            linger.stop();
            fadeOut.stop();
        }
    }

    // Caught as the flow says so, which is before the agent lets it go:
    // isActive drops in the same breath, so the windows are kept up by
    // this and the held flow instead.
    Connections {
        target: root.flow

        function onAuthenticationSucceeded(): void {
            root.succeeded = true;
            linger.restart();
            fadeOut.restart();
        }
    }

    Timer {
        id: linger

        interval: 550
        onTriggered: {
            root.succeeded = false;
            root.leaving = false;
        }
    }

    // Matches the card's own exit in Dialog.
    Timer {
        id: fadeOut

        interval: 300
        onTriggered: root.leaving = true
    }

    LazyLoader {
        active: root.flow !== null || root.succeeded

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property ShellScreen modelData

                readonly property bool main: modelData.name === root.keyScreen

                screen: modelData
                color: "transparent"

                // Over everything, the bar and notifications included,
                // and reserving nothing. Only the dialog's screen takes
                // the keyboard, so typing cannot wander off to another.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "morph-shell-polkit"
                WlrLayershell.keyboardFocus: main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Rectangle {
                    id: scrim

                    anchors.fill: parent

                    color: {
                        const c = Appearance.palette.m3scrim;
                        return Qt.rgba(c.r, c.g, c.b, 0.45);
                    }

                    opacity: 0
                    Component.onCompleted: opacity = 1

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Connections {
                        target: root

                        function onLeavingChanged(): void {
                            if (root.leaving)
                                scrim.opacity = 0;
                        }
                    }
                }

                // Swallows clicks on the dim, so nothing under it can be
                // reached while the request is waiting on an answer.
                MouseArea {
                    anchors.fill: parent
                }

                Loader {
                    anchors.centerIn: parent

                    active: win.main

                    sourceComponent: Dialog {
                        flow: root.flow
                        succeeded: root.succeeded
                    }
                }
            }
        }
    }
}

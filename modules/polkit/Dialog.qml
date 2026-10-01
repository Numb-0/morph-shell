pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Polkit
import qs.components
import qs.config

// The card a polkit request is answered on: what is asking, who you are
// authenticating as, and the password field.
//
// The field only takes input while PAM is waiting on it. Between a
// submit and the answer it greys out, and a wrong password shakes the
// card and hands the field back empty for another go.
Rectangle {
    id: root

    required property AuthFlow flow

    // The right password went in: the shield turns to a tick and the
    // card goes. The agent has let the flow go by then, so for these
    // last moments flow is null and the card shows what it last had.
    property bool succeeded: false

    property string message: ""
    property string identityName: ""
    property bool identityIsGroup: false

    function remember(): void {
        if (!flow)
            return;
        message = flow.message;
        identityName = flow.selectedIdentity?.displayName ?? "";
        identityIsGroup = flow.selectedIdentity?.isGroup ?? false;
    }

    onFlowChanged: remember()

    // The prompt PAM sends ends in a colon, there to sit before a
    // terminal's cursor. As a placeholder it reads better without.
    readonly property string prompt: (flow?.inputPrompt || qsTr("Password")).replace(/:\s*$/, "")

    readonly property bool busy: !flow?.isResponseRequired

    // Set by a failed attempt, and cleared by typing so the warning does
    // not hang around over the next try.
    property bool wrong: false

    function submit(): void {
        if (busy || !flow)
            return;
        flow.submit(password.text);
        password.text = "";
    }

    function cancel(): void {
        flow?.cancelAuthenticationRequest();
    }

    // Steps through who may answer, for requests more than one user (or
    // an admin group) can authorise. Changing it starts a fresh attempt.
    function nextIdentity(): void {
        const ids = flow?.identities ?? [];
        if (ids.length < 2)
            return;
        flow.selectedIdentity = ids[(ids.indexOf(flow.selectedIdentity) + 1) % ids.length];
        remember();
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            root.wrong = true;
            shake.restart();
        }

        function onIsResponseRequiredChanged(): void {
            if (root.flow?.isResponseRequired)
                password.forceActiveFocus();
        }
    }

    implicitWidth: 400
    implicitHeight: column.implicitHeight + Appearance.padding.extraLarge * 2

    radius: Appearance.rounding.extraLarge
    color: Appearance.palette.m3surfaceContainer

    // Rises into place as the dim comes up, and once the tick has had
    // its moment, shrinks away again.
    opacity: 0
    scale: 0.9
    Component.onCompleted: {
        remember();
        opacity = 1;
        scale = 1;
        password.forceActiveFocus();
    }

    onSucceededChanged: if (succeeded) {
        tick.restart();
        leave.restart();
    }

    Timer {
        id: leave

        interval: 300
        onTriggered: {
            root.opacity = 0;
            root.scale = 0.95;
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    // Side to side and back to rest, the way a login screen says no.
    SequentialAnimation {
        id: shake

        readonly property int step: 50

        NumberAnimation {
            target: column
            property: "anchors.horizontalCenterOffset"
            to: 10
            duration: shake.step
        }
        NumberAnimation {
            target: column
            property: "anchors.horizontalCenterOffset"
            to: -10
            duration: shake.step
        }
        NumberAnimation {
            target: column
            property: "anchors.horizontalCenterOffset"
            to: 6
            duration: shake.step
        }
        NumberAnimation {
            target: column
            property: "anchors.horizontalCenterOffset"
            to: 0
            duration: shake.step
        }
    }

    ColumnLayout {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Appearance.padding.extraLarge * 2

        spacing: Appearance.spacing.medium

        Rectangle {
            id: badge

            Layout.alignment: Qt.AlignHCenter

            implicitWidth: 56
            implicitHeight: 56
            radius: height / 2
            color: root.succeeded ? Appearance.palette.m3primary : Appearance.palette.m3primaryContainer

            Behavior on color {
                CAnim {
                    duration: Appearance.anim.durations.fastEffects
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent

                icon: root.succeeded ? "check" : "shield_lock"
                size: Appearance.font.icon.large
                weight: root.succeeded ? 600 : 400
                color: root.succeeded ? Appearance.palette.m3onPrimary : Appearance.palette.m3onPrimaryContainer
                fill: 1
            }

            // A quick pop as the shield turns to a tick.
            SequentialAnimation {
                id: tick

                Anim {
                    target: badge
                    property: "scale"
                    to: 1.2
                    type: Anim.FastEffects
                }
                Anim {
                    target: badge
                    property: "scale"
                    to: 1
                    type: Anim.FastSpatial
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            text: qsTr("Authentication required")
            font.pixelSize: Appearance.font.large
        }

        StyledText {
            Layout.fillWidth: true

            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.message
            font.pixelSize: Appearance.font.normal
            color: Appearance.palette.m3onSurfaceVariant
        }

        // Who the password is for. A chip you can click through when
        // there is more than one to choose from.
        Rectangle {
            id: identity

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.spacing.small

            readonly property bool choosable: (root.flow?.identities.length ?? 0) > 1

            implicitWidth: identityRow.implicitWidth + Appearance.padding.medium * 2
            implicitHeight: identityRow.implicitHeight + Appearance.padding.extraSmall * 2

            radius: height / 2
            color: Appearance.palette.m3secondaryContainer

            RowLayout {
                id: identityRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.extraSmall

                MaterialSymbol {
                    icon: root.identityIsGroup ? "group" : "person"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3onSecondaryContainer
                }

                StyledText {
                    text: root.identityName
                    color: Appearance.palette.m3onSecondaryContainer
                }

                MaterialSymbol {
                    visible: identity.choosable
                    icon: "unfold_more"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3onSecondaryContainer
                }
            }

            HoverHandler {
                enabled: identity.choosable
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: identity.choosable
                onTapped: root.nextIdentity()
            }
        }

        // The field, a plain TextInput as the launcher's is.
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small

            implicitHeight: 48

            radius: height / 2
            color: Appearance.palette.m3surfaceContainerHighest
            border.width: root.wrong ? 2 : password.activeFocus ? 2 : 0
            border.color: root.wrong ? Appearance.palette.m3error : Appearance.palette.m3primary
            opacity: root.busy ? 0.6 : 1

            Behavior on border.color {
                CAnim {}
            }

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.large
                spacing: Appearance.spacing.small

                MaterialSymbol {
                    icon: "key"
                    size: Appearance.font.icon.normal
                    color: Appearance.palette.m3onSurfaceVariant
                }

                TextInput {
                    id: password

                    Layout.fillWidth: true

                    enabled: !root.busy
                    echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"

                    color: Appearance.palette.m3onSurface
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.normal

                    renderType: TextInput.NativeRendering
                    selectionColor: Appearance.palette.m3primary
                    selectedTextColor: Appearance.palette.m3onPrimary

                    onTextChanged: if (text.length > 0)
                        root.wrong = false

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: root.cancel()

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: password.text.length === 0

                        text: root.succeeded ? "" : root.busy ? qsTr("Checking…") : root.prompt
                        font.pixelSize: Appearance.font.normal
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        // What PAM has to add -- a fingerprint reader's prompt, an
        // account about to expire -- or the warning after a wrong try.
        StyledText {
            Layout.fillWidth: true

            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            text: root.flow?.supplementaryMessage || (root.wrong ? qsTr("Wrong password, try again") : "")
            color: root.wrong || root.flow?.supplementaryIsError ? Appearance.palette.m3error : Appearance.palette.m3onSurfaceVariant
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Appearance.spacing.small

            spacing: Appearance.spacing.small

            TextButton {
                label: qsTr("Cancel")
                onClicked: root.cancel()
            }

            TextButton {
                label: qsTr("Authenticate")
                filled: true
                enabled: !root.busy
                onClicked: root.submit()
            }
        }
    }

    // An M3 common button: filled for the action, text-only beside it.
    component TextButton: Rectangle {
        id: btn

        required property string label
        property bool filled: false

        signal clicked

        readonly property color content: filled ? Appearance.palette.m3onPrimary : Appearance.palette.m3primary

        implicitWidth: btnLabel.implicitWidth + Appearance.padding.large * 2
        implicitHeight: 40

        radius: btnHover.hovered ? Appearance.rounding.medium : height / 2
        color: filled ? Appearance.palette.m3primary : "transparent"
        opacity: enabled ? 1 : 0.5

        Behavior on radius {
            Anim {
                type: Anim.FastSpatial
            }
        }

        // The M3 state layer.
        Rectangle {
            anchors.fill: parent

            radius: parent.radius
            color: btn.content
            opacity: btnTap.pressed ? 0.16 : btnHover.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        StyledText {
            id: btnLabel

            anchors.centerIn: parent

            text: btn.label
            font.pixelSize: Appearance.font.normal
            color: btn.content
        }

        HoverHandler {
            id: btnHover

            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: btnTap

            enabled: btn.enabled
            onTapped: btn.clicked()
        }
    }
}

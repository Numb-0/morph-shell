pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// One screen of the lock: the wallpaper, the time in the top left and
// the password field just under the middle, laid out as hyprlock had
// them.
//
// The wallpaper is the same one the background draws, and the lock comes
// and goes over it: it dims and the clock and field rise in on the way
// in, and on the way out, after the tick, they fade and the dim lifts
// before the session is let go, so the desktop comes back under an
// unchanged picture.
WlSessionLockSurface {
    id: root

    required property Lock lock

    color: Appearance.palette.m3surface

    // Decoded before the first frame, not after: the compositor shows a
    // lock surface the moment it has one, and an async load would flash
    // plain surface first.
    Image {
        anchors.fill: parent

        source: Appearance.wallpaper ? `file://${Appearance.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false

        sourceSize.width: root.width * (root.screen?.devicePixelRatio ?? 1)
        sourceSize.height: root.height * (root.screen?.devicePixelRatio ?? 1)
    }

    Rectangle {
        anchors.fill: parent

        color: {
            const c = Appearance.palette.m3scrim;
            return Qt.rgba(c.r, c.g, c.b, 0.3);
        }

        opacity: content.shown ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    // The pointer is hidden, as hyprlock hid it; there is nothing here
    // to point at.
    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.BlankCursor
    }

    Item {
        id: content

        anchors.fill: parent

        // Up from the first frame, and down again once the password is
        // in, while the session is still locked.
        property bool shown: false
        Component.onCompleted: {
            shown = Qt.binding(() => !root.lock.leaving);
            forceActiveFocus();
        }

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.96

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Takes the keys for this screen. Every screen writes into the
        // lock's one buffer, so whichever has the keyboard, the field on
        // each shows the same.
        focus: true
        Keys.onPressed: event => {
            event.accepted = true;
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.lock.submit();
                return;
            case Qt.Key_Backspace:
                root.lock.erase(!!(event.modifiers & Qt.ControlModifier));
                return;
            case Qt.Key_Escape:
                root.lock.erase(true);
                return;
            }
            // Printable text only: no control characters, and no Ctrl
            // shortcuts typing their letter into the password.
            const text = event.text;
            if (text.length > 0 && text.charCodeAt(0) >= 0x20 && text !== "\x7f" && !(event.modifiers & Qt.ControlModifier))
                root.lock.type(text);
        }

        Column {
            x: 200
            y: 200

            spacing: -Appearance.spacing.small

            StyledText {
                text: Time.format("HH:mm")
                font.pixelSize: 120
                color: Appearance.palette.m3primaryFixed
            }

            StyledText {
                leftPadding: Appearance.padding.small
                text: Time.format("dddd d MMMM")
                font.pixelSize: Appearance.font.large
                color: Appearance.palette.m3primaryFixedDim
            }
        }

        // The field. It grows as the dots outrun it, shakes on a wrong
        // password and turns to a tick on the right one.
        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 120

            readonly property color content: root.lock.unlocking ? Appearance.palette.m3onSuccess : root.lock.wrong ? Appearance.palette.m3onError : Appearance.palette.m3onTertiary

            implicitWidth: Math.max(200, dots.implicitWidth + Appearance.padding.extraLarge * 2)
            implicitHeight: 60

            radius: height / 2
            color: root.lock.unlocking ? Appearance.palette.m3success : root.lock.wrong ? Appearance.palette.m3error : Appearance.palette.m3tertiary

            Behavior on implicitWidth {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on color {
                CAnim {
                    duration: Appearance.anim.durations.fastEffects
                }
            }

            Connections {
                target: root.lock

                function onFailed(): void {
                    shake.restart();
                }
            }

            // Side to side and back to rest, as the polkit dialog says no.
            SequentialAnimation {
                id: shake

                readonly property int step: 50

                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: 12
                    duration: shake.step
                }
                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: -12
                    duration: shake.step
                }
                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: 7
                    duration: shake.step
                }
                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: 0
                    duration: shake.step
                }
            }

            // One dot per character, each popping in on its own. A list
            // model rather than a count, so a keystroke adds one dot
            // instead of rebuilding the row.
            ListModel {
                id: dotModel
            }

            Connections {
                target: root.lock

                function onBufferChanged(): void {
                    const n = root.lock.buffer.length;
                    if (n === 0)
                        dotModel.clear();
                    while (dotModel.count < n)
                        dotModel.append({});
                    while (dotModel.count > n)
                        dotModel.remove(dotModel.count - 1);
                }
            }

            Row {
                id: dots

                anchors.centerIn: parent

                spacing: Appearance.spacing.small
                opacity: root.lock.unlocking ? 0 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Repeater {
                    model: dotModel

                    Rectangle {
                        id: dot

                        required property int index

                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: field.content

                        scale: 0
                        Component.onCompleted: scale = 1

                        Behavior on scale {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }

                        // A wave along the dots while PAM is checking.
                        SequentialAnimation on opacity {
                            running: root.lock.checking
                            loops: Animation.Infinite
                            alwaysRunToEnd: true

                            // index is -1 for a moment as the delegate is made.
                            PauseAnimation {
                                duration: Math.max(0, dot.index) * 60
                            }
                            Anim {
                                to: 0.35
                                type: Anim.DefaultEffects
                            }
                            Anim {
                                to: 1
                                type: Anim.DefaultEffects
                            }
                        }
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent

                icon: "check"
                size: Appearance.font.icon.large
                weight: 600
                color: field.content

                opacity: root.lock.unlocking ? 1 : 0
                scale: root.lock.unlocking ? 1 : 0.5

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }
            }
        }

        // Under the field: the warning after a wrong try, or what PAM had
        // to add.
        StyledText {
            anchors.horizontalCenter: field.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: Appearance.spacing.medium

            text: root.lock.message || (root.lock.wrong ? qsTr("Wrong password, try again") : "")
            font.pixelSize: Appearance.font.normal
            color: Appearance.palette.m3error
        }
    }
}

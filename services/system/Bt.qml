pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth, as the bar wants it: the adapter's radio, the devices it
// knows or can see, and which of them are connected.
//
// Built on Quickshell's own Bluetooth module, which talks to BlueZ over
// D-Bus, as caelestia and end-4 both do. The panel follows the network
// one here rather than caelestia's list of switches.
//
// Named Bt rather than Bluetooth, so it does not shadow the module's
// own singleton, as Net does not shadow Network.
Singleton {
    id: root

    // Usually the only one. Null on a machine without an adapter, or
    // without bluetoothd running -- the bar widget then hides itself.
    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false

    // rfkill holding the radio off, which no toggle here can undo.
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked

    readonly property bool discovering: adapter?.discovering ?? false

    // Connected first, then paired, then by name. A device nobody has
    // paired shows up only while discovering, and one that has not told
    // us its name -- most of what discovery turns up is some stranger's
    // earbuds or a BLE beacon -- is left out, since its address alone
    // gives nothing to go on.
    readonly property list<var> devices: adapter ? [...adapter.devices.values].filter(d => d.paired || d.connected || d.deviceName !== "").sort((a, b) => b.connected - a.connected || b.paired - a.paired || a.name.localeCompare(b.name)) : []

    readonly property list<var> connectedDevices: devices.filter(d => d.connected)

    readonly property bool connected: connectedDevices.length > 0

    // How many open panels want discovery running. A count rather than
    // a flag, as the network scanner's is: every screen has its own bar.
    property int scanRequests: 0

    // Whether the discovery going on is ours. Another client -- blueman,
    // bluetoothctl -- may be scanning too, and closing the panel must
    // not stop theirs.
    property bool ownDiscovery: false

    readonly property string icon: {
        if (!enabled)
            return "bluetooth_disabled";
        if (connected)
            return "bluetooth_connected";
        return "bluetooth";
    }

    // BlueZ gives a freedesktop icon name for the device's class; the
    // same matches caelestia and end-4 make, in the same order, since
    // "audio-headset" has to win over "audio".
    function deviceIcon(device: var): string {
        const name = device?.icon ?? "";
        if (name.includes("headset") || name.includes("headphones"))
            return "headphones";
        if (name.includes("audio"))
            return "speaker";
        if (name.includes("phone"))
            return "smartphone";
        if (name.includes("mouse"))
            return "mouse";
        if (name.includes("keyboard"))
            return "keyboard";
        if (name.includes("gaming") || name.includes("joystick"))
            return "stadia_controller";
        if (name.includes("computer"))
            return "computer";
        return "bluetooth";
    }

    function busy(device: var): bool {
        const s = device?.state;
        return !!device?.pairing || s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting;
    }

    function setEnabled(enabled: bool): void {
        if (adapter && !blocked)
            adapter.enabled = enabled;
    }

    function watch(watching: bool): void {
        scanRequests = Math.max(0, scanRequests + (watching ? 1 : -1));
    }

    // One click does what it takes: a stranger is paired first and
    // connected once that goes through, the way a phone's list works.
    // It is also trusted, so it can reconnect by itself next time.
    function toggle(device: var): void {
        if (!device || busy(device))
            return;

        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            pending.device = device;
            device.pair();
        }
    }

    function forget(device: var): void {
        device?.forget();
    }

    function updateDiscovery(): void {
        if (!adapter)
            return;

        const want = scanRequests > 0 && enabled;
        if (want && !adapter.discovering) {
            adapter.discovering = true;
            ownDiscovery = true;
        } else if (!want && ownDiscovery) {
            // Powering off has already stopped it; asking again would
            // only get an error back.
            if (adapter.discovering)
                adapter.discovering = false;
            ownDiscovery = false;
        }
    }

    onScanRequestsChanged: updateDiscovery()
    onEnabledChanged: updateDiscovery()
    onAdapterChanged: {
        ownDiscovery = false;
        updateDiscovery();
    }

    // The device just asked to pair, so that finishing pairing can go
    // on to connect it. A pairing that fails is only logged by the
    // module, so this can outlive one; all that costs is a connect if
    // the same device gets paired some other way.
    QtObject {
        id: pending

        property var device: null
    }

    Instantiator {
        model: root.adapter?.devices ?? null

        delegate: Connections {
            required property var modelData

            target: modelData

            function onPairedChanged(): void {
                if (!modelData.paired || pending.device !== modelData)
                    return;

                pending.device = null;
                modelData.trusted = true;
                modelData.connect();
            }
        }
    }
}

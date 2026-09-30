pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// The network, as the bar wants it: the Wi-Fi radio, what is in range,
// what is joined, and a wired link if there is one.
//
// Built on Quickshell's own Networking module, which talks to
// NetworkManager over D-Bus, so every change arrives as it happens
// rather than being polled for and parsed out of nmcli. caelestia and
// end-4 both drive nmcli instead; the panel is laid out after
// caelestia's, but none of that plumbing is needed here.
//
// Named Net rather than Network so the bar widget can have that name,
// and so neither shadows the module's own Network type.
Singleton {
    id: root

    readonly property list<var> devices: Networking.devices.values

    // The first Wi-Fi device NetworkManager manages, or null on a
    // machine without one -- the panel then shows only the wired link.
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.nmManaged) ?? null

    // A wired device with a live connection, or null. Unmanaged devices
    // -- a container's veth, a bridge -- are not the machine's own link,
    // and would otherwise read as a cable plugged in.
    readonly property var ethernet: devices.find(d => d.type === DeviceType.Wired && d.nmManaged && d.connected) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled

    // A hardware switch or a BIOS setting holding the radio off, which
    // no toggle here can undo.
    readonly property bool wifiBlocked: !Networking.wifiHardwareEnabled

    // Joined first, then by signal. Networks nobody has joined only
    // appear while the scanner is running; with the panel shut, this is
    // just the joined and saved ones.
    readonly property list<var> networks: wifi ? [...wifi.networks.values].sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength) : []

    readonly property var active: networks.find(n => n.connected) ?? null

    // The network that turned out to need a password, for the panel's
    // password field. Null the rest of the time.
    property var passwordNetwork: null

    // The last thing that went wrong, and the network it went wrong on,
    // so the panel can say it on that network's row.
    property string error: ""
    property var errorNetwork: null

    function clearError(): void {
        error = "";
        errorNetwork = null;
    }

    // A network being joined for the first time. NetworkManager saves a
    // profile for it the moment it is tried, before any password, so a
    // try that never connects would leave it listed as saved. Held here
    // until it connects, and its profile forgotten if it never does.
    property var trial: null

    function dropTrial(): void {
        if (trial && !trial.connected)
            trial.forget();
        trial = null;
    }

    // How many open panels want the list of what is in range. A count
    // rather than a flag: every screen has its own bar, and one panel
    // closing must not stop the scan another is showing.
    property int scanRequests: 0

    readonly property bool connected: ethernet !== null || active !== null

    readonly property string icon: {
        if (ethernet)
            return "lan";
        if (!wifiEnabled || !wifi)
            return "wifi_off";
        if (!active)
            return "signal_wifi_0_bar";
        return strengthIcon(active.signalStrength);
    }

    // Five steps, as caelestia's are, over the module's 0..1 strength.
    function strengthIcon(strength: real): string {
        const icons = ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "network_wifi"];
        return icons[Math.max(0, Math.min(4, Math.floor(strength * 5)))];
    }

    // Only these take a pre-shared key; anything else -- enterprise,
    // WEP, LEAP -- wants more than one field can ask for.
    function takesPassword(network: var): bool {
        const s = network?.security;
        return s === WifiSecurityType.WpaPsk || s === WifiSecurityType.Wpa2Psk || s === WifiSecurityType.Sae;
    }

    function isSecure(network: var): bool {
        const s = network?.security;
        return s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe;
    }

    function setWifiEnabled(enabled: bool): void {
        Networking.wifiEnabled = enabled;
    }

    function watch(watching: bool): void {
        scanRequests = Math.max(0, scanRequests + (watching ? 1 : -1));
    }

    // Tried without a password first, as the module suggests: a saved
    // network comes up on its stored key, and the field only opens once
    // NetworkManager actually asks for one.
    function connectTo(network: var): void {
        if (!network || network.connected || network.stateChanging)
            return;

        clearError();
        passwordNetwork = null;
        dropTrial();
        if (!network.known)
            trial = network;
        network.connect();
    }

    function connectWithPassword(network: var, password: string): void {
        if (!network || password.length === 0)
            return;

        clearError();
        passwordNetwork = null;
        pending.network = network;
        network.connectWithPsk(password);
    }

    function cancelPassword(): void {
        if (passwordNetwork !== null && passwordNetwork === trial)
            dropTrial();
        if (passwordNetwork !== null && passwordNetwork === errorNetwork)
            clearError();
        passwordNetwork = null;
    }

    function disconnectWifi(): void {
        active?.disconnect();
    }

    // The scanner runs only while a panel is looking. It rescans on its
    // own timer as long as it is on, so there is no "rescan now" to
    // offer -- and nothing to keep the radio busy once the panel shuts.
    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.scanRequests > 0 && root.wifiEnabled
    }

    // Which network was just given a password, so a NoSecrets from it
    // reads as the key being wrong rather than as one being missing.
    QtObject {
        id: pending

        property var network: null
    }

    // One listener per network, since the failure is signalled on the
    // network itself rather than on the device.
    Instantiator {
        model: root.wifi?.networks ?? null

        delegate: Connections {
            required property var modelData

            target: modelData

            function onConnectionFailed(reason: int): void {
                const retried = pending.network === modelData;
                pending.network = null;

                const wantsPassword = reason === ConnectionFailReason.NoSecrets && root.takesPassword(modelData);

                root.errorNetwork = modelData;
                if (wantsPassword)
                    root.error = retried ? qsTr("Wrong password") : "";
                else if (reason === ConnectionFailReason.NoSecrets)
                    root.error = qsTr("This network needs a full network manager to join");
                else
                    root.error = ConnectionFailReason.toString(reason);

                // Asked again for a password only while a panel is open to
                // take it. Otherwise nothing more will be asked of it, so a
                // first try ends here.
                if (wantsPassword && root.scanRequests > 0)
                    root.passwordNetwork = modelData;
                else if (root.trial === modelData)
                    root.dropTrial();
            }


            function onConnectedChanged(): void {
                if (!modelData.connected)
                    return;
                if (root.passwordNetwork === modelData)
                    root.passwordNetwork = null;
                // Joined, so its profile is really saved now.
                if (root.trial === modelData)
                    root.trial = null;
            }
        }
    }
}

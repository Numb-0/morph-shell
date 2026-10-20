import QtQuick

// The clock panel's weather, from Open-Meteo. Set in the user's
// config, under "weather"; these are the defaults.
QtObject {
    // The "weather" object of the user's config.
    property var user: ({})

    // A place to look up by its English name, "Florence" or
    // "Florence, IT", or a "latitude,longitude" pair. Empty asks
    // where the machine's address is, which only gets as close as
    // wherever the ISP registered it.
    readonly property string location: user.location ?? ""

    readonly property bool fahrenheit: user.fahrenheit ?? false

    // Minutes between fetches. Open-Meteo updates every 15.
    readonly property int refresh: Math.max(1, user.refresh ?? 15)
}

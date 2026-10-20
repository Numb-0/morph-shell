pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The weather where the machine is, for the clock panel: how it is now,
// and the days ahead.
//
// From Open-Meteo, which needs no key. Where "here" is comes from the
// config's location, looked up with Open-Meteo's own geocoder, or else
// from the machine's address -- which only gets as close as the ISP's
// nearest exchange, often the wrong city.
Singleton {
    id: root

    // Whether there is anything to show yet.
    readonly property bool ready: current !== null

    // The place the weather is for, as the geocoder or the address
    // lookup named it.
    property string place: ""

    // { temperature, feelsLike, code, isDay, humidity, wind }, or null
    // before the first fetch lands.
    property var current: null

    // A day each from today, as { date, code, max, min, rain }: `rain`
    // being the chance of any, in percent.
    property var days: []

    readonly property string unit: Appearance.weather.fahrenheit ? "°F" : "°C"
    readonly property string windUnit: Appearance.weather.fahrenheit ? "mph" : "km/h"

    // The last thing that went wrong, for the panel to say while it has
    // nothing better to show.
    property string error: ""

    property real latitude: NaN
    property real longitude: NaN

    property date fetched: new Date(0)

    // Counts the lookups of where "here" is, so one that answers after
    // the location has changed again is ignored rather than winning.
    property int lookups: 0

    function temperature(value: real): string {
        return `${Math.round(value)}°`;
    }

    // WMO weather codes, as Open-Meteo gives them, to a glyph and a word.
    function icon(code: int, day: bool): string {
        if (code === 0)
            return day ? "sunny" : "clear_night";
        if (code <= 2)
            return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3)
            return "cloud";
        if (code === 45 || code === 48)
            return "foggy";
        if (code >= 51 && code <= 57)
            return "rainy_light";
        if (code === 61 || code === 80)
            return "rainy_light";
        if (code === 63 || code === 81)
            return "rainy";
        if (code === 65 || code === 82)
            return "rainy_heavy";
        if (code === 66 || code === 67)
            return "weather_mix";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "weather_snowy";
        if (code >= 95)
            return "thunderstorm";
        return "cloud";
    }

    function describe(code: int): string {
        const words = {
            0: qsTr("Clear"),
            1: qsTr("Mostly clear"),
            2: qsTr("Partly cloudy"),
            3: qsTr("Overcast"),
            45: qsTr("Fog"),
            48: qsTr("Freezing fog"),
            51: qsTr("Light drizzle"),
            53: qsTr("Drizzle"),
            55: qsTr("Heavy drizzle"),
            56: qsTr("Freezing drizzle"),
            57: qsTr("Freezing drizzle"),
            61: qsTr("Light rain"),
            63: qsTr("Rain"),
            65: qsTr("Heavy rain"),
            66: qsTr("Freezing rain"),
            67: qsTr("Freezing rain"),
            71: qsTr("Light snow"),
            73: qsTr("Snow"),
            75: qsTr("Heavy snow"),
            77: qsTr("Snow grains"),
            80: qsTr("Light showers"),
            81: qsTr("Showers"),
            82: qsTr("Heavy showers"),
            85: qsTr("Snow showers"),
            86: qsTr("Heavy snow showers"),
            95: qsTr("Thunderstorm"),
            96: qsTr("Thunderstorm with hail"),
            99: qsTr("Thunderstorm with hail")
        };
        return words[code] ?? "";
    }

    function get(url: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status !== 200) {
                fail(qsTr("Weather unavailable"));
                return;
            }

            try {
                done(JSON.parse(xhr.responseText));
            } catch (e) {
                fail(qsTr("Weather unavailable"));
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // Tries again in a minute rather than waiting out the whole refresh:
    // a laptop waking up has no network for the first few seconds.
    function fail(message: string): void {
        error = message;
        retry.restart();
    }

    // Works out where "here" is, then fetches. Again whenever the
    // location in the config changes.
    function locate(): void {
        const wanted = Appearance.weather.location.trim();
        const asked = ++lookups;

        const pair = wanted.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/);
        if (pair) {
            latitude = Number(pair[1]);
            longitude = Number(pair[2]);
            place = "";
            fetch();
            return;
        }

        if (wanted.length > 0) {
            // "Firenze, IT": the geocoder takes the name alone, and the
            // country narrows its answers down after.
            const [name, country] = wanted.split(",").map(s => s.trim());
            get(`https://geocoding-api.open-meteo.com/v1/search?count=10&language=en&name=${encodeURIComponent(name)}`, data => {
                if (asked !== lookups)
                    return;

                const results = data.results ?? [];
                const found = results.find(r => !country || r.country_code?.toLowerCase() === country.toLowerCase()) ?? null;
                if (!found) {
                    fail(qsTr("Couldn't find %1").arg(wanted));
                    return;
                }
                latitude = found.latitude;
                longitude = found.longitude;
                place = found.name;
                fetch();
            });
            return;
        }

        get("https://ipapi.co/json/", data => {
            if (asked !== lookups)
                return;

            if (typeof data.latitude !== "number") {
                fail(qsTr("Couldn't tell where this is"));
                return;
            }
            latitude = data.latitude;
            longitude = data.longitude;
            place = data.city ?? "";
            fetch();
        });
    }

    function fetch(): void {
        if (isNaN(latitude) || isNaN(longitude)) {
            locate();
            return;
        }

        const units = Appearance.weather.fahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "";
        const url = "https://api.open-meteo.com/v1/forecast" + `?latitude=${latitude}&longitude=${longitude}` + "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" + `&forecast_days=5&timezone=auto${units}`;

        get(url, data => {
            const c = data.current;
            const d = data.daily;
            if (!c || !d) {
                fail(qsTr("Weather unavailable"));
                return;
            }

            current = {
                temperature: c.temperature_2m,
                feelsLike: c.apparent_temperature,
                code: c.weather_code,
                isDay: c.is_day === 1,
                humidity: c.relative_humidity_2m,
                wind: c.wind_speed_10m
            };

            // Dates come as "2026-10-19", which Date reads as UTC
            // midnight -- the evening before, west of Greenwich -- so
            // they are built from their parts instead.
            days = d.time.map((t, i) => {
                const [y, m, day] = t.split("-").map(Number);
                return {
                    date: new Date(y, m - 1, day),
                    code: d.weather_code[i],
                    max: d.temperature_2m_max[i],
                    min: d.temperature_2m_min[i],
                    rain: d.precipitation_probability_max[i] ?? 0
                };
            });

            error = "";
            fetched = new Date();
        });
    }

    // For the panel opening: a fetch if the last one is getting old, so
    // what it shows is never far behind even after a long sleep, when
    // the timer below has not caught up yet.
    function freshen(): void {
        if (Date.now() - fetched.getTime() > Appearance.weather.refresh * 60 * 1000 / 2)
            fetch();
    }

    Component.onCompleted: locate()

    // Edits to the user's config land while the shell runs: a new place
    // is looked up afresh, and new units fetched in.
    Connections {
        target: Appearance.weather

        function onLocationChanged(): void {
            root.latitude = NaN;
            root.longitude = NaN;
            root.locate();
        }

        function onFahrenheitChanged(): void {
            root.fetch();
        }
    }

    Timer {
        running: true
        repeat: true
        interval: Appearance.weather.refresh * 60 * 1000

        onTriggered: root.fetch()
    }

    Timer {
        id: retry

        interval: 60 * 1000
        onTriggered: root.fetch()
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import "jalali.js" as J

// The plugin's logic, no UI: the clock (refreshed every 30 s, so the day rolls
// over within half a minute of midnight) and the resolved settings. The view
// state (month on show, selected day) lives in the widget, like the built-in
// desktop calendar. Reads only the system clock; writes nothing.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    readonly property bool persianDigits: svc.flag("persianDigits", true)
    readonly property bool showWeekNumbers: svc.flag("showWeekNumbers", true)
    readonly property bool showGregorian: svc.flag("showGregorian", true)
    readonly property bool showHolidays: svc.flag("showHolidays", true)

    function flag(key, fallback) {
        return svc.settings && svc.settings[key] !== undefined ? svc.settings[key] === true : fallback;
    }

    property var now: new Date()
    readonly property var today: J.fromDate(svc.now)

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: svc.now = new Date()
    }
}

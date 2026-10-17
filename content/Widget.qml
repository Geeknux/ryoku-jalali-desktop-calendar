pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons
import "../service/jalali.js" as J

// A Jalali month calendar for the desktop, after Ryoku's built-in desktop
// calendar: month title and week eyebrow, prev / today / next, a Saturday-first
// six-week grid with week numbers, neighbouring-month days ghosted, the current
// week banded, today ringed, and a footer naming the hovered or selected day
// and its holiday. The whole face runs right-to-left through LayoutMirroring.
// The host draws the card/glass backing, drag, resize and the right-click menu.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 360

    // Host accent (manifest capabilities.colors): Auto / pinned / off.
    property color accentColor: Theme.accent
    property bool accentFromHost: false
    readonly property color accent: root.accentFromHost ? root.accentColor : Theme.accent

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool fa: service ? service.persianDigits : true
    readonly property bool showWeekNumbers: service ? service.showWeekNumbers : true
    readonly property bool showGregorian: service ? service.showGregorian : true
    readonly property bool showHolidays: service ? service.showHolidays : true
    readonly property var today: service ? service.today : J.fromDate(new Date())

    readonly property string faFont: "Vazirmatn"
    readonly property color ink: Theme.bright
    readonly property color inkDim: Theme.dim
    readonly property color faint: Qt.rgba(Theme.dim.r, Theme.dim.g, Theme.dim.b, 0.55)

    // View state.
    property int viewYear: J.fromDate(new Date()).jy
    property int viewMonth: J.fromDate(new Date()).jm
    property int selectedJdn: J.fromDate(new Date()).jdn
    property int hoveredJdn: 0
    readonly property int activeJdn: root.hoveredJdn > 0 ? root.hoveredJdn : root.selectedJdn
    readonly property int weeks: 6
    readonly property var days: J.buildRange(root.viewYear, root.viewMonth, root.today.jdn, root.weeks)
    readonly property int todayRow: {
        for (var i = 0; i < root.days.length; i++)
            if (root.days[i].today) return root.days[i].row;
        return -1;
    }

    readonly property real weekWidth: root.showWeekNumbers ? 28 * root.s : 0
    readonly property real cellWidth: 40 * root.s
    readonly property real cellHeight: 34 * root.s

    implicitWidth: root.weekWidth + root.cellWidth * 7
    implicitHeight: col.implicitHeight

    LayoutMirroring.enabled: true
    LayoutMirroring.childrenInherit: true

    function d(v) { return J.digits(v, root.fa); }

    function shift(delta) {
        if (delta === 0) {
            root.viewYear = root.today.jy;
            root.viewMonth = root.today.jm;
            root.selectedJdn = root.today.jdn;
        } else {
            var m = root.viewMonth - 1 + delta;
            root.viewYear = root.viewYear + Math.floor(m / 12);
            root.viewMonth = ((m % 12) + 12) % 12 + 1;
        }
        reveal.restart();
    }

    function pick(day) {
        root.selectedJdn = day.jdn;
        if (!day.inMonth) {
            root.viewYear = day.jy;
            root.viewMonth = day.jm;
            reveal.restart();
        }
    }

    // Follow the day over midnight when the view is on today.
    property int _lastToday: root.today.jdn
    onTodayChanged: {
        if (root.today.jdn === root._lastToday) return;
        var followed = root.selectedJdn === root._lastToday;
        root._lastToday = root.today.jdn;
        if (followed) root.shift(0);
        sweep.restart();
    }

    Column {
        id: col
        width: parent.width
        spacing: 8 * root.s

        // Header: title + eyebrow on the right, navigation on the left.
        Item {
            width: parent.width
            height: 46 * root.s

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s

                Text {
                    text: J.MONTHS[root.viewMonth - 1] + " " + root.d(root.viewYear)
                    color: root.ink
                    font.family: root.faFont
                    font.pixelSize: 23 * root.s
                    font.weight: Font.DemiBold
                }
                Row {
                    spacing: 8 * root.s
                    Text {
                        text: "هفته‌ی " + root.d(J.weekOfYear(root.today.jdn)) + " سال"
                        color: root.faint
                        font.family: root.faFont
                        font.pixelSize: 10 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showGregorian
                        text: J.gregorianSpan(root.viewYear, root.viewMonth).toUpperCase()
                        color: root.faint
                        font.family: Theme.mono
                        font.pixelSize: 9 * root.s
                        font.letterSpacing: 1.1 * root.s
                    }
                }
            }

            // Mirrored, so the model's first item sits rightmost: › (previous)
            // on the right, ‹ (next) on the left, as an RTL calendar reads.
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * root.s
                Repeater {
                    model: [
                        { label: "›", delta: -1, name: "ماه قبل" },
                        { label: "امروز", delta: 0, name: "برگشت به امروز" },
                        { label: "‹", delta: 1, name: "ماه بعد" }
                    ]
                    delegate: Rectangle {
                        id: nav
                        required property var modelData
                        width: nav.modelData.delta === 0 ? 48 * root.s : 28 * root.s
                        height: 28 * root.s
                        radius: 8 * root.s
                        color: navArea.containsMouse ? Theme.hair : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: nav.modelData.name
                        Text {
                            anchors.centerIn: parent
                            // LRM keeps the lone ‹ / › out of RTL bidi
                            // mirroring, which would flip them inward.
                            text: nav.modelData.delta === 0 ? nav.modelData.label : "\u200E" + nav.modelData.label
                            color: root.ink
                            font.family: nav.modelData.delta === 0 ? root.faFont : Theme.font
                            font.pixelSize: nav.modelData.delta === 0 ? 11 * root.s : 18 * root.s
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shift(nav.modelData.delta)
                        }
                    }
                }
            }
        }

        Item {
            id: grid
            width: parent.width
            height: weekdayRow.height + root.cellHeight * root.weeks
            property real pulse: 0

            // Weekday heads, Saturday rightmost, Friday in the accent.
            Row {
                id: weekdayRow
                anchors.left: parent.left
                anchors.leftMargin: root.weekWidth
                Repeater {
                    model: J.WEEKDAYS_SHORT
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: root.cellWidth
                        height: 22 * root.s
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: parent.index === 6 ? root.accent : root.faint
                            font.family: root.faFont
                            font.pixelSize: 10 * root.s
                        }
                    }
                }
            }

            Column {
                id: rows
                anchors.top: weekdayRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                    model: root.weeks
                    delegate: Item {
                        id: week
                        required property int index
                        width: rows.width
                        height: root.cellHeight

                        // Current-week band.
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: root.weekWidth
                            radius: 10 * root.s
                            visible: week.index === root.todayRow
                            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.035 + grid.pulse * 0.055)
                        }

                        Row {
                            anchors.fill: parent

                            Item {
                                width: root.weekWidth
                                height: root.cellHeight
                                visible: root.showWeekNumbers
                                Text {
                                    anchors.centerIn: parent
                                    // The row's last day names its week, so the
                                    // row holding 1 Farvardin reads 1, not 53.
                                    text: root.d(J.weekOfYear(root.days[week.index * 7 + 6].jdn))
                                    color: root.faint
                                    font.family: root.faFont
                                    font.pixelSize: 9 * root.s
                                }
                            }

                            Repeater {
                                model: 7
                                delegate: Item {
                                    id: cell
                                    required property int index
                                    readonly property var day: root.days[week.index * 7 + cell.index]
                                    readonly property bool selected: cell.day.jdn === root.selectedJdn
                                    readonly property bool hovered: cellArea.containsMouse
                                    readonly property bool emphasized: cell.selected || cell.day.today || cell.hovered
                                    readonly property bool off: cell.day.friday || (root.showHolidays && cell.day.holiday.length > 0)
                                    width: root.cellWidth
                                    height: root.cellHeight

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 29 * root.s
                                        height: 29 * root.s
                                        radius: width / 2
                                        color: cell.day.today
                                            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
                                            : (cell.emphasized ? Theme.hair : "transparent")
                                        border.width: cell.day.today ? 1 : 0
                                        border.color: root.accent
                                        scale: cell.emphasized ? 1 : 0.88
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.d(cell.day.day)
                                        color: !cell.day.inMonth ? root.faint
                                             : (cell.off && !cell.day.today ? root.accent : root.ink)
                                        opacity: cell.day.inMonth ? 1 : 0.75
                                        font.family: root.faFont
                                        font.pixelSize: 13 * root.s
                                        font.weight: cell.day.today ? Font.DemiBold : Font.Medium
                                    }

                                    // Gregorian day, tiny, in the cell's lower corner.
                                    Text {
                                        visible: root.showGregorian && cell.day.inMonth
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.rightMargin: 3 * root.s
                                        anchors.bottomMargin: 1 * root.s
                                        text: cell.day.gday
                                        color: root.faint
                                        font.family: Theme.mono
                                        font.pixelSize: 7 * root.s
                                    }

                                    // Holiday tick.
                                    Rectangle {
                                        visible: root.showHolidays && cell.day.inMonth && cell.day.holiday.length > 0
                                        width: 12 * root.s
                                        height: Math.max(1, root.s)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2 * root.s
                                        color: root.accent
                                    }

                                    MouseArea {
                                        id: cellArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onContainsMouseChanged: {
                                            if (containsMouse)
                                                root.hoveredJdn = cell.day.jdn;
                                            else if (root.hoveredJdn === cell.day.jdn)
                                                root.hoveredJdn = 0;
                                        }
                                        onClicked: root.pick(cell.day)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer: the hovered (or selected) day and what is on it.
        Item {
            id: details
            width: parent.width
            height: 52 * root.s

            readonly property var day: J.fromJdn(root.activeJdn)
            readonly property string holidayName: root.showHolidays ? J.holiday(details.day.jm, details.day.jd) : ""
            readonly property bool isFriday: details.day.wd === 6

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.hair
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 9 * root.s
                text: J.format(details.day, "full", root.fa)
                color: root.inkDim
                font.family: root.faFont
                font.pixelSize: 10 * root.s
            }
            Text {
                visible: root.showGregorian
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10 * root.s
                text: Qt.formatDate(J.toGregorianDate(root.activeJdn), "dddd, MMMM d, yyyy")
                color: root.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.letterSpacing: 0.8 * root.s
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6 * root.s
                horizontalAlignment: Text.AlignLeft
                readonly property bool has: details.holidayName.length > 0 || details.isFriday
                text: details.holidayName.length > 0
                      ? "تعطیل رسمی: " + details.holidayName
                      : (details.isFriday ? "تعطیل: جمعه" : "مناسبت یا تعطیلی ثبت نشده")
                color: has ? root.accent : root.faint
                opacity: has ? 1 : 0.7
                elide: Text.ElideRight
                font.family: root.faFont
                font.pixelSize: 11 * root.s
            }
        }
    }

    NumberAnimation {
        id: reveal
        target: grid
        property: "opacity"
        from: 0
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: sweep
        NumberAnimation { target: grid; property: "pulse"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: grid; property: "pulse"; from: 1; to: 0; duration: 220; easing.type: Easing.InOutCubic }
    }
}

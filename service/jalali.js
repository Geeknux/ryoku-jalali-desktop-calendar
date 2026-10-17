.pragma library

// Jalali (Solar Hijri) <-> Gregorian conversion, after the jalaali-js
// algorithm (Borkowski's break table). Pure functions, no I/O.

var BREAKS = [-61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635,
              2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178];

var MONTHS = ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
              "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"];
// Saturday first, as the Iranian week runs.
var WEEKDAYS = ["شنبه", "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه"];
var WEEKDAYS_SHORT = ["ش", "ی", "د", "س", "چ", "پ", "ج"];

function div(a, b) { return ~~(a / b); }
function mod(a, b) { return a - ~~(a / b) * b; }

function jalCal(jy, withoutLeap) {
    var bl = BREAKS.length, gy = jy + 621, leapJ = -14, jp = BREAKS[0];
    var jm, jump = 0, leap, leapG, march, n, i;
    if (jy < jp || jy >= BREAKS[bl - 1])
        return null;
    for (i = 1; i < bl; i += 1) {
        jm = BREAKS[i];
        jump = jm - jp;
        if (jy < jm)
            break;
        leapJ = leapJ + div(jump, 33) * 8 + div(mod(jump, 33), 4);
        jp = jm;
    }
    n = jy - jp;
    leapJ = leapJ + div(n, 33) * 8 + div(mod(n, 33) + 3, 4);
    if (mod(jump, 33) === 4 && jump - n === 4)
        leapJ += 1;
    leapG = div(gy, 4) - div((div(gy, 100) + 1) * 3, 4) - 150;
    march = 20 + leapJ - leapG;
    if (withoutLeap)
        return { gy: gy, march: march };
    if (jump - n < 6)
        n = n - jump + div(jump + 4, 33) * 33;
    leap = mod(mod(n + 1, 33) - 1, 4);
    if (leap === -1)
        leap = 4;
    return { leap: leap, gy: gy, march: march };
}

function g2d(gy, gm, gd) {
    var d = div((gy + div(gm - 8, 6) + 100100) * 1461, 4)
          + div(153 * mod(gm + 9, 12) + 2, 5)
          + gd - 34840408;
    return d - div(div(gy + 100100 + div(gm - 8, 6), 100) * 3, 4) + 752;
}

function d2g(jdn) {
    var j = 4 * jdn + 139361631;
    j = j + div(div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
    var i = div(mod(j, 1461), 4) * 5 + 308;
    var gd = div(mod(i, 153), 5) + 1;
    var gm = mod(div(i, 153), 12) + 1;
    var gy = div(j, 1461) - 100100 + div(8 - gm, 6);
    return { gy: gy, gm: gm, gd: gd };
}

function j2d(jy, jm, jd) {
    var r = jalCal(jy, true);
    return g2d(r.gy, 3, r.march) + (jm - 1) * 31 - div(jm, 7) * (jm - 7) + jd - 1;
}

function d2j(jdn) {
    var gy = d2g(jdn).gy, jy = gy - 621, r = jalCal(jy, false);
    var k = jdn - g2d(gy, 3, r.march), jm, jd;
    if (k >= 0) {
        if (k <= 185)
            return { jy: jy, jm: 1 + div(k, 31), jd: mod(k, 31) + 1 };
        k -= 186;
    } else {
        jy -= 1;
        k += 179;
        if (r.leap === 1)
            k += 1;
    }
    jm = 7 + div(k, 30);
    jd = mod(k, 30) + 1;
    return { jy: jy, jm: jm, jd: jd };
}

function isLeap(jy) {
    var r = jalCal(jy, false);
    return r !== null && r.leap === 0;
}

function monthLength(jy, jm) {
    if (jm <= 6) return 31;
    if (jm <= 11) return 30;
    return isLeap(jy) ? 30 : 29;
}

// 0 = Saturday ... 6 = Friday.
function weekday(jdn) { return mod(jdn + 2, 7); }

// A JS Date (local time) to {jy, jm, jd, wd, jdn}.
function fromDate(date) {
    var jdn = g2d(date.getFullYear(), date.getMonth() + 1, date.getDate());
    var j = d2j(jdn);
    j.wd = weekday(jdn);
    j.jdn = jdn;
    return j;
}

function fromJdn(jdn) {
    var j = d2j(jdn);
    j.wd = weekday(jdn);
    j.jdn = jdn;
    return j;
}

function toGregorianDate(jdn) {
    var g = d2g(jdn);
    return new Date(g.gy, g.gm - 1, g.gd);
}

function digits(value, persian) {
    var s = String(value);
    if (!persian)
        return s;
    var fa = "۰۱۲۳۴۵۶۷۸۹";
    return s.replace(/[0-9]/g, function (c) { return fa.charAt(Number(c)); });
}

function pad2(n) { return n < 10 ? "0" + n : String(n); }

// fmt: "dm" | "wdm" | "full" | "numeric"
function format(j, fmt, persian) {
    if (fmt === "numeric")
        return digits(j.jy + "/" + pad2(j.jm) + "/" + pad2(j.jd), persian);
    var dm = digits(j.jd, persian) + " " + MONTHS[j.jm - 1];
    if (fmt === "dm")
        return dm;
    var wdm = WEEKDAYS[j.wd] + " " + dm;
    if (fmt === "full")
        return wdm + " " + digits(j.jy, persian);
    return wdm;
}

// The cells of a month grid, Saturday first: leading blanks, then each day.
function monthCells(jy, jm, todayJdn) {
    var first = j2d(jy, jm, 1);
    var lead = weekday(first);
    var len = monthLength(jy, jm);
    var cells = [];
    for (var b = 0; b < lead; b++)
        cells.push({ day: 0, jdn: 0, today: false, friday: false });
    for (var d = 1; d <= len; d++) {
        var jdn = first + d - 1;
        cells.push({ day: d, jdn: jdn, today: jdn === todayJdn, friday: weekday(jdn) === 6 });
    }
    return cells;
}

// Iran's official holidays that fall on a fixed Solar Hijri date. Holidays set
// by the lunar Hijri calendar move every year and depend on moon sighting, so
// they are not listed here.
var HOLIDAYS = {
    "1-1": "عید نوروز", "1-2": "عید نوروز", "1-3": "عید نوروز", "1-4": "عید نوروز",
    "1-12": "روز جمهوری اسلامی",
    "1-13": "روز طبیعت",
    "3-14": "رحلت امام خمینی",
    "3-15": "قیام ۱۵ خرداد",
    "11-22": "پیروزی انقلاب اسلامی",
    "12-29": "ملی شدن صنعت نفت"
};

function holiday(jm, jd) { return HOLIDAYS[jm + "-" + jd] || ""; }

// Week of the Jalali year, Saturday-first; the week holding 1 Farvardin is 1.
function weekOfYear(jdn) {
    var j = d2j(jdn);
    var start = j2d(j.jy, 1, 1);
    return div(jdn - start + weekday(start), 7) + 1;
}

// A fixed grid of `weeks` Saturday-first rows covering month jy/jm, with the
// neighbouring months' days filling the edges (inMonth false).
function buildRange(jy, jm, todayJdn, weeks) {
    var first = j2d(jy, jm, 1);
    var start = first - weekday(first);
    var days = [];
    for (var i = 0; i < weeks * 7; i++) {
        var jdn = start + i;
        var j = d2j(jdn);
        var g = d2g(jdn);
        days.push({
            jdn: jdn,
            jy: j.jy, jm: j.jm, day: j.jd,
            gday: g.gd,
            inMonth: j.jm === jm && j.jy === jy,
            today: jdn === todayJdn,
            friday: i % 7 === 6,
            holiday: holiday(j.jm, j.jd),
            row: div(i, 7),
            column: i % 7
        });
    }
    return days;
}

// "Sep – Oct 2026" style span of the Gregorian months a Jalali month covers.
function gregorianSpan(jy, jm) {
    var a = toGregorianDate(j2d(jy, jm, 1));
    var b = toGregorianDate(j2d(jy, jm, monthLength(jy, jm)));
    var M = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if (a.getFullYear() === b.getFullYear())
        return M[a.getMonth()] + " – " + M[b.getMonth()] + " " + b.getFullYear();
    return M[a.getMonth()] + " " + a.getFullYear() + " – " + M[b.getMonth()] + " " + b.getFullYear();
}

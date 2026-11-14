import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Language and region (Plasma's plasma-localerc): the language of menus and
// apps, and how dates, times, numbers and money are written, from the
// languages this computer has (localectl list-locales). They apply when you
// next sign in; adding languages (which needs an administrator) is in KDE's
// page.
SettingsPage {
    id: page
    title: "Language & Region"

    property var locales: []       // ["en_UG.UTF-8", ...]
    property string formats: ""
    property string language: ""
    property bool changed: false

    function code(l) { return l.replace(/\..*$/, "") }
    function label(l) {
        const loc = Qt.locale(code(l))
        const lang = loc.nativeLanguageName || code(l)
        const terr = loc.nativeTerritoryName || ""
        return lang.charAt(0).toUpperCase() + lang.slice(1) + (terr ? " (" + terr + ")" : "")
    }
    function example(l) {
        const loc = Qt.locale(code(l))
        return new Date().toLocaleDateString(loc, Locale.LongFormat) + " · " + new Date().toLocaleTimeString(loc, Locale.ShortFormat) +
               " · " + Number(1234567.89).toLocaleString(loc, "f", 2) + " · " + Number(15000).toLocaleCurrencyString(loc)
    }
    function read() {
        System.run(["localectl", "list-locales"], (o) => {
            locales = o.split("\n").map(s => s.trim()).filter(s => /UTF-8$/i.test(s) && !/^C\./.test(s))
                       .sort((a, b) => label(a).localeCompare(label(b)))
        })
        System.run(["kreadconfig6", "--file", "plasma-localerc", "--group", "Formats", "--key", "LANG"], (o) => {
            formats = o.trim()
            if (formats === "") System.run(["sh", "-c", "echo ${LANG:-en_US.UTF-8}"], (l) => formats = l.trim())
        })
        System.run(["kreadconfig6", "--file", "plasma-localerc", "--group", "Translations", "--key", "LANGUAGE"], (o) => {
            language = o.trim().split(":")[0]
            if (language === "") System.run(["sh", "-c", "echo ${LANG:-en_US.UTF-8}"], (l) => language = code(l.trim()))
        })
    }
    Component.onCompleted: read()

    Surface {
        visible: page.changed
        Layout.fillWidth: true
        implicitHeight: 60
        stroke: Theme.accent
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            Label { Layout.fillWidth: true; text: "Sign out and back in to see the change everywhere"; font.weight: Font.DemiBold }
            Btn {
                text: "Sign out"
                primary: true
                onClicked: System.launch(["qdbus6", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptLogout"])
            }
        }
    }

    Section { title: "Language"; caption: "Menus, apps and messages" }
    Card {
        SettingRow {
            title: "Language"
            icon: "preferences-desktop-locale-symbolic"
            Choice {
                implicitWidth: 280
                options: page.locales.map(l => page.label(l))
                current: page.locales.findIndex(l => page.code(l) === page.language)
                onPicked: (i) => {
                    const c = page.code(page.locales[i])
                    page.language = c
                    // The language, then English as a fallback for anything untranslated.
                    System.run(["kwriteconfig6", "--file", "plasma-localerc", "--group", "Translations", "--key", "LANGUAGE", c + (c.indexOf("en") === 0 ? "" : ":en_US")], () => page.changed = true)
                }
            }
        }
    }

    Section { title: "Region"; caption: "How dates, times, numbers and money are written" }
    Card {
        SettingRow {
            title: "Formats"
            subtitle: page.formats ? page.example(page.formats) : ""
            Choice {
                implicitWidth: 280
                options: page.locales.map(l => page.label(l))
                current: page.locales.indexOf(page.formats)
                onPicked: (i) => {
                    const l = page.locales[i]
                    page.formats = l
                    System.run(["kwriteconfig6", "--file", "plasma-localerc", "--group", "Formats", "--key", "LANG", l], () => page.changed = true)
                }
            }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Add a language, and separate formats for time, money and measurements"
            subtitle: "Adding a language needs an administrator's password"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_regionandlang"])
        }
    }
}

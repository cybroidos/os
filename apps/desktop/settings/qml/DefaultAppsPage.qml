import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Default apps (freedesktop.org's mimeapps.list, through xdg-mime; KDE reads
// it too): which app opens web links, email, files, documents, pictures,
// music and videos; the terminal from kdeglobals.
SettingsPage {
    id: page
    title: "Default Apps"

    // [title, the type that decides it, every type set with it]
    readonly property var kinds: [
        ["Web browser", "x-scheme-handler/https", ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml"]],
        ["Email", "x-scheme-handler/mailto", ["x-scheme-handler/mailto"]],
        ["Files", "inode/directory", ["inode/directory"]],
        ["Text", "text/plain", ["text/plain"]],
        ["PDF documents", "application/pdf", ["application/pdf"]],
        ["Pictures", "image/jpeg", ["image/jpeg", "image/png", "image/webp", "image/gif"]],
        ["Music", "audio/mpeg", ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"]],
        ["Videos", "video/mp4", ["video/mp4", "video/x-matroska", "video/webm"]]]
    property var apps: ({})        // kind title → [{id, name}]
    property var chosen: ({})      // kind title → desktop id

    // The apps that can open a type, from their .desktop files (the
    // CybroidOS names in /usr/share/cybroid/apps first). Hidden entries count
    // too (Okular opens PDFs through one), under their app's name. With no
    // default set, KDE picks the highest InitialPreference: shown as chosen.
    function candidates(kind) {
        const mime = kind[1]
        const script = "for d in /usr/share/cybroid/apps/applications /usr/share/applications \"$HOME/.local/share/applications\"; do " +
            "grep -lE '^MimeType=(.*;)?" + mime.replace("+", "\\+") + "(;|$)' \"$d\"/*.desktop 2>/dev/null; done | " +
            "while read -r f; do printf '%s|%s|%s|%s\\n' \"$(basename \"$f\")\" \"$(sed -n 's/^Name=//p' \"$f\" | head -1)\" " +
            "\"$(sed -n 's/^InitialPreference=//p' \"$f\" | head -1)\" \"$(grep -c '^NoDisplay=true' \"$f\")\"; done"
        System.run(["sh", "-c", script], (o) => {
            const byId = {}, byName = {}
            for (const l of o.split("\n")) {
                const p = l.split("|")
                if (p.length < 4 || byId[p[0]] || p[1] === "") continue
                const app = { id: p[0], name: p[1], pref: parseInt(p[2]) || 0, hidden: p[3] !== "0" }
                byId[p[0]] = app
                // One entry per app name: the visible one over a hidden helper.
                const o2 = byName[app.name]
                if (!o2 || (o2.hidden && !app.hidden)) byName[app.name] = app
            }
            const list = Object.values(byName).sort((x, y) => (y.pref - x.pref) || x.name.localeCompare(y.name))
            const a = Object.assign({}, apps); a[kind[0]] = list; apps = a
            System.run(["xdg-mime", "query", "default", mime], (d) => {
                let id = d.trim()
                // A default set as a hidden entry, or none: the app KDE would use.
                if (id && byId[id] && !list.some(x => x.id === id)) id = (byName[byId[id].name] || {}).id || id
                if (!id && list.length) id = list[0].id
                const c = Object.assign({}, chosen); c[kind[0]] = id; chosen = c
            })
        })
    }
    Component.onCompleted: { for (const k of kinds) candidates(k) }

    Card {
        Repeater {
            model: page.kinds
            SettingRow {
                id: kr
                required property var modelData
                readonly property var list: page.apps[modelData[0]] || []
                title: modelData[0]
                Choice {
                    implicitWidth: 240
                    placeholder: kr.list.length ? "Choose" : "No app for this"
                    options: (page.apps[modelData[0]] || []).map(a => a.name)
                    current: (page.apps[modelData[0]] || []).findIndex(a => a.id === page.chosen[modelData[0]])
                    onPicked: (i) => {
                        const kind = modelData, app = page.apps[kind[0]][i]
                        System.run(["xdg-mime", "default", app.id].concat(kind[2]), () => page.candidates(kind))
                    }
                }
            }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Every file type, and the terminal"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_componentchooser"])
        }
    }
}

import QtQuick 2.6
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.5
import org.kde.plasma.plasma5support as Plasma5Support

// "Workshop" tab: browse / search the Steam Workshop for Wallpaper Engine and subscribe from here.
// Everything network-related is done by the `wallpaper-workshop` helper (JSON on stdout).
Item {
    id: page
    property string libraryPath: ""
    property string currentId: ""
    signal useWallpaper(string id, string source)

    readonly property var sorts: [
        { text: "Trending", value: "trend" }, { text: "Most popular", value: "totaluniquesubscribers" },
        { text: "Most recent", value: "mostrecent" }, { text: "Recently updated", value: "lastupdated" }]
    readonly property var periods: [
        { text: "Today", value: 1 }, { text: "This week", value: 7 }, { text: "This month", value: 30 },
        { text: "3 months", value: 90 }, { text: "This year", value: 365 }, { text: "All time", value: -1 }]
    readonly property var tagGroups: [
        { name: "Type", tags: ["Scene", "Video", "Web"] },
        { name: "Age rating", tags: ["Everyone", "Questionable", "Mature"] },
        { name: "Genre", tags: ["Abstract", "Animal", "Anime", "Cartoon", "CGI", "Cyberpunk", "Fantasy", "Game", "Girls",
            "Guys", "Landscape", "Medieval", "Memes", "MMD", "Music", "Nature", "Pixel art", "Relaxing", "Retro",
            "Sci-Fi", "Sports", "Technology", "Television", "Vehicle", "Unspecified"] },
        { name: "Special", tags: ["Approved", "Audio responsive", "3D", "Customizable", "Puppet Warp", "HDR"] }]

    // 0 = ignore, 1 = must have, 2 = must not have
    property var tagState: ({ "Everyone": 1 })
    property int pageNo: 1
    property int total: 0
    property int perPage: 30
    property bool busy: false
    property bool loggedIn: false
    property string message: ""
    property var pending: ({})          // ids subscribed here that Steam is still downloading
    property int pendingCount: 0
    property bool showFilters: false

    ListModel { id: results }

    // ---- helper plumbing -------------------------------------------------------------------------------
    property var callbacks: ({})
    property int serial: 0
    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            exec.disconnectSource(sourceName);
            const cb = page.callbacks[sourceName];
            delete page.callbacks[sourceName];
            if (!cb) return;
            let obj = null;
            try { obj = JSON.parse(data["stdout"]); } catch (e) { obj = null; }
            if (obj === null) {
                const err = (data["stderr"] || "").trim().split("\n").pop();
                obj = { error: err || "The wallpaper-workshop helper isn't installed (see the project README)." };
            }
            cb(obj);
        }
    }
    function run(args, cb) {
        const cmd = 'W="$HOME/.local/bin/wallpaper-workshop"; [ -x "$W" ] || W=wallpaper-workshop; "$W" ' + args
            + ' #' + (++page.serial);
        page.callbacks[cmd] = cb;
        exec.connectSource(cmd);
    }
    function asciiJson(o) {
        return JSON.stringify(o).replace(/[\u0080-￿]/g, c => "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4));
    }
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // ---- actions ---------------------------------------------------------------------------------------
    function query() {
        const inc = [], exc = [];
        for (const k in tagState) { if (tagState[k] === 1) inc.push(k); else if (tagState[k] === 2) exc.push(k); }
        return {
            text: searchField.text, sort: sortBox.model[sortBox.currentIndex].value,
            days: periodBox.model[periodBox.currentIndex].value, include: inc, exclude: exc,
            page: pageNo, library: libraryPath
        };
    }
    function search(resetPage) {
        if (resetPage) pageNo = 1;
        busy = true; message = "";
        run("search " + shq(asciiJson(query())), res => {
            busy = false;
            results.clear();
            if (res.error) { message = res.error; total = 0; return; }
            total = res.total || 0;
            perPage = res.per_page || 30;
            for (let n = 0; n < res.items.length; n++) {
                const it = res.items[n];
                results.append({ wid: it.id, title: it.title, author: it.author || "", thumb: it.thumb || "",
                                 subs: it.subs || 0, installed: it.installed, source: it.source || "",
                                 state: it.installed ? "installed" : (pending[it.id] ? "downloading" : "") });
            }
            if (results.count === 0) message = "Nothing found. Try fewer filters.";
        });
    }
    function refreshLogin() { run("status", res => { loggedIn = !!res.logged_in; }); }
    function login() {
        message = "Complete the Steam sign-in in the window that just opened…";
        run("login", res => { message = res.ok ? "" : (res.error || ""); refreshLogin(); });
    }
    function logout() { run("logout", res => { loggedIn = false; }); }
    function setRow(wid, props) {
        for (let i = 0; i < results.count; i++)
            if (results.get(i).wid === wid) { for (const k in props) results.setProperty(i, k, props[k]); }
    }
    function subscribe(wid) {
        if (!loggedIn) { openInSteam(wid); return; }
        setRow(wid, { state: "subscribing" });
        run("subscribe " + shq(wid), res => {
            if (res.ok) {
                pending[wid] = true; pendingCount = Object.keys(pending).length;
                setRow(wid, { state: "downloading" });
                message = "Subscribed. Steam will download it (Steam must be running); it then appears here and in Wallpapers.";
            } else {
                setRow(wid, { state: "" });
                if (res.need_login) { loggedIn = false; message = "Steam sign-in expired — using the Steam client instead."; openInSteam(wid); }
                else message = "Couldn't subscribe: " + res.error;
            }
        });
    }
    // Opens the item in the (already signed-in) Steam client; subscribing there is picked up automatically.
    function openInSteam(wid) {
        run("open " + shq(wid), res => {
            if (res.ok) {
                pending[wid] = true; pendingCount = Object.keys(pending).length;
                setRow(wid, { state: "waiting" });
                message = "Click Subscribe on the page that just opened in Steam. It will show up here when it has downloaded.";
            } else message = "Couldn't open Steam: " + res.error;
        });
    }
    function checkPending() {
        run("installed " + shq(libraryPath), res => {
            const have = res.installed || {};
            for (const wid in pending) {
                if (have[wid]) {
                    setRow(wid, { state: "installed", installed: true, source: have[wid] });
                    delete pending[wid];
                }
            }
            pendingCount = Object.keys(pending).length;
        });
    }
    function cycleTag(t) {
        const s = Object.assign({}, tagState);
        s[t] = ((s[t] || 0) + 1) % 3;
        if (s[t] === 0) delete s[t];
        tagState = s;
    }
    function fmt(n) { return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k" : String(n); }

    Timer { interval: 5000; repeat: true; running: page.pendingCount > 0 && page.visible; onTriggered: page.checkPending() }
    Component.onCompleted: { refreshLogin(); search(true); }

    // ---- UI --------------------------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search the Workshop…"
                onAccepted: page.search(true)
            }
            ComboBox { id: sortBox; model: page.sorts; textRole: "text"; onActivated: page.search(true) }
            ComboBox {
                id: periodBox; model: page.periods; textRole: "text"; currentIndex: 1
                visible: page.sorts[sortBox.currentIndex].value === "trend" && searchField.text === ""
                onActivated: page.search(true)
            }
            Button { text: "Search"; onClicked: page.search(true) }
            Button { text: page.showFilters ? "Filters ▴" : "Filters ▾"; onClicked: page.showFilters = !page.showFilters }
        }

        Flickable {
            visible: page.showFilters
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(filterCol.implicitHeight, 170) : 0
            contentHeight: filterCol.implicitHeight
            clip: true
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: filterCol
                width: parent.width - 12
                Label { text: "Click a tag once to require it (✓), twice to exclude it (✕)."; opacity: 0.7 }
                Repeater {
                    model: page.tagGroups
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { text: modelData.name; font.bold: true }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: modelData.tags
                                delegate: Button {
                                    readonly property int st: page.tagState[modelData] || 0
                                    text: (st === 1 ? "✓ " : st === 2 ? "✕ " : "") + modelData
                                    flat: st === 0
                                    highlighted: st !== 0
                                    palette.button: st === 1 ? "#2e7d32" : st === 2 ? "#b71c1c" : undefined
                                    palette.buttonText: st === 0 ? undefined : "white"
                                    onClicked: { page.cycleTag(modelData); page.search(true); }
                                }
                            }
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: page.busy ? "Searching…" : page.message
            wrapMode: Text.Wrap
            opacity: 0.85
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 220
            cellHeight: 190
            model: results
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: 4
                    radius: 4; color: "transparent"
                    border.color: wid === page.currentId ? "#3daee9" : Qt.rgba(0.5, 0.5, 0.5, 0.4)
                    border.width: wid === page.currentId ? 2 : 1
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 4; spacing: 2
                        Image {
                            Layout.fillWidth: true; Layout.preferredHeight: 100
                            source: thumb; fillMode: Image.PreserveAspectCrop
                            asynchronous: true; clip: true
                            Rectangle { anchors.fill: parent; color: "#22888888"; z: -1 }
                        }
                        Label { text: title; elide: Text.ElideRight; Layout.fillWidth: true; font.bold: true }
                        Label {
                            text: (author ? author + "  ·  " : "") + "★ " + page.fmt(subs)
                            elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.7; font.pixelSize: 11
                        }
                        Button {
                            Layout.fillWidth: true
                            enabled: state === "" || state === "installed" || state === "waiting"
                            text: state === "installed" ? (wid === page.currentId ? "In use" : "Use as wallpaper")
                                : state === "subscribing" ? "Subscribing…"
                                : state === "waiting" ? "Waiting for you in Steam…"
                                : state === "downloading" ? "Downloading in Steam…" : "Subscribe"
                            highlighted: state === ""
                            onClicked: {
                                if (state === "installed") page.useWallpaper(wid, source);
                                else if (state === "waiting") page.openInSteam(wid);
                                else page.subscribe(wid);
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button { text: "◀ Prev"; enabled: page.pageNo > 1 && !page.busy; onClicked: { page.pageNo--; page.search(false); } }
            Label {
                text: "Page " + page.pageNo + (page.total > 0 ? " of " + Math.max(1, Math.ceil(page.total / page.perPage)) : "")
            }
            Button {
                text: "Next ▶"
                enabled: !page.busy && results.count > 0 && page.pageNo * page.perPage < page.total
                onClicked: { page.pageNo++; page.search(false); }
            }
            Item { Layout.fillWidth: true }
            Label { text: page.loggedIn ? "One-click subscribe on" : "Subscribe opens Steam"; opacity: 0.7 }
            Button {
                text: page.loggedIn ? "Sign out" : "Optional: sign in for one-click"
                onClicked: page.loggedIn ? page.logout() : page.login()
            }
        }
    }
}

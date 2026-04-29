import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color blue: _theme.blue
    readonly property color red: _theme.red
    readonly property color peach: _theme.peach

    // ─────────── State ───────────
    property string activeTab: "profile"
    property var profileData: ({})
    property var pullsList: []
    property var reviewsList: []
    property var issuesList: []
    property var notifsList: []
    property var reposList: []
    property var starredList: []
    property var gistsList: []
    property var activityList: []
    property var workflowsList: []
    property string errorMsg: ""
    property bool loading: false
    property string searchText: ""

    function fetchActive() {
        loading = true; errorMsg = "";
        dataProc.command = ["bash", "/home/amir/.config/hypr/scripts/quickshell/github/gh_data.sh", root.activeTab];
        dataProc.running = false; dataProc.running = true;
    }
    function fetchProfile() {
        loading = true; errorMsg = "";
        profileProc.running = false; profileProc.running = true;
    }
    function open(url) { if (url) Quickshell.execDetached(["xdg-open", url]); }

    Component.onCompleted: { fetchProfile(); fetchActive(); }
    onActiveTabChanged: fetchActive()

    Process {
        id: profileProc
        running: false
        command: ["bash", "/home/amir/.config/hypr/scripts/quickshell/github/gh_data.sh", "profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse(this.text);
                    if (j.error) { root.errorMsg = j.error; return; }
                    root.profileData = j;
                } catch(e) { root.errorMsg = "profile parse: " + e; }
            }
        }
    }
    Process {
        id: dataProc
        running: false
        command: ["bash", "/home/amir/.config/hypr/scripts/quickshell/github/gh_data.sh", "profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    let j = JSON.parse(this.text);
                    if (j.error) { root.errorMsg = j.error; return; }
                    if (j.type === "pulls")          root.pullsList = j.items || [];
                    else if (j.type === "reviews")   root.reviewsList = j.items || [];
                    else if (j.type === "issues")    root.issuesList = j.items || [];
                    else if (j.type === "notifications") root.notifsList = j.items || [];
                    else if (j.type === "repos")     root.reposList = j.items || [];
                    else if (j.type === "starred")   root.starredList = j.items || [];
                    else if (j.type === "gists")     root.gistsList = j.items || [];
                    else if (j.type === "activity")  root.activityList = j.items || [];
                    else if (j.type === "workflows") root.workflowsList = j.items || [];
                } catch(e) { root.errorMsg = "data parse: " + e; }
            }
        }
    }

    // ─────────── UI ───────────
    Rectangle {
        id: container
        anchors.fill: parent
        color: base
        radius: s(18)
        border.width: 1
        border.color: Qt.rgba(text.r, text.g, text.b, 0.06)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: s(14)
            spacing: s(10)

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                Rectangle {
                    width: s(44); height: s(44); radius: s(22); color: surface1; clip: true
                    Image { anchors.fill: parent; source: root.profileData.avatar_url || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.open(root.profileData.html_url) }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: root.profileData.name || root.profileData.login || "..."; color: root.text; font.family: "JetBrains Mono"; font.pixelSize: s(15); font.weight: Font.Black }
                    Text { text: root.profileData.login ? "@" + root.profileData.login : ""; color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(11) }
                }

                Rectangle {
                    width: s(34); height: s(34); radius: s(10)
                    color: refreshHover.containsMouse ? surface2 : surface1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: s(14); color: root.text }
                    MouseArea { id: refreshHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.fetchProfile(); root.fetchActive(); }
                    }
                }
            }

            // ── Body: sidebar + content ──
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: s(10)

                // ── Sidebar ──
                Rectangle {
                    Layout.preferredWidth: s(190); Layout.fillHeight: true
                    color: Qt.rgba(crust.r, crust.g, crust.b, 0.55); radius: s(12)
                    border.width: 1; border.color: Qt.rgba(text.r, text.g, text.b, 0.04)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: s(8)
                        spacing: s(2)

                        Repeater {
                            model: [
                                { id: "profile",       label: "Profile",       icon: "" , badge: -1 },
                                { id: "pulls",         label: "Pull Requests", icon: "" , badge: root.profileData.stats ? root.profileData.stats.open_prs : -1 },
                                { id: "reviews",       label: "Reviews",       icon: "" , badge: root.profileData.stats ? root.profileData.stats.review_requested : -1 },
                                { id: "issues",        label: "Issues",        icon: "" , badge: root.profileData.stats ? root.profileData.stats.open_issues : -1 },
                                { id: "notifications", label: "Notifications", icon: "" , badge: root.profileData.stats ? root.profileData.stats.notifications : -1 },
                                { id: "_sep1",         label: "",              icon: "" , badge: -1 },
                                { id: "repos",         label: "Repositories",  icon: "" , badge: root.profileData.public_repos !== undefined ? root.profileData.public_repos : -1 },
                                { id: "starred",       label: "Starred",       icon: "" , badge: root.profileData.stats ? root.profileData.stats.stars_given : -1 },
                                { id: "gists",         label: "Gists",         icon: "" , badge: root.profileData.public_gists !== undefined ? root.profileData.public_gists : -1 },
                                { id: "_sep2",         label: "",              icon: "" , badge: -1 },
                                { id: "activity",      label: "Activity",      icon: "" , badge: -1 },
                                { id: "workflows",     label: "Workflows",     icon: "" , badge: -1 }
                            ]
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: modelData.id.startsWith("_sep") ? s(10) : s(32)

                                // separator
                                Rectangle {
                                    visible: modelData.id.startsWith("_sep")
                                    height: 1; width: parent.width - s(12)
                                    anchors.centerIn: parent
                                    color: Qt.rgba(text.r, text.g, text.b, 0.05)
                                }

                                // sidebar item
                                Rectangle {
                                    visible: !modelData.id.startsWith("_sep")
                                    anchors.fill: parent
                                    radius: s(8)
                                    property bool active: root.activeTab === modelData.id
                                    color: active ? Qt.rgba(text.r, text.g, text.b, 0.10) : (sideHover.containsMouse ? Qt.rgba(text.r, text.g, text.b, 0.05) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: s(10)
                                        anchors.rightMargin: s(10)
                                        spacing: s(8)
                                        Text { text: modelData.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: s(13); color: root.text; Layout.preferredWidth: s(16) }
                                        Text { text: modelData.label; Layout.fillWidth: true; color: root.text; font.family: "JetBrains Mono"; font.pixelSize: s(11); font.weight: parent.parent.active ? Font.Black : Font.Bold; elide: Text.ElideRight }
                                        Rectangle {
                                            visible: modelData.badge >= 0
                                            Layout.preferredHeight: s(16)
                                            Layout.preferredWidth: badgeText.implicitWidth + s(10)
                                            radius: s(8)
                                            color: surface2
                                            Text { id: badgeText; anchors.centerIn: parent; text: modelData.badge >= 0 ? modelData.badge : ""; color: root.text; font.family: "JetBrains Mono"; font.pixelSize: s(9); font.weight: Font.Black }
                                        }
                                    }
                                    MouseArea {
                                        id: sideHover
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activeTab = modelData.id
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // ── Content area ──
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Qt.rgba(crust.r, crust.g, crust.b, 0.5); radius: s(12)
                    border.width: 1; border.color: Qt.rgba(text.r, text.g, text.b, 0.04)
                    clip: true

                    // banner: error / loading
                    Text {
                        anchors.centerIn: parent; visible: root.errorMsg.length > 0
                        text: root.errorMsg; color: red; font.family: "JetBrains Mono"; font.pixelSize: s(12)
                        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; width: parent.width - s(40)
                    }
                    Text {
                        anchors.centerIn: parent; visible: !root.errorMsg && root.loading
                        text: "loading..."; color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(12)
                    }

                    // ── Profile tab content (stat cards + bio) ──
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: s(14); spacing: s(12)
                        visible: !root.errorMsg && !root.loading && root.activeTab === "profile"

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4; rowSpacing: s(8); columnSpacing: s(8)
                            Repeater {
                                model: [
                                    { l: "Followers",     v: (root.profileData.followers !== undefined ? root.profileData.followers : "—") },
                                    { l: "Following",     v: (root.profileData.following !== undefined ? root.profileData.following : "—") },
                                    { l: "Public Repos",  v: (root.profileData.public_repos !== undefined ? root.profileData.public_repos : "—") },
                                    { l: "Stars Given",   v: (root.profileData.stats ? root.profileData.stats.stars_given : "—") },
                                    { l: "Open PRs",      v: (root.profileData.stats ? root.profileData.stats.open_prs : "—") },
                                    { l: "Reviews Req.",  v: (root.profileData.stats ? root.profileData.stats.review_requested : "—") },
                                    { l: "Open Issues",   v: (root.profileData.stats ? root.profileData.stats.open_issues : "—") },
                                    { l: "Notifications", v: (root.profileData.stats ? root.profileData.stats.notifications : "—") }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: s(64)
                                    radius: s(10); color: surface0
                                    border.width: 1; border.color: Qt.rgba(text.r, text.g, text.b, 0.04)
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: s(8); spacing: s(2)
                                        Text { text: modelData.v; color: root.text; font.family: "JetBrains Mono"; font.pixelSize: s(20); font.weight: Font.Black }
                                        Text { text: modelData.l; color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(10) }
                                    }
                                }
                            }
                        }
                        // bio / readme block
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: s(10); color: surface0
                            border.width: 1; border.color: Qt.rgba(text.r, text.g, text.b, 0.04)
                            clip: true
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: s(14); spacing: s(6)

                                Flickable {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    contentHeight: bioText.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                    Text {
                                        id: bioText
                                        width: parent.width
                                        text: (root.profileData.profile_readme && root.profileData.profile_readme.length > 0)
                                              ? root.profileData.profile_readme
                                              : (root.profileData.bio || "(no bio set on github.com/settings/profile)")
                                        textFormat: (root.profileData.profile_readme && root.profileData.profile_readme.length > 0) ? Text.MarkdownText : Text.PlainText
                                        color: root.text
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(11)
                                        wrapMode: Text.WordWrap
                                        onLinkActivated: (link) => root.open(link)
                                    }
                                }

                                RowLayout {
                                    spacing: s(14); Layout.fillWidth: true
                                    Text { text: " " + (root.profileData.location || "—"); color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(10) }
                                    Text { text: " " + (root.profileData.company || "—"); color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(10) }
                                    Text { text: " " + (root.profileData.blog || "—"); color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(10) }
                                    Item { Layout.fillWidth: true }
                                    Text { text: "joined " + (root.profileData.created_at ? root.profileData.created_at.substring(0,10) : "—"); color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(10) }
                                }
                            }
                        }
                    }

                    // ── Generic list (everything except profile) ──
                    ListView {
                        anchors.fill: parent; anchors.margins: s(8)
                        spacing: s(6); clip: true
                        visible: !root.errorMsg && !root.loading && root.activeTab !== "profile"
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        model: root.currentItems()

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: s(60); radius: s(10)
                            color: itemHover.containsMouse ? surface1 : surface0
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: s(10); spacing: s(2)
                                Text {
                                    Layout.fillWidth: true
                                    text: root.itemTitle(modelData)
                                    color: root.text; font.family: "JetBrains Mono"
                                    font.pixelSize: s(12); font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.itemSubtitle(modelData)
                                    color: subtext0; font.family: "JetBrains Mono"
                                    font.pixelSize: s(10)
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: itemHover; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.open(root.itemUrl(modelData))
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.errorMsg && !root.loading && root.activeTab !== "profile" && root.currentItems().length === 0
                        text: "(empty)"; color: subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(13)
                    }
                }
            }
        }
    }

    // ─────────── Helpers ───────────
    function currentItems() {
        switch (activeTab) {
            case "pulls":         return pullsList;
            case "reviews":       return reviewsList;
            case "issues":        return issuesList;
            case "notifications": return notifsList;
            case "repos":         return reposList;
            case "starred":       return starredList;
            case "gists":         return gistsList;
            case "activity":      return activityList;
            case "workflows":     return workflowsList;
            default: return [];
        }
    }
    function itemTitle(it) {
        if (!it) return "";
        switch (activeTab) {
            case "pulls": case "reviews": case "issues":
                return "#" + it.number + "  " + (it.title || "");
            case "notifications":
                return it.title || "(no title)";
            case "repos":
                return (it.nameWithOwner || it.name || "") + (it.visibility === "PRIVATE" ? "  · private" : "");
            case "starred":
                return it.full_name || "";
            case "gists":
                return it.description || it.id || "(untitled)";
            case "activity":
                return (it.repo || "") + " — " + (it.summary || it.type || "");
            case "workflows":
                return (it.name || "(workflow)") + (it.conclusion ? " · " + it.conclusion : (it.status ? " · " + it.status : ""));
            default: return "";
        }
    }
    function itemSubtitle(it) {
        if (!it) return "";
        function repoOf(x) { return x.repository ? (x.repository.nameWithOwner || x.repository.name || "") : ""; }
        switch (activeTab) {
            case "pulls":   return (it.isDraft ? "DRAFT  ·  " : "") + repoOf(it);
            case "reviews": return repoOf(it) + (it.author && it.author.login ? "  ·  by @" + it.author.login : "");
            case "issues":  return repoOf(it);
            case "notifications": return (it.repo || "") + "  ·  " + (it.reason || "");
            case "repos":
                return (it.primaryLanguage ? (it.primaryLanguage.name || "—") + "  ·  " : "")
                       + "★ " + (it.stargazerCount || 0)
                       + "  ·  ⑂ " + (it.forkCount || 0)
                       + (it.description ? "  ·  " + it.description : "");
            case "starred":
                return (it.language || "—") + "  ·  ★ " + (it.stargazers_count || 0)
                       + (it.description ? "  ·  " + it.description : "");
            case "gists":
                return (it["public"] === "public" ? "public" : "secret") + "  ·  " + (it.files || "?") + " files";
            case "activity":
                return (it.created_at ? it.created_at.substring(0,16).replace("T", " ") : "");
            case "workflows":
                return (it.repo || "") + (it.head_branch ? "  ·  " + it.head_branch : "") + (it.run_number ? "  ·  #" + it.run_number : "");
            default: return "";
        }
    }
    function itemUrl(it) {
        if (!it) return "";
        switch (activeTab) {
            case "pulls": case "reviews": case "issues": return it.url;
            case "notifications":
                return it.api_url
                    ? it.api_url.replace("api.github.com/repos/", "github.com/").replace("/pulls/", "/pull/")
                    : "https://github.com/notifications";
            case "repos":     return it.url || "";
            case "starred":   return it.html_url || "";
            case "gists":     return it.id ? "https://gist.github.com/" + (root.profileData.login || "anonymous") + "/" + it.id : "";
            case "activity":  return it.url || "";
            case "workflows": return it.html_url || "";
            default: return "";
        }
    }
}

.pragma library

function trimSlashes(value) {
    return String(value || "").replace(/^\/+|\/+$/g, "");
}

function join() {
    let parts = [];
    for (let i = 0; i < arguments.length; i++) {
        let part = arguments[i];
        if (part === undefined || part === null || String(part).length === 0) continue;
        let text = String(part);
        if (parts.length === 0 && text.indexOf("/") === 0) {
            parts.push(text.replace(/\/+$/g, ""));
        } else {
            parts.push(trimSlashes(text));
        }
    }
    if (parts.length === 0) return "";
    return parts.join("/").replace(/\/+/g, "/");
}

function homePath(home, suffix) {
    return join(home || "", suffix || "");
}

function quickshellDir(home) {
    return homePath(home, ".config/hypr/scripts/quickshell");
}

function cockpitCacheDir(home) {
    return homePath(home, ".cache/hermes-cockpit");
}

function cockpitJson(home, name) {
    return join(cockpitCacheDir(home), String(name || "status").replace(/\.json$/g, "") + ".json");
}

function hyprRiceRuntimeDir(runtimeDir) {
    return join(runtimeDir || "/tmp", "hypr-rice");
}

function riceStateJson(runtimeDir) {
    return join(hyprRiceRuntimeDir(runtimeDir), "state.json");
}

function notificationPolicyJson(runtimeDir) {
    return join(hyprRiceRuntimeDir(runtimeDir), "notification_policy.json");
}

function qsColorsJson(home) {
    return join(quickshellDir(home), "qs_colors.json");
}

function repoQuickshellDir(repoRoot) {
    return join(repoRoot || "", "config/hypr/scripts/quickshell");
}

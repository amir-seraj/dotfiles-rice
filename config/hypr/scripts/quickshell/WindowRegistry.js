.pragma library

function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }

    if (mw <= 0 || mh <= 0) return 1.0;
    
    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);
    
    let baseScale = 1.0;
    
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);

    let base = {
        // --- Top Right Popups ---
        "battery":   { w: s(801, scale), h: s(760, scale), rx: mw - s(805, scale), ry: s(60, scale), comp: "battery/BatteryPopup.qml" },
        "network":   { w: s(900, scale), h: s(700, scale), rx: mw - s(904, scale), ry: s(60, scale), comp: "network/NetworkPopup.qml" },
        "volume":    { w: s(450, scale), h: s(700, scale), rx: mw - s(455, scale), ry: s(60, scale), comp: "volume/VolumePopup.qml" },
        
        // --- Command Deck / cockpit ---
        "commanddeck": { w: s(1180, scale), h: s(760, scale), rx: Math.floor((mw/2)-(s(1180, scale)/2)), ry: Math.floor((mh/2)-(s(760, scale)/2)), comp: "commanddeck/CommandDeckPopup.qml" },

        // --- GitHub ---
        "github":    { w: s(1200, scale), h: s(820, scale), rx: Math.floor((mw/2)-(s(1200, scale)/2)), ry: Math.floor((mh/2)-(s(820, scale)/2)), comp: "github/GitHubPopup.qml" },

        // --- X Operator Cockpits ---
        "health":    { w: s(880, scale), h: s(680, scale), rx: Math.floor((mw/2)-(s(880, scale)/2)), ry: Math.floor((mh/2)-(s(680, scale)/2)), comp: "health/HealthPopup.qml" },
        "obsidian":  { w: s(900, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "obsidian/ObsidianCockpitPopup.qml" },
        "agents":    { w: s(900, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "agents/AgentHudPopup.qml" },
        "devlab":    { w: s(960, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(960, scale)/2)), ry: Math.floor((mh/2)-(s(720, scale)/2)), comp: "devlab/DevLabPopup.qml" },
        "sentinel":  { w: s(960, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(960, scale)/2)), ry: Math.floor((mh/2)-(s(720, scale)/2)), comp: "sentinel/SentinelPopup.qml" },
        "commandpalette": { w: s(900, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(720, scale)/2)), comp: "commandpalette/CommandPalettePopup.qml" },
        "systemcockpit": { w: s(900, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "system/SystemCockpitPopup.qml" },
        "musicdeck": { w: s(820, scale), h: s(660, scale), rx: Math.floor((mw/2)-(s(820, scale)/2)), ry: Math.floor((mh/2)-(s(660, scale)/2)), comp: "musicdeck/MusicDeckPopup.qml" },
        "bootritual": { w: s(860, scale), h: s(660, scale), rx: Math.floor((mw/2)-(s(860, scale)/2)), ry: Math.floor((mh/2)-(s(660, scale)/2)), comp: "boot/BootRitualPopup.qml" },
        "themepicker": { w: s(860, scale), h: s(660, scale), rx: Math.floor((mw/2)-(s(860, scale)/2)), ry: Math.floor((mh/2)-(s(660, scale)/2)), comp: "themes/ThemePickerPopup.qml" },

        // --- Body / health utility ---
        "movetimer": { w: s(560, scale), h: s(620, scale), rx: Math.floor((mw/2)-(s(560, scale)/2)), ry: Math.floor((mh/2)-(s(620, scale)/2)), comp: "movetimer/MoveTimerPopup.qml" },

        // --- Central Standard Tools ---
        "applauncher": { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "applauncher/appLauncher.qml" },
        "clipboard": { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "clipboard/ClipboardManager.qml" },
        "monitors":  { w: s(800, scale), h: s(650, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "monitors/MonitorPopup.qml" },
        "stewart":   { w: s(800, scale), h: s(650, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "stewart/stewart.qml" },

        // --- Central Large Tools ---
        "focustime": { w: s(900, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "focustime/FocusTimePopup.qml" },

        // --- Extralarge / Custom Centered ---
        "guide":     { w: s(1200, scale), h: s(750, scale), rx: Math.floor((mw/2)-(s(1200, scale)/2)), ry: Math.floor((mh/2)-(s(750, scale)/2)), comp: "guide/GuidePopup.qml" },
        "calendar":  { w: s(1450, scale), h: s(750, scale), rx: Math.floor((mw/2)-(s(1450, scale)/2)), ry: s(60, scale), comp: "calendar/CalendarPopup.qml" },
        "updater":   { w: s(500, scale),  h: s(600, scale), rx: Math.floor((mw/2)-(s(500, scale)/2)), ry: Math.floor((mh/2)-(s(600, scale)/2)), comp: "updater/UpdaterPopup.qml" },
        "wallpaper": { w: mw, h: s(650, scale), rx: 0, ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "wallpaper/WallpaperPicker.qml" },
        
        // --- Top Left Edge ---
        "music":     { w: s(700, scale), h: s(650, scale), rx: s(5, scale), ry: s(60, scale), comp: "music/MusicPopup.qml" },

        "movies": {
            w: s(1370, scale),
            h: s(850, scale),
            rx: Math.floor((mw / 2) - (s(1370, scale) / 2)),
            ry: mh - s(850, scale),
            comp: "movies/MovieWidget.qml"
        },
        
        // --- Screen Spanning Panels ---
        "settings":  { w: s(450, scale), h: mh - s(0, scale), rx: s(0, scale), ry: s(0, scale), comp: "settings/SettingsPopup.qml" },
        
        // --- Utility ---
        "hidden":    { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" } 
    };

    if (!base[name]) return null;
    
    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;
    
    return t;
}

function getPopupLayout(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }
    
    let scale = getScale(mw, mh, userScale);
    return {
        w: s(350, scale),
        marginTop: s(60, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}

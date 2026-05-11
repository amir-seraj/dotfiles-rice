# X Operator Rice Megaplan Implementation Plan

> For Hermes: Use subagent-driven-development skill to implement this plan task-by-task. Do not implement all tasks concurrently when they touch the same QML/config files. Use fresh subagents per phase slice, then run validation gates.

Goal: Build the full “go wild” X Operator Noir desktop: command deck, workspace personalities, health/focus system, privacy mode, Obsidian/project/agent/system cockpit, music, notification privacy, lock screen polish, theme engine, and boot-to-work ritual.

Architecture: One central privacy-safe state layer feeds Quickshell widgets. Shell/Python backends write sanitized JSON under ~/.cache/hermes-cockpit and ${XDG_RUNTIME_DIR}/hypr-rice. Quickshell reads only those sanitized JSON files and opens popups through the existing WindowRegistry.js + qs_manager.sh IPC pattern.

Tech Stack: Hyprland, Quickshell/QML, bash, Python 3, jq, systemd user timers, Kitty, Obsidian vault files, existing Hermes scripts, playerctl, grim, awww/matugen.

Safety: Repo-first. Backup before live sync. Privacy mode is fail-closed. No raw notifications, transcripts, browser text, health note bodies, screenshots, secrets, or tokens in topbar/widgets.

---

## Current baseline

Repo: /home/amir/dotfiles-rice
Live config: /home/amir/.config/hypr
Quickshell live: /home/amir/.config/hypr/scripts/quickshell
Important existing files:
- Main.qml: overlay panel, StackView, notification server, IPC watcher
- TopBar.qml: live topbar/status modules
- WindowRegistry.js: popup registry/layouts
- qs_manager.sh: writes /tmp/qs_widget_state
- movetimer/: working movement timer backend + popup
- github/GitHubPopup.qml: existing full utility popup style

Known Quickshell pitfalls:
- Use masterWindow.screen.width/height for popup layout, not masterWindow.width/height.
- Popup root must define notifModel/layoutWidth/layoutHeight.
- Never declare property var data on Item/Rectangle roots; Qt Quick uses Item.data as child container. Use timerData/stateData/payload.
- After close all, wait about 1 second before opening another widget unless delayedClear race guard is active.

---

## Agent dispatch summary

Dispatched/monitored 3 planning agents:

1. Quickshell architecture agent
   Scope: ideas 1, 6, 8, 10, 11, 17, 18, 19.
   Result: proposed shared QML components, popup registry strategy, backend JSON contracts, validation gates.

2. Hyprland automation agent
   Scope: ideas 2, 4, 5, 7, 9, 13, 14, 15, 20.
   Result: proposed ricectl, workspace personalities, privacy/focus modes, aura, terminal profiles, notification policy, lock-prep, boot ritual.

3. Data/backend integration agent
   Scope: ideas 3, 6, 10, 12, 16, 17, 20.
   Result: proposed hermes_cockpit_status.py aggregator, health/system/agent/Obsidian/Sentinel/music JSON schemas, privacy risks.

---

## The 20 ideas mapped to concrete modules

1. X Command Deck
   - Popup: quickshell/commanddeck/CommandDeckPopup.qml
   - Backend: ~/.hermes/scripts/hermes_cockpit_status.py all
   - State: ~/.cache/hermes-cockpit/{system,health,agents,obsidian,projects,music,sentinel,ritual}.json
   - Keybind: Super+Space or Super+Ctrl+Space if Super+Space already used.

2. Workspace Personalities
   - Config: config/hypr/modes/personalities.json
   - Script: config/hypr/scripts/workspace-personality.sh or ricectl.sh workspace-enter
   - Modify: workspaces.sh, TopBar.qml, settings.json workspaceCount=10.

3. Animated Spine Health Daemon
   - Extend: movetimer/move_timer.py
   - Backend: ~/.hermes/scripts/health_status.py or hermes_cockpit_status.py health
   - State: ~/.cache/hermes-cockpit/health.json
   - UI: health/HealthPopup.qml or section in CommandDeck.

4. Focus/Flow Mode
   - Script: config/hypr/scripts/focus-mode.sh or ricectl.sh mode focus
   - State: ${XDG_RUNTIME_DIR}/hypr-rice/state.json
   - Effects: starts timers, hides noisy modules, privacy redaction, optional app launch.

5. Dynamic Wallpaper/Status Aura
   - Script: config/hypr/scripts/aura.sh
   - Config: config/hypr/modes/wallpaper_auras.json
   - Modify: WallpaperPicker.qml, init.sh, TopBar.qml.

6. Obsidian Cockpit
   - Backend: ~/.hermes/scripts/obsidian_cockpit_status.py or hermes_cockpit_status.py obsidian
   - State: ~/.cache/hermes-cockpit/obsidian.json, projects.json
   - UI: obsidian/ObsidianCockpitPopup.qml, CommandDeck section.

7. Terminal Operator Glass Profiles
   - Script: config/hypr/scripts/terminal-profile.sh
   - Config: config/hypr/modes/terminal_profiles.json
   - Kitty profiles: config/kitty/profiles/{default,code,private,admin}.conf
   - Modify: variables.conf/settings.json terminal keybinds.

8. Sci-fi App Launcher / Command Palette
   - Popup: commandpalette/CommandPalettePopup.qml
   - Backend: commandpalette/command_palette.py
   - Sources: .desktop apps, ~/.hermes/projects.yaml, scripts, recent commands.

9. Notification Center Overhaul
   - Policy: config/hypr/modes/notification_rules.json
   - Script: config/hypr/scripts/notify-policy.sh
   - Modify: Main.qml notification capture, NotificationPopups.qml
   - Optional UI: notifications/NotificationCenter.qml.

10. Agent Activity HUD
   - Backend: ~/.hermes/scripts/agent_activity_status.py or hermes_cockpit_status.py agents
   - State: ~/.cache/hermes-cockpit/agents.json
   - UI: agents/AgentHudPopup.qml, CommandDeck section.

11. GitHub/Dev Lab Expansion
   - Extend: github/GitHubPopup.qml or create devlab/DevLabPopup.qml
   - Backend: devlab/devlab_status.py using gh/git locally
   - State: ~/.cache/hermes-cockpit/devlab.json

12. Sensor/Internship Mode
   - Backend: ~/.hermes/scripts/sentinel_mode.py
   - State: ~/.hermes/state/sentinel_mode.json and ~/.cache/hermes-cockpit/sentinel.json
   - UI: sentinel/SentinelPopup.qml, CommandDeck section.

13. Cinematic Lock Screen
   - Modify: lock.sh, Lock.qml, hypridle.conf
   - Add: lock-prep.sh, modes/lock_profiles.json
   - Privacy: if privacy mode, do not screenshot current desktop for lock background.

14. Living Topbar
   - Add: quickshell/RiceState.qml or state reader process in TopBar.qml
   - Modify: TopBar.qml modules to react to mode/aura/privacy/workspace personality.

15. Private Mode
   - Script: ricectl.sh privacy toggle
   - Modify: Main.qml notification storage/display, TopBar redaction, workspace 9 behavior.
   - Must be implemented before any flashy notification/history features.

16. Audio/Music Visualizer Widget
   - Backend: ~/.hermes/scripts/music_status.py wrapping existing music/music_info.sh
   - State: ~/.cache/hermes-cockpit/music.json
   - UI: music/MusicPopup.qml extension or musicdeck/MusicDeckPopup.qml.

17. System Thermal/CPU Cockpit
   - Backend: ~/.hermes/scripts/system_cockpit_status.py or hermes_cockpit_status.py system
   - State: ~/.cache/hermes-cockpit/system.json
   - UI: system/SystemCockpitPopup.qml.

18. X Face Mascot Module
   - UI component: components/XMascot.qml
   - Topbar chip + CommandDeck avatar.
   - Mood derives from state.json: focus/privacy/move_due/agent_running/music.

19. Quickshell Theme Engine
   - Config: config/hypr/modes/themes.json
   - Script: ricectl.sh theme apply <name>
   - QML: ThemeState.qml or theme reader in Config.qml/TopBar.qml.

20. Full Boot-to-Work Ritual
   - Backend: ~/.hermes/scripts/boot_to_work.py and/or config/hypr/scripts/boot-ritual.sh
   - State: ~/.cache/hermes-cockpit/ritual.json
   - UI: boot/BootRitualPopup.qml, CommandDeck section.

---

## Implementation phases and gates

### Gate 0: Repo + live backup

Commands:
```bash
git -C /home/amir/dotfiles-rice status --short --branch
backup=/home/amir/.config/rice-backups/$(date +%Y%m%d-%H%M%S)-xoperator-megaplan
mkdir -p "$backup"
cp -a /home/amir/.config/hypr "$backup/hypr"
cp -a /home/amir/.config/kitty "$backup/kitty"
```

Pass criteria:
- Repo starts clean or changes are deliberately committed/stashed.
- Backup path exists.

Abort if:
- Repo has unknown unrelated dirty files.
- Live config backup fails.

---

### Phase 1: State brain + privacy-safe JSON cache

Objective: Create the backend foundation before any huge UI.

Files to create:
- config/hypr/scripts/ricectl.sh
- config/hypr/modes/personalities.json
- config/hypr/modes/privacy_rules.json
- config/hypr/modes/notification_rules.json
- config/hypr/modes/wallpaper_auras.json
- config/hypr/modes/terminal_profiles.json
- config/hypr/modes/themes.json
- /home/amir/.hermes/scripts/hermes_cockpit_status.py

Runtime/state outputs:
- ${XDG_RUNTIME_DIR}/hypr-rice/state.json
- ${XDG_RUNTIME_DIR}/hypr-rice/notification_policy.json
- ~/.cache/hermes-cockpit/system.json
- ~/.cache/hermes-cockpit/health.json
- ~/.cache/hermes-cockpit/agents.json
- ~/.cache/hermes-cockpit/obsidian.json
- ~/.cache/hermes-cockpit/projects.json
- ~/.cache/hermes-cockpit/music.json
- ~/.cache/hermes-cockpit/sentinel.json
- ~/.cache/hermes-cockpit/ritual.json

Tasks:
1. Create config/hypr/modes/*.json with safe defaults.
2. Create ricectl.sh with commands:
   - state
   - mode normal|focus|privacy|presentation|personal
   - privacy on|off|toggle
   - workspace-enter <n>
   - aura <name>
   - theme <name>
3. Create hermes_cockpit_status.py with subcommands:
   - all, system, health, agents, obsidian, projects, music, sentinel, ritual
4. Add atomic JSON write helper.
5. Add redaction helper.
6. Add systemd user service/timer only after manual script validation.

Validation:
```bash
bash -n /home/amir/dotfiles-rice/config/hypr/scripts/ricectl.sh
jq empty /home/amir/dotfiles-rice/config/hypr/modes/*.json
python3 -m py_compile /home/amir/.hermes/scripts/hermes_cockpit_status.py
/home/amir/dotfiles-rice/config/hypr/scripts/ricectl.sh state | jq .
python3 /home/amir/.hermes/scripts/hermes_cockpit_status.py all
for f in /home/amir/.cache/hermes-cockpit/*.json; do jq empty "$f"; done
```

Pass criteria:
- All JSON files are valid.
- No raw notification bodies, transcript text, note bodies, secrets, IPs, or full window titles are emitted.

---

### Phase 2: Shared Quickshell component kit

Objective: Make all future widgets consistent and avoid copy/paste bugs.

Files to create:
- config/hypr/scripts/quickshell/components/PopupScaffold.qml
- config/hypr/scripts/quickshell/components/PopupHeader.qml
- config/hypr/scripts/quickshell/components/IconButton.qml
- config/hypr/scripts/quickshell/components/PillButton.qml
- config/hypr/scripts/quickshell/components/SectionCard.qml
- config/hypr/scripts/quickshell/components/TabRail.qml
- config/hypr/scripts/quickshell/components/MetricRing.qml
- config/hypr/scripts/quickshell/components/EmptyState.qml
- config/hypr/scripts/quickshell/components/XMascot.qml
- config/hypr/scripts/quickshell/lib/JsonUtil.js
- config/hypr/scripts/quickshell/lib/Paths.js

Tasks:
1. Implement PopupScaffold with required StackView props.
2. Implement basic visual components using existing MatugenColors/Scaler.
3. Create one sandbox popup component test if needed.
4. Do not refactor GitHub/MoveTimer yet.

Validation:
```bash
qmllint /home/amir/dotfiles-rice/config/hypr/scripts/quickshell/components/*.qml
```

Pass criteria:
- QML lint clean.
- Components do not declare property var data.

---

### Phase 3: Command Deck MVP

Objective: Implement idea 1 as the central hub and prove backend/UI flow.

Files to create:
- config/hypr/scripts/quickshell/commanddeck/CommandDeckPopup.qml
- optional: config/hypr/scripts/quickshell/commanddeck/command_deck_status.py if not using hermes_cockpit_status.py directly

Files to modify:
- WindowRegistry.js: add commanddeck layout
- settings.json: add keybind for commanddeck
- optionally TopBar.qml: add small command deck button/chip

Suggested layout:
- Header: X COMMAND DECK, time, privacy/mode chip
- Left rail: Overview, Work, Health, Agents, System, Music, Ritual
- Cards:
  - current project / workspace personality
  - focus + spine timers
  - agent activity
  - system resources
  - Obsidian cockpit links/counts
  - music status
- Actions:
  - Work Mode
  - Privacy Mode
  - Capture Note
  - Work Report
  - Open Project
  - AI Handoff

Validation:
```bash
qmllint /home/amir/dotfiles-rice/config/hypr/scripts/quickshell/commanddeck/CommandDeckPopup.qml
# after live sync:
qs -p ~/.config/hypr/scripts/quickshell/Main.qml ipc call main forceReload
bash ~/.config/hypr/scripts/qs_manager.sh close all
sleep 1
bash ~/.config/hypr/scripts/qs_manager.sh open commanddeck
cat /tmp/qs_current_widget
WAYLAND_DISPLAY=wayland-1 grim /tmp/hermes-rice/commanddeck.png
```

Pass criteria:
- Popup opens centered.
- No blank panel.
- No private raw text displayed.

---

### Phase 4: Privacy mode + notification center hardening

Objective: Implement ideas 9 and 15 before more data-rich widgets.

Files to modify:
- Main.qml
- notifications/NotificationPopups.qml
- TopBar.qml
- settings.json

Files to create:
- config/hypr/scripts/notify-policy.sh
- config/hypr/scripts/quickshell/notifications/NotificationCenter.qml optional

Tasks:
1. Main.qml reads notification policy JSON.
2. In privacy/private mode, do not append raw notification summary/body to visible popups or history.
3. In redacted mode, show app class only and generic hidden text.
4. TopBar shows privacy chip and redacts media/window-sensitive text.
5. Add privacy toggle keybind.

Validation:
```bash
~/.config/hypr/scripts/ricectl.sh privacy on
notify-send "SECRET TITLE" "SECRET BODY"
# visually confirm no SECRET text
~/.config/hypr/scripts/ricectl.sh privacy off
notify-send "NORMAL TITLE" "NORMAL BODY"
```

Pass criteria:
- SECRET TITLE/BODY never appears visually or in notification history in privacy mode.
- Normal notifications return when privacy off.

---

### Phase 5: Workspace personalities + living topbar

Objective: Implement ideas 2 and 14.

Files to modify:
- workspaces.sh
- TopBar.qml
- settings.json
- optionally qs_manager.sh to call ricectl workspace-enter

Tasks:
1. Set workspaceCount to 10.
2. personalities.json defines workspace icon/name/aura/privacy/terminal policy.
3. workspaces.sh emits personality metadata.
4. TopBar uses personality icon/color/name.
5. Workspace 9 implies privacy/private policy.

Validation:
```bash
jq empty ~/.config/hypr/modes/personalities.json
bash ~/.config/hypr/scripts/quickshell/workspaces.sh | jq .
hyprctl dispatch workspace 9
cat ${XDG_RUNTIME_DIR}/hypr-rice/state.json | jq .
```

Pass criteria:
- Workspace icons/names show correctly.
- Workspace 9 switches to privacy-safe topbar behavior.

---

### Phase 6: Health/focus/spine system upgrade

Objective: Expand ideas 3 and 4 on top of existing movement timer.

Files to modify:
- movetimer/move_timer.py
- movetimer/MoveTimerPopup.qml
- TopBar.qml

Files to create:
- health/HealthPopup.qml
- /home/amir/.hermes/scripts/health_status.py optional if not folded into hermes_cockpit_status.py

Tasks:
1. Add movement streak stats.
2. Add daily cycles count.
3. Expose health.json.
4. Add CommandDeck health card.
5. Add focus-mode script to start work + movement timers.

Validation:
```bash
python3 ~/.config/hypr/scripts/quickshell/movetimer/move_timer.py status | jq .
python3 ~/.hermes/scripts/hermes_cockpit_status.py health
jq empty ~/.cache/hermes-cockpit/health.json
```

Pass criteria:
- Done returns to focus/work mode.
- Health data contains no raw health note bodies.

---

### Phase 7: Obsidian/project/agent/Innovina widgets

Objective: Implement ideas 6, 10, 11, 12.

Files to create:
- obsidian/ObsidianCockpitPopup.qml
- agents/AgentHudPopup.qml
- devlab/DevLabPopup.qml
- sentinel/SentinelPopup.qml
- /home/amir/.hermes/scripts/agent_activity_status.py optional
- /home/amir/.hermes/scripts/sentinel_mode.py

Files to modify:
- WindowRegistry.js
- CommandDeckPopup.qml
- settings.json optional keybinds

Tasks:
1. Obsidian cockpit: counts + links only.
2. Agent HUD: agent/project/status/counts only, no transcript text.
3. Dev Lab: GitHub/git status and PR/issue summary.
4. Sentinel mode: Innovina dashboard, project next action, timekeeper/work report hooks.

Validation:
```bash
python3 ~/.hermes/scripts/project_cockpit.py --json >/tmp/project_cockpit.json
jq empty /tmp/project_cockpit.json
python3 ~/.hermes/scripts/hermes_cockpit_status.py agents
python3 ~/.hermes/scripts/hermes_cockpit_status.py obsidian
python3 ~/.hermes/scripts/hermes_cockpit_status.py sentinel
```

Pass criteria:
- Widgets show summaries only.
- No raw session transcript/note body/client secrets.

---

### Phase 8: App launcher, terminal profiles, music, system cockpit

Objective: Implement ideas 7, 8, 16, 17.

Files to create:
- commandpalette/CommandPalettePopup.qml
- commandpalette/command_palette.py
- system/SystemCockpitPopup.qml
- musicdeck/MusicDeckPopup.qml or extend music/MusicPopup.qml
- config/hypr/scripts/terminal-profile.sh
- config/kitty/profiles/{default,code,private,admin}.conf

Files to modify:
- WindowRegistry.js
- settings.json
- variables.conf
- CommandDeckPopup.qml

Tasks:
1. Command palette indexes apps/projects/scripts.
2. Terminal profile launcher respects workspace personality.
3. Music status wrapper redacts title/artist in privacy mode.
4. System cockpit shows services/resources without leaking titles/IPs.

Validation:
```bash
python3 commandpalette/command_palette.py | jq .
bash -n ~/.config/hypr/scripts/terminal-profile.sh
~/.config/hypr/scripts/terminal-profile.sh launch --dry-run
python3 ~/.hermes/scripts/hermes_cockpit_status.py system
python3 ~/.hermes/scripts/hermes_cockpit_status.py music
```

Pass criteria:
- No duplicate app launches during dry-run.
- System cockpit avoids full active window titles and IPs.

---

### Phase 9: Aura, theme engine, mascot, lock screen, boot ritual

Objective: Implement ideas 5, 13, 18, 19, 20.

Files to create:
- config/hypr/scripts/aura.sh
- config/hypr/scripts/lock-prep.sh
- config/hypr/scripts/boot-ritual.sh
- boot/BootRitualPopup.qml
- themes/ThemePickerPopup.qml optional
- config/hypr/modes/lock_profiles.json
- /home/amir/.hermes/scripts/boot_to_work.py

Files to modify:
- WallpaperPicker.qml
- init.sh
- matugen_reload.sh
- lock.sh
- Lock.qml
- hypridle.conf
- WindowRegistry.js
- CommandDeckPopup.qml

Tasks:
1. Theme engine switches noir-purple/matrix-green/sentinel-olive/private-red/ocean-cyan.
2. X mascot appears in CommandDeck and optional topbar, mood-driven.
3. Aura changes wallpaper/status colors safely.
4. Lock screen uses lock-prep.sh and avoids screenshot background in privacy mode.
5. Boot ritual runs as dry-run first, then opt-in.

Validation:
```bash
bash -n ~/.config/hypr/scripts/aura.sh
bash -n ~/.config/hypr/scripts/lock-prep.sh
bash -n ~/.config/hypr/scripts/boot-ritual.sh
~/.config/hypr/scripts/lock-prep.sh
test -f /tmp/lock_bg.png && file /tmp/lock_bg.png
python3 ~/.hermes/scripts/boot_to_work.py --dry-run
```

Pass criteria:
- Lock screen still works.
- Privacy lock does not use current sensitive desktop screenshot.
- Boot ritual never auto-sends reports/messages.

---

## Global validation after each phase

```bash
# Repo
cd /home/amir/dotfiles-rice
git status --short
jq empty config/hypr/settings.json
find config/hypr/modes -name '*.json' -print0 | xargs -0 -n1 jq empty
find config/hypr/scripts -name '*.sh' -print0 | xargs -0 -n1 bash -n
find config/hypr/scripts/quickshell -name '*.qml' -print0 | xargs -0 qmllint

# Live after sync
qs -p ~/.config/hypr/scripts/quickshell/Main.qml ipc call main forceReload
qs -p ~/.config/hypr/scripts/quickshell/TopBar.qml ipc call topbar forceReload || true
WAYLAND_DISPLAY=wayland-1 hyprctl reload
```

Visual smoke:
```bash
bash ~/.config/hypr/scripts/qs_manager.sh close all
sleep 1
bash ~/.config/hypr/scripts/qs_manager.sh open commanddeck
sleep 1
cat /tmp/qs_current_widget
WAYLAND_DISPLAY=wayland-1 grim /tmp/hermes-rice/commanddeck-phase.png
```

Privacy smoke:
```bash
~/.config/hypr/scripts/ricectl.sh privacy on
notify-send "SECRET TITLE" "SECRET BODY"
# verify no SECRET appears visually/history
~/.config/hypr/scripts/ricectl.sh privacy off
```

---

## Subagent execution policy

Parallelize only independent tasks:
- Good parallel groups:
  - backend JSON scripts
  - QML shared components
  - docs/plan validation
- Do not parallel-edit the same files:
  - Main.qml
  - TopBar.qml
  - WindowRegistry.js
  - settings.json
  - qs_manager.sh

Per task:
1. Implementer agent edits repo only.
2. Spec reviewer checks against this plan.
3. Quality reviewer checks privacy/QML pitfalls.
4. Parent syncs to live only after validation.
5. Parent captures screenshot and checks logs.
6. Commit and push phase checkpoint.

Suggested phase commits:
- feat: add rice state brain and cockpit cache
- feat: add quickshell popup component kit
- feat: add command deck popup
- feat: harden privacy notification mode
- feat: add workspace personalities and living topbar
- feat: expand health and focus system
- feat: add obsidian agent and sentinel cockpits
- feat: add command palette music and system cockpit
- feat: add aura theme mascot lock and boot ritual

---

## Rollback

Runtime rollback:
```bash
rm -rf "${XDG_RUNTIME_DIR}/hypr-rice"
rm -f ~/.cache/qs_dnd
pkill -f 'quickshell.*Main.qml' || true
pkill -f 'quickshell.*TopBar.qml' || true
quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml &
quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml &
WAYLAND_DISPLAY=wayland-1 hyprctl reload
```

File rollback:
```bash
# replace TIMESTAMP with the backup dir from Gate 0
rm -rf /home/amir/.config/hypr
cp -a /home/amir/.config/rice-backups/TIMESTAMP-xoperator-megaplan/hypr /home/amir/.config/hypr
rm -rf /home/amir/.config/kitty
cp -a /home/amir/.config/rice-backups/TIMESTAMP-xoperator-megaplan/kitty /home/amir/.config/kitty
WAYLAND_DISPLAY=wayland-1 hyprctl reload
```

Repo rollback:
```bash
cd /home/amir/dotfiles-rice
git status --short
git restore config/hypr config/kitty docs/plans
```

Emergency privacy rollback:
```bash
pkill -f 'quickshell.*Main.qml'
# restore Main.qml and NotificationPopups.qml from backup, then restart Main.qml
```

---

## Initial execution recommendation

Start with Phases 1-3 only in the first build sprint:
1. State brain + JSON cache
2. Shared component kit
3. Command Deck MVP

Reason: these create the foundation for all 20 ideas without touching the riskiest parts first. Then implement Privacy Mode immediately after Command Deck before adding more data-rich widgets.

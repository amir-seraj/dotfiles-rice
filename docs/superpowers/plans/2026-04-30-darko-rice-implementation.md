# Darko Rice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a runtime-toggleable Donnie-Darko theme variant alongside the existing monochrome rice, with `theme darko` / `theme mono` switching the entire stack (Hyprland, Quickshell, GTK, Qt, Kvantum, kitty, yazi, lockscreen, idle, wallpapers, SDDM, GRUB, Plymouth) in <1s for live surfaces and on next boot/login for staged surfaces.

**Architecture:** Dual-rice via `~/.config/themes/{mono,darko}/`. Each theme owns its full matugen template set + manifest (icons / cursor / kvantum). A `theme-switch` script flips the `active` symlink, regenerates matugen outputs, signals every live consumer, and stages SDDM/Plymouth/GRUB for next boot. `mono` is a 1:1 capture of the current rice; `darko` is the new work.

**Tech Stack:** bash, matugen (Material You generator), Quickshell (Qt6/QML), Hyprland, hyprlock + hypridle (already running but actual lockscreen is `Lock.qml` Quickshell), kvantummanager, adw-gtk3, Papirus icons, kitty, yazi, SDDM (sugar-candy-style QML), Plymouth (script plugin), GRUB.

**Spec reference:** `docs/superpowers/specs/2026-04-30-darko-rice-design.md`. Two stack corrections from spec: (1) lockscreen layout lives in `Lock.qml` (Quickshell), not `hyprlock.conf`; (2) notification styling lives in Quickshell's `NotificationPopups.qml`, not mako/swaync. Matugen palette propagation handles colors automatically; only Darko-specific layout/text additions need direct file edits.

**Working directory:** `/home/amir/dotfiles-rice` (already a git repo with the upstream rice mirrored). Edits to `~/.config/...` or `~/.local/...` happen on the live system; rsync/save-rice already syncs them into the repo.

---

## File map

### New files

| Path | Purpose |
|---|---|
| `~/.config/themes/mono/seed.txt` | seed source for matugen; `auto` (use wallpaper) or `#hex` |
| `~/.config/themes/mono/manifest.json` | icon / cursor / kvantum / gtk theme names |
| `~/.config/themes/mono/matugen-templates/` | per-theme override copies of all matugen templates |
| `~/.config/themes/mono/wallpapers/` | wallpaper rotation pool for this theme (symlinks ok) |
| `~/.config/themes/mono/lock-overrides.qml` | Lock.qml partial — empty for mono |
| `~/.config/themes/mono/sddm-theme/` | full SDDM theme dir |
| `~/.config/themes/mono/plymouth-theme/` | full Plymouth theme dir |
| `~/.config/themes/mono/grub-theme/` | full GRUB theme dir |
| `~/.config/themes/darko/...` | mirror structure, Darko content |
| `~/.config/themes/active` | symlink → mono\|darko |
| `~/.local/bin/theme-switch` | the switcher (full logic) |
| `~/.local/bin/theme` | symlink → theme-switch |
| `~/.local/bin/darko-countdown.sh` | optional countdown daemon (only if hyprlock/Lock.qml can't compute live) |
| `~/.config/Kvantum/darko-kv/darko-kv.kvconfig` | Darko Kvantum theme |
| `~/.config/Kvantum/darko-kv/darko-kv.svg` | Darko Kvantum SVG assets |
| `~/.config/yazi/theme.toml` | yazi theme (matugen-rendered) |
| `~/.config/matugen/templates/yazi-theme.toml.template` | new matugen template for yazi |
| `~/.icons/Papirus-Darko/` | recolored folder icons for Darko |
| `dotfiles-rice/tests/theme-switch.sh` | smoke test script |

### Modified files

| Path | Change |
|---|---|
| `~/.config/matugen/config.toml` | add yazi-theme template entry; nothing structural changes |
| `~/.config/hypr/scripts/quickshell/Lock.qml` | add countdown widget + "wake up donnie" + "DARKO" wordmark, gated on active theme |
| `~/.config/hypr/hypridle.conf` | add 5s lavender fade pre-screen-off (only when active=darko) |
| `~/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh` | call theme-switch's reload sub-step OR be invoked by it; deduplicate |
| `~/.config/matugen/templates/qs_colors.json.template` | per-theme override copies live in `themes/<name>/matugen-templates/` |
| `/etc/sddm.conf.d/10-wayland-matugen.conf` | flip `Current=` between `darko-sddm` and `matugen-minimal` |
| `/etc/default/grub` | flip `GRUB_THEME=` between paths |
| `/usr/share/sddm/themes/darko-sddm/` | new system-installed Darko SDDM theme |
| `/usr/share/plymouth/themes/darko-boot/` | new Darko Plymouth theme |
| `/boot/grub/themes/darko-grub/` | new Darko GRUB theme |
| `dotfiles-rice/.gitignore` | already has `.superpowers/` |

### Out-of-tree (live system only)

System-owned files in `/usr/share/sddm`, `/usr/share/plymouth`, `/boot/grub` are written directly via sudo by `theme-switch`; we mirror their **source** in `~/.config/themes/<name>/{sddm,plymouth,grub}-theme/` so they're version-controlled in dotfiles-rice.

---

## Phase 0 — Scaffolding

### Task 1: Create theme directory skeletons

**Files:**
- Create: `~/.config/themes/mono/`, `~/.config/themes/darko/`, all subdirs

- [ ] **Step 1: Create directories**

```bash
mkdir -p ~/.config/themes/{mono,darko}/{matugen-templates,wallpapers,sddm-theme,plymouth-theme,grub-theme}
```

- [ ] **Step 2: Verify**

```bash
tree -L 3 ~/.config/themes/
```

Expected: both `mono` and `darko` directory trees present, all subdirs empty.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles-rice
mkdir -p config/themes
rsync -a ~/.config/themes/ config/themes/
git add config/themes/
git commit -m "scaffold: empty theme dirs for dual-rice switcher"
```

### Task 2: Snapshot current configs as `mono`

**Files:**
- Create: `~/.config/themes/mono/seed.txt`, `~/.config/themes/mono/manifest.json`
- Copy into: `~/.config/themes/mono/matugen-templates/` (from `~/.config/matugen/templates/`)

- [ ] **Step 1: Write `mono/seed.txt`**

Write the literal file content (one line, no quotes):

```
auto
```

`auto` means "drive matugen from the current wallpaper" — preserves today's behavior.

- [ ] **Step 2: Write `mono/manifest.json`**

```json
{
  "name": "mono",
  "display_name": "Monochrome",
  "icon_theme": "Papirus-Dark",
  "cursor_theme": "Bibata-Modern-Classic",
  "gtk_theme": "adw-gtk3-dark",
  "kvantum_theme": "kvantum-default",
  "color_scheme": "prefer-dark",
  "matugen_scheme": "scheme-tonal-spot"
}
```

- [ ] **Step 3: Copy matugen templates into mono/**

```bash
cp -r ~/.config/matugen/templates/. ~/.config/themes/mono/matugen-templates/
ls ~/.config/themes/mono/matugen-templates/
```

Expected: 14 `*.template` files listed.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles-rice
rsync -a --exclude='.git' ~/.config/themes/ config/themes/
git add config/themes/mono/
git commit -m "snapshot current rice as mono theme variant"
```

### Task 3: Write `theme-switch` v0 (symlink-only, no reload)

**Files:**
- Create: `~/.local/bin/theme-switch`

- [ ] **Step 1: Write the script**

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/theme-switch <<'EOF'
#!/usr/bin/env bash
# theme-switch — flip the active rice theme symlink.
# Usage: theme-switch <mono|darko>
#        theme-switch              # report current
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
ACTIVE="$THEMES_DIR/active"

if [[ $# -eq 0 ]]; then
    if [[ -L "$ACTIVE" ]]; then
        echo "active: $(basename "$(readlink "$ACTIVE")")"
    else
        echo "active: <none — run 'theme-switch mono' or 'theme-switch darko'>"
    fi
    exit 0
fi

target="$1"
target_dir="$THEMES_DIR/$target"

if [[ ! -d "$target_dir" ]]; then
    echo "error: $target_dir does not exist" >&2
    exit 1
fi

ln -sfn "$target" "$ACTIVE"
echo "active: $target"
EOF
chmod +x ~/.local/bin/theme-switch
```

- [ ] **Step 2: Symlink `theme` shorthand**

```bash
ln -sfn theme-switch ~/.local/bin/theme
```

- [ ] **Step 3: Verify it's on PATH**

```bash
which theme-switch && which theme
```

Expected: both resolve to `~/.local/bin/...`. If not, add `~/.local/bin` to PATH first via `~/.zshrc`.

- [ ] **Step 4: Test the basic flip**

```bash
theme-switch mono && theme
```

Expected output: `active: mono`.

```bash
theme-switch darko 2>&1 || true
```

Expected: error because `darko/` is empty-but-exists. Actually since it's a directory, this succeeds. So:

```bash
theme-switch nonexistent
```

Expected: `error: /home/amir/.config/themes/nonexistent does not exist` and exit 1.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-rice
mkdir -p local/bin
cp ~/.local/bin/theme-switch local/bin/
git add local/bin/theme-switch
git commit -m "add theme-switch v0 (symlink-only, no reload yet)"
```

### Task 4: Write smoke test scaffold

**Files:**
- Create: `dotfiles-rice/tests/theme-switch.sh`

- [ ] **Step 1: Write the test harness**

```bash
mkdir -p ~/dotfiles-rice/tests
cat > ~/dotfiles-rice/tests/theme-switch.sh <<'EOF'
#!/usr/bin/env bash
# Smoke tests for theme-switch. Run from anywhere.
# Each `assert` line prints PASS/FAIL with the test name.
set -uo pipefail

failed=0
assert() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name  ($*)"
        failed=$((failed + 1))
    fi
}
assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "PASS  $name"
    else
        echo "FAIL  $name  expected=$expected got=$actual"
        failed=$((failed + 1))
    fi
}

# --- Phase 0 tests ---
assert "theme-switch on PATH" command -v theme-switch
assert "themes dir exists" test -d "$HOME/.config/themes"
assert "mono dir exists" test -d "$HOME/.config/themes/mono"
assert "darko dir exists" test -d "$HOME/.config/themes/darko"

theme-switch mono >/dev/null
active=$(basename "$(readlink "$HOME/.config/themes/active")")
assert_eq "active==mono after switch" mono "$active"

# --- summary ---
echo
if [[ $failed -eq 0 ]]; then
    echo "all passed"
    exit 0
else
    echo "$failed failed"
    exit 1
fi
EOF
chmod +x ~/dotfiles-rice/tests/theme-switch.sh
```

- [ ] **Step 2: Run the test**

```bash
~/dotfiles-rice/tests/theme-switch.sh
```

Expected: 5 PASS lines, exit 0.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles-rice
git add tests/theme-switch.sh
git commit -m "test: phase-0 smoke tests for theme-switch scaffolding"
```

---

## Phase 1 — Palette plumbing

### Task 5: Stub `darko` theme dir as a mono clone

**Files:**
- Copy: `~/.config/themes/mono/` → `~/.config/themes/darko/`

- [ ] **Step 1: Clone**

```bash
cp -r ~/.config/themes/mono/. ~/.config/themes/darko/
ls ~/.config/themes/darko/matugen-templates/ | wc -l
```

Expected: `14` (or whatever mono had).

- [ ] **Step 2: Verify smoke test still works on switch**

```bash
~/dotfiles-rice/tests/theme-switch.sh
theme-switch darko && theme
theme-switch mono
```

Expected: `active: darko` then `active: mono`.

### Task 6: Write `darko/seed.txt` and `darko/manifest.json`

**Files:**
- Create: `~/.config/themes/darko/seed.txt`
- Create: `~/.config/themes/darko/manifest.json` (overwrite the mono clone)

- [ ] **Step 1: Write seed**

```bash
echo '#7a4a8a' > ~/.config/themes/darko/seed.txt
```

(`#7a4a8a` = portal magenta primary seed from spec.)

- [ ] **Step 2: Write manifest**

```bash
cat > ~/.config/themes/darko/manifest.json <<'EOF'
{
  "name": "darko",
  "display_name": "Donnie Darko",
  "icon_theme": "Papirus-Darko",
  "cursor_theme": "Bibata-Modern-Classic",
  "gtk_theme": "adw-gtk3-dark",
  "kvantum_theme": "darko-kv",
  "color_scheme": "prefer-dark",
  "matugen_scheme": "scheme-tonal-spot",
  "countdown_end": "2026-05-28T06:42:12+02:00"
}
EOF
```

- [ ] **Step 3: Verify with jq**

```bash
jq . ~/.config/themes/darko/manifest.json
```

Expected: pretty-printed JSON, no errors.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles-rice
rsync -a --exclude='.git' ~/.config/themes/darko/ config/themes/darko/
git add config/themes/darko/
git commit -m "scaffold darko theme dir with portal-magenta seed"
```

### Task 7: Override `darko/matugen-templates/qs_colors.json.template` to break the unified-grey

The current `qs_colors.json.template` (mono behavior) collapses blue/peach/mauve/pink/sapphire/teal/green all to `secondary_container`. For Darko we want each role to get its own distinct chroma so accents (magenta border, sodium-amber urgent) actually show through.

**Files:**
- Modify: `~/.config/themes/darko/matugen-templates/qs_colors.json.template`

- [ ] **Step 1: Read the existing mono template**

```bash
cat ~/.config/themes/darko/matugen-templates/qs_colors.json.template
```

You'll see lines like `"blue": "{{colors.secondary_container.default.hex}}"` repeated for every accent. Note the current file structure — we'll overwrite it.

- [ ] **Step 2: Write the Darko template**

Replace the template contents with this (keeps the mocha-named keys Quickshell expects, but maps each to a distinct M3 role so colors actually differentiate):

```json
{
  "base": "{{colors.surface.default.hex}}",
  "mantle": "{{colors.surface_dim.default.hex}}",
  "crust": "{{colors.surface_container_lowest.default.hex}}",
  "text": "{{colors.on_surface.default.hex}}",
  "subtext0": "{{colors.on_surface_variant.default.hex}}",
  "subtext1": "{{colors.on_surface_variant.default.hex}}",
  "overlay0": "{{colors.outline_variant.default.hex}}",
  "overlay1": "{{colors.outline_variant.default.hex}}",
  "overlay2": "{{colors.outline.default.hex}}",
  "surface0": "{{colors.surface_container_low.default.hex}}",
  "surface1": "{{colors.surface_container.default.hex}}",
  "surface2": "{{colors.surface_container_high.default.hex}}",
  "blue": "{{colors.primary.default.hex}}",
  "lavender": "{{colors.primary.default.hex}}",
  "sapphire": "{{colors.primary.default.hex}}",
  "sky": "{{colors.tertiary.default.hex}}",
  "teal": "{{colors.tertiary.default.hex}}",
  "green": "{{colors.tertiary.default.hex}}",
  "yellow": "{{colors.secondary.default.hex}}",
  "peach": "{{colors.secondary.default.hex}}",
  "maroon": "{{colors.error.default.hex}}",
  "red": "{{colors.error.default.hex}}",
  "mauve": "{{colors.primary_container.default.hex}}",
  "pink": "{{colors.primary_container.default.hex}}",
  "flamingo": "{{colors.primary_fixed.default.hex}}",
  "rosewater": "{{colors.primary_fixed_dim.default.hex}}"
}
```

- [ ] **Step 3: Override `darko/matugen-templates/hyprland.conf.template`**

In the mono version, active border is hardcoded to `rgba(ffae42ff)` (mango). Replace with portal magenta:

```bash
# Find the existing line
grep -n 'active_border' ~/.config/themes/darko/matugen-templates/hyprland.conf.template
```

Edit the file so the active-border line reads:

```
$active_border = rgba(7a4a8aff)
```

If the file uses a different mechanism (e.g., `general:col.active_border = ...`), replace that color with `rgba(7a4a8aff)` plus any glow setting. Keep the rest of the file unchanged.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles-rice
rsync -a --exclude='.git' ~/.config/themes/darko/matugen-templates/ config/themes/darko/matugen-templates/
git add config/themes/darko/matugen-templates/
git commit -m "darko: distinct color roles + portal-magenta active border"
```

### Task 8: Add the matugen-render step to `theme-switch`

**Files:**
- Modify: `~/.local/bin/theme-switch`

- [ ] **Step 1: Replace the script with v1 (palette-aware)**

Overwrite `~/.local/bin/theme-switch` with:

```bash
cat > ~/.local/bin/theme-switch <<'EOF'
#!/usr/bin/env bash
# theme-switch — flip the active rice theme and regenerate matugen outputs.
# Usage: theme-switch <mono|darko>
#        theme-switch                # report current
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
ACTIVE="$THEMES_DIR/active"
MATUGEN_TEMPLATES="$HOME/.config/matugen/templates"

if [[ $# -eq 0 ]]; then
    if [[ -L "$ACTIVE" ]]; then
        echo "active: $(basename "$(readlink "$ACTIVE")")"
    else
        echo "active: <none>"
    fi
    exit 0
fi

target="$1"
target_dir="$THEMES_DIR/$target"
[[ -d "$target_dir" ]] || { echo "error: $target_dir does not exist" >&2; exit 1; }

# 1. flip active symlink
ln -sfn "$target" "$ACTIVE"

# 2. swap matugen templates: backup originals once, then symlink the active set.
if [[ ! -L "$MATUGEN_TEMPLATES" ]] && [[ ! -d "$MATUGEN_TEMPLATES.orig" ]]; then
    mv "$MATUGEN_TEMPLATES" "$MATUGEN_TEMPLATES.orig"
fi
ln -sfn "$ACTIVE/matugen-templates" "$MATUGEN_TEMPLATES"

# 3. regenerate via matugen using the theme's seed
seed="$(cat "$ACTIVE/seed.txt")"
scheme="$(jq -r '.matugen_scheme // "scheme-tonal-spot"' "$ACTIVE/manifest.json")"

if [[ "$seed" == "auto" ]]; then
    # use current wallpaper. Find it from awww or first file in active wallpapers/.
    wallpaper="$(awww query 2>/dev/null | head -1 | awk '{print $NF}' || true)"
    [[ -z "$wallpaper" ]] && wallpaper="$(ls "$ACTIVE/wallpapers/"*.{jpg,png,webp} 2>/dev/null | head -1)"
    [[ -n "$wallpaper" && -f "$wallpaper" ]] || { echo "error: seed=auto but no wallpaper found" >&2; exit 1; }
    matugen image "$wallpaper" -t "$scheme"
else
    matugen color hex "$seed" -t "$scheme"
fi

# 4. run the existing post-process / live-reload helper
~/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh

echo "active: $target  (matugen rendered, live surfaces reloaded)"
EOF
chmod +x ~/.local/bin/theme-switch
```

- [ ] **Step 2: Save mono's current seed-source**

If you currently use a wallpaper-driven palette, `mono/seed.txt` should stay `auto`. If you'd rather lock mono to a specific seed, change to a hex now. For this plan: keep `auto`.

- [ ] **Step 3: Test mono → darko → mono cycle**

```bash
theme-switch mono
# Expected: matugen runs from current wallpaper, no visible change.
theme-switch darko
# Expected: hyprland border turns portal magenta, kitty repaints, TopBar accents shift.
theme-switch mono
# Expected: rice returns to monochrome.
```

If matugen errors with "templates dir not found", check the symlink: `ls -la ~/.config/matugen/templates`.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles-rice
cp ~/.local/bin/theme-switch local/bin/
git add local/bin/theme-switch
git commit -m "theme-switch v1: matugen render from active theme seed"
```

### Task 9: Extend smoke test to cover Phase 1

**Files:**
- Modify: `dotfiles-rice/tests/theme-switch.sh`

- [ ] **Step 1: Append checks**

After the existing `# --- Phase 0 tests ---` block (before the summary), insert:

```bash
# --- Phase 1 tests ---
assert "matugen templates is a symlink" test -L "$HOME/.config/matugen/templates"

theme-switch mono >/dev/null
linked=$(readlink "$HOME/.config/matugen/templates")
assert_eq "templates -> mono after switch" "$HOME/.config/themes/active/matugen-templates" "$linked"

# darko render produces portal-magenta active border
theme-switch darko >/dev/null
border=$(grep -E '^\$active_border' "$HOME/.config/hypr/colors.conf" 2>/dev/null | grep -oE '[0-9a-f]{6,8}' | head -1 || true)
assert "darko active border contains 7a4a8a" test "${border,,}" = "7a4a8aff"

# mono render restores something else (anything but 7a4a8a)
theme-switch mono >/dev/null
border=$(grep -E '^\$active_border' "$HOME/.config/hypr/colors.conf" 2>/dev/null | grep -oE '[0-9a-f]{6,8}' | head -1 || true)
assert "mono active border != darko" test "${border,,}" != "7a4a8aff"
```

- [ ] **Step 2: Run**

```bash
~/dotfiles-rice/tests/theme-switch.sh
```

Expected: all pass. If "darko active border contains 7a4a8a" fails, check that Task 7 Step 3 actually wrote the hex into the template.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles-rice
git add tests/theme-switch.sh
git commit -m "test: phase-1 palette-render smoke checks"
```

### Task 10: Visual checkpoint (manual)

- [ ] **Step 1: Verify visually**

Run `theme-switch darko`. With your eyes, confirm:
- Hyprland active border is portal magenta (`#7a4a8a`)
- TopBar accent text/icons are sodium amber (`#f5a040`-ish)
- Kitty repainted (open a new kitty window if needed)
- Notifications (trigger one with `notify-send "test"`) show in cosmic-blue/lavender
- Lock.qml not yet customized — still mono-styled lockscreen, but colors should be darko-leaning

If anything's wrong, debug before proceeding. **This is the brainstorming-spec checkpoint** — surface a screenshot if you want to share progress before phases 2+.

- [ ] **Step 2: Switch back**

```bash
theme-switch mono
```

Confirm rice returns to current monochrome look exactly.

---

## Phase 2 — Qt + Kvantum + GTK + yazi

### Task 11: Install yazi

- [ ] **Step 1: Install via pacman**

```bash
sudo pacman -S --needed yazi
yazi --version
```

Expected: yazi version output.

### Task 12: Add yazi matugen template

**Files:**
- Create: `~/.config/matugen/templates/yazi-theme.toml.template`
- Modify: `~/.config/matugen/config.toml`

- [ ] **Step 1: Write the matugen template**

```bash
cat > ~/.config/matugen/templates/yazi-theme.toml.template <<'EOF'
[manager]
cwd = { fg = "{{colors.primary.default.hex}}" }
hovered = { fg = "{{colors.on_surface.default.hex}}", bg = "{{colors.surface_container_high.default.hex}}" }
preview_hovered = { underline = true }
find_keyword = { fg = "{{colors.secondary.default.hex}}", italic = true }
find_position = { fg = "{{colors.secondary.default.hex}}", bg = "reset", italic = true }
marker_copied = { fg = "{{colors.tertiary.default.hex}}", bg = "{{colors.tertiary.default.hex}}" }
marker_cut = { fg = "{{colors.error.default.hex}}", bg = "{{colors.error.default.hex}}" }
marker_marked = { fg = "{{colors.primary.default.hex}}", bg = "{{colors.primary.default.hex}}" }
marker_selected = { fg = "{{colors.primary.default.hex}}", bg = "{{colors.primary.default.hex}}" }
tab_active = { fg = "{{colors.on_primary.default.hex}}", bg = "{{colors.primary.default.hex}}" }
tab_inactive = { fg = "{{colors.on_surface_variant.default.hex}}", bg = "{{colors.surface_container.default.hex}}" }
border_symbol = "│"
border_style = { fg = "{{colors.outline.default.hex}}" }

[status]
separator_open = ""
separator_close = ""
separator_style = { fg = "{{colors.surface_container.default.hex}}", bg = "{{colors.surface_container.default.hex}}" }
mode_normal = { fg = "{{colors.on_primary.default.hex}}", bg = "{{colors.primary.default.hex}}", bold = true }
mode_select = { fg = "{{colors.on_secondary.default.hex}}", bg = "{{colors.secondary.default.hex}}", bold = true }
mode_unset  = { fg = "{{colors.on_error.default.hex}}",  bg = "{{colors.error.default.hex}}",  bold = true }
progress_label = { fg = "{{colors.on_surface.default.hex}}", bold = true }
progress_normal = { fg = "{{colors.primary.default.hex}}", bg = "{{colors.surface_container.default.hex}}" }
progress_error  = { fg = "{{colors.error.default.hex}}",   bg = "{{colors.surface_container.default.hex}}" }
permissions_t = { fg = "{{colors.primary.default.hex}}" }
permissions_r = { fg = "{{colors.secondary.default.hex}}" }
permissions_w = { fg = "{{colors.error.default.hex}}" }
permissions_x = { fg = "{{colors.tertiary.default.hex}}" }
permissions_s = { fg = "{{colors.outline.default.hex}}" }

[input]
border = { fg = "{{colors.primary.default.hex}}" }
title = {}
value = {}
selected = { reversed = true }

[select]
border = { fg = "{{colors.primary.default.hex}}" }
active = { fg = "{{colors.secondary.default.hex}}" }
inactive = {}

[tasks]
border = { fg = "{{colors.primary.default.hex}}" }
title = {}
hovered = { underline = true }

[which]
mask = { bg = "{{colors.surface_dim.default.hex}}" }
cand = { fg = "{{colors.primary.default.hex}}" }
rest = { fg = "{{colors.on_surface_variant.default.hex}}" }
desc = { fg = "{{colors.secondary.default.hex}}" }
separator = "  "
separator_style = { fg = "{{colors.outline.default.hex}}" }

[help]
on = { fg = "{{colors.secondary.default.hex}}" }
exec = { fg = "{{colors.primary.default.hex}}" }
desc = { fg = "{{colors.on_surface_variant.default.hex}}" }
hovered = { bg = "{{colors.surface_container_high.default.hex}}", bold = true }
footer = { fg = "{{colors.on_surface.default.hex}}", bg = "{{colors.surface_container.default.hex}}" }

[filetype]
rules = [
    { mime = "image/*", fg = "{{colors.tertiary.default.hex}}" },
    { mime = "video/*", fg = "{{colors.secondary.default.hex}}" },
    { mime = "audio/*", fg = "{{colors.secondary.default.hex}}" },
    { mime = "application/pdf", fg = "{{colors.error.default.hex}}" },
    { mime = "application/zip", fg = "{{colors.primary.default.hex}}" },
    { name = "*/", fg = "{{colors.primary.default.hex}}" },
]
EOF
```

- [ ] **Step 2: Append the template entry to matugen config.toml**

Append to `~/.config/matugen/config.toml`:

```toml
[templates.yazi]
input_path = "~/.config/matugen/templates/yazi-theme.toml.template"
output_path = "~/.config/yazi/theme.toml"
```

- [ ] **Step 3: Mirror the template into both theme dirs**

```bash
cp ~/.config/matugen/templates/yazi-theme.toml.template ~/.config/themes/mono/matugen-templates/
cp ~/.config/matugen/templates/yazi-theme.toml.template ~/.config/themes/darko/matugen-templates/
mkdir -p ~/.config/yazi
```

- [ ] **Step 4: Test**

```bash
theme-switch darko
yazi  # opens TUI; check colors are cosmic
# q to quit
theme-switch mono
yazi  # check colors return to mono
```

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-rice
rsync -a --exclude='.git' ~/.config/matugen/ config/matugen/
rsync -a ~/.config/themes/ config/themes/
git add config/matugen/ config/themes/
git commit -m "yazi: matugen-driven theme, mirror into both rice variants"
```

### Task 13: Build the `darko-kv` Kvantum theme

**Files:**
- Create: `~/.config/Kvantum/darko-kv/darko-kv.kvconfig`
- Create: `~/.config/Kvantum/darko-kv/darko-kv.svg`

- [ ] **Step 1: Find a base Kvantum theme to derive from**

```bash
ls /usr/share/Kvantum/ 2>/dev/null
```

Pick a dark theme as base — `KvDark` or `KvAdaptaDark` typically ship. We'll copy it and recolor.

```bash
sudo cp -r /usr/share/Kvantum/KvDark ~/.config/Kvantum/darko-kv 2>/dev/null \
    || sudo cp -r /usr/share/Kvantum/KvAdaptaDark ~/.config/Kvantum/darko-kv \
    || { echo "error: pick a base theme manually"; exit 1; }
sudo chown -R $USER:$USER ~/.config/Kvantum/darko-kv
mv ~/.config/Kvantum/darko-kv/KvDark.kvconfig ~/.config/Kvantum/darko-kv/darko-kv.kvconfig 2>/dev/null \
    || mv ~/.config/Kvantum/darko-kv/KvAdaptaDark.kvconfig ~/.config/Kvantum/darko-kv/darko-kv.kvconfig 2>/dev/null
mv ~/.config/Kvantum/darko-kv/KvDark.svg ~/.config/Kvantum/darko-kv/darko-kv.svg 2>/dev/null \
    || mv ~/.config/Kvantum/darko-kv/KvAdaptaDark.svg ~/.config/Kvantum/darko-kv/darko-kv.svg 2>/dev/null
```

- [ ] **Step 2: Recolor `.kvconfig`**

Open `~/.config/Kvantum/darko-kv/darko-kv.kvconfig`. Find the `[GeneralColors]` section and replace with:

```ini
[GeneralColors]
window.color=#1c2440
base.color=#0a0e1a
alt.base.color=#1c2440
button.color=#2a2050
light.color=#4a3870
mid.light.color=#2a2050
dark.color=#0a0e1a
mid.color=#1c2440
highlight.color=#7a4a8a
inactive.highlight.color=#4a3870
text.color=#b4a8e8
window.text.color=#b4a8e8
button.text.color=#e8dfff
disabled.text.color=#7a8aa0
tooltip.text.color=#0a0e1a
highlight.text.color=#0a0e1a
link.color=#f5a040
link.visited.color=#c4506a
```

Save.

- [ ] **Step 3: Apply via kvantummanager**

```bash
kvantummanager --set darko-kv
```

Open Dolphin (`dolphin &`); confirm cosmic-blue chrome. Close Dolphin.

- [ ] **Step 4: Set up mono fallback**

The mono variant uses Kvantum default. Ensure manifest reflects this:

```bash
jq '.kvantum_theme' ~/.config/themes/mono/manifest.json
# expected: "kvantum-default"
```

If you'd rather mono use a specific Kvantum theme, change manifest now and `kvantummanager --set <name>` to verify it exists.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/Kvantum/darko-kv/ config/Kvantum/darko-kv/
git add config/Kvantum/darko-kv/
git commit -m "darko: custom Kvantum theme darko-kv (cosmic blues + portal magenta highlight)"
```

### Task 14: Wire Kvantum + GTK + cursor + icon-theme into `theme-switch`

**Files:**
- Modify: `~/.local/bin/theme-switch`

- [ ] **Step 1: Replace the script with v2**

```bash
cat > ~/.local/bin/theme-switch <<'EOF'
#!/usr/bin/env bash
# theme-switch — flip the active rice theme.
# Usage: theme-switch <mono|darko>
#        theme-switch                # report current
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
ACTIVE="$THEMES_DIR/active"
MATUGEN_TEMPLATES="$HOME/.config/matugen/templates"

if [[ $# -eq 0 ]]; then
    if [[ -L "$ACTIVE" ]]; then
        echo "active: $(basename "$(readlink "$ACTIVE")")"
    else
        echo "active: <none>"
    fi
    exit 0
fi

target="$1"
target_dir="$THEMES_DIR/$target"
[[ -d "$target_dir" ]] || { echo "error: $target_dir does not exist" >&2; exit 1; }
manifest="$target_dir/manifest.json"
[[ -f "$manifest" ]] || { echo "error: $manifest missing" >&2; exit 1; }

# 1. flip active symlink
ln -sfn "$target" "$ACTIVE"

# 2. swap matugen templates
if [[ ! -L "$MATUGEN_TEMPLATES" ]] && [[ ! -d "$MATUGEN_TEMPLATES.orig" ]]; then
    mv "$MATUGEN_TEMPLATES" "$MATUGEN_TEMPLATES.orig"
fi
ln -sfn "$ACTIVE/matugen-templates" "$MATUGEN_TEMPLATES"

# 3. matugen render
seed="$(cat "$ACTIVE/seed.txt")"
scheme="$(jq -r '.matugen_scheme // "scheme-tonal-spot"' "$manifest")"
if [[ "$seed" == "auto" ]]; then
    wallpaper="$(awww query 2>/dev/null | head -1 | awk '{print $NF}' || true)"
    [[ -z "$wallpaper" ]] && wallpaper="$(ls "$ACTIVE/wallpapers/"*.{jpg,png,webp} 2>/dev/null | head -1 || true)"
    [[ -n "$wallpaper" && -f "$wallpaper" ]] || { echo "warn: seed=auto but no wallpaper; using fixed darko fallback" >&2; matugen color hex '#7a4a8a' -t "$scheme"; }
    [[ -n "$wallpaper" && -f "$wallpaper" ]] && matugen image "$wallpaper" -t "$scheme"
else
    matugen color hex "$seed" -t "$scheme"
fi

# 4. matugen post-process + reloads (kitty, cava, swayosd, gtk live-reload)
~/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh

# 5. apply manifest settings
icon="$(jq -r '.icon_theme' "$manifest")"
cursor="$(jq -r '.cursor_theme' "$manifest")"
gtk="$(jq -r '.gtk_theme' "$manifest")"
kvantum="$(jq -r '.kvantum_theme' "$manifest")"
scheme_pref="$(jq -r '.color_scheme' "$manifest")"

gsettings set org.gnome.desktop.interface icon-theme "$icon" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme "$gtk" 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme "$scheme_pref" 2>/dev/null || true

# Hyprctl: cursor lives here too
hyprctl setcursor "$cursor" 24 2>/dev/null || true

# Kvantum: only set if not "kvantum-default"
if [[ "$kvantum" != "kvantum-default" && "$kvantum" != "null" ]]; then
    kvantummanager --set "$kvantum" 2>/dev/null || true
fi

# 6. relaunch any running Dolphin so it picks up Kvantum
if pgrep -x dolphin >/dev/null; then
    pkill -x dolphin || true
    (sleep 0.3; dolphin >/dev/null 2>&1 &) >/dev/null 2>&1 || true
fi

# 7. reload Hyprland
hyprctl reload >/dev/null 2>&1 || true

echo "active: $target  (live surfaces reloaded; sddm/plymouth/grub via Phase 5 staging)"
EOF
chmod +x ~/.local/bin/theme-switch
```

- [ ] **Step 2: Test full Phase-2 cycle**

```bash
theme-switch darko
gsettings get org.gnome.desktop.interface icon-theme  # 'Papirus-Darko'
gsettings get org.gnome.desktop.interface cursor-theme  # 'Bibata-Modern-Classic'
theme-switch mono
gsettings get org.gnome.desktop.interface icon-theme  # 'Papirus-Dark'
```

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles-rice
cp ~/.local/bin/theme-switch local/bin/
git add local/bin/theme-switch
git commit -m "theme-switch v2: apply manifest (icons, cursor, gtk, kvantum) on switch"
```

### Task 15: Set up Papirus-Darko icon override dir

`Papirus-Darko` is a recolored fork. We use Papirus's built-in `papirus-folders` if available, else fall back to a 30-icon override directory copied from Papirus-Dark and tinted via ImageMagick.

**Files:**
- Create: `~/.icons/Papirus-Darko/index.theme`
- Optional: `~/.icons/Papirus-Darko/symlinks/` farming Papirus-Dark, with violet-tinted folder PNGs overriding.

- [ ] **Step 1: Try the easy path**

```bash
command -v papirus-folders && papirus-folders -l
```

If `papirus-folders` exists and lists a `violet` color, the easy path works:

```bash
sudo papirus-folders -C violet --theme Papirus-Dark
```

Then point Darko at it by editing `darko/manifest.json`:

```json
"icon_theme": "Papirus-Dark",
```

(re-using Papirus-Dark, but its folders are now violet system-wide). Skip to Step 4. **Caveat:** this is global — switching to mono won't restore the old folder color unless we run `papirus-folders -C teal` (or whatever) on every mono switch.

To make it theme-switch-aware, encode the folder color in manifest:

```json
"papirus_folders_color": "violet"   // for darko
"papirus_folders_color": "yellow"   // for mono (or whatever the default was)
```

Then add to `theme-switch` Step 5 (manifest application):

```bash
pf_color="$(jq -r '.papirus_folders_color // empty' "$manifest")"
if [[ -n "$pf_color" ]] && command -v papirus-folders >/dev/null; then
    sudo -n papirus-folders -C "$pf_color" --theme Papirus-Dark 2>/dev/null \
        || papirus-folders -C "$pf_color" --theme Papirus-Dark 2>/dev/null || true
fi
```

This needs sudo or NOPASSWD; document that in CLAUDE.md.

- [ ] **Step 2: Fallback — manual override theme**

If `papirus-folders` isn't available or `violet` isn't a built-in color:

```bash
mkdir -p ~/.icons/Papirus-Darko
cat > ~/.icons/Papirus-Darko/index.theme <<'EOF'
[Icon Theme]
Name=Papirus-Darko
Inherits=Papirus-Dark
EOF
```

This is enough for `gsettings set icon-theme Papirus-Darko` to resolve — it'll inherit Papirus-Dark with no overrides. To actually tint folders, drop violet-tinted PNGs into `~/.icons/Papirus-Darko/<size>/places/`. **Defer the tinting to Phase 6 polish** unless you want to spend an hour on ImageMagick — out of scope for this plan.

- [ ] **Step 3: Update manifest if using fallback**

If you're on the fallback path:

```bash
# already correct — manifest says Papirus-Darko, which inherits Papirus-Dark
jq '.icon_theme' ~/.config/themes/darko/manifest.json
# expected: "Papirus-Darko"
```

- [ ] **Step 4: Test**

```bash
theme-switch darko
gsettings get org.gnome.desktop.interface icon-theme
# 'Papirus-Darko' (or 'Papirus-Dark' if Step 1 path)
```

Open Nautilus or Dolphin; folder colors should look (subtly) different. If they don't, that's expected for the fallback path — the inheritance theme has no overrides yet.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-rice
mkdir -p local/icons
[[ -d ~/.icons/Papirus-Darko ]] && rsync -a ~/.icons/Papirus-Darko/ local/icons/Papirus-Darko/
git add local/icons/ config/themes/
git commit -m "icons: papirus-darko inheritance theme stub"
```

---

## Phase 3 — Lockscreen + idle

### Task 16: Add Darko motifs to `Lock.qml`

The existing `Lock.qml` already uses MatugenColors for its palette, so colors flip automatically when matugen regenerates. We need to **add** the Darko-specific elements (DARKO wordmark, countdown, "wake up donnie") gated on the active theme name.

**Files:**
- Modify: `~/.config/hypr/scripts/quickshell/Lock.qml`

- [ ] **Step 1: Read the current Lock.qml fully**

```bash
wc -l ~/.config/hypr/scripts/quickshell/Lock.qml
sed -n '1,80p' ~/.config/hypr/scripts/quickshell/Lock.qml
```

Identify where the password input + clock are rendered.

- [ ] **Step 2: Add a top-level theme-name property**

Near the top of `ShellRoot {`, after the existing theme color readonlys, add:

```qml
readonly property string activeTheme: {
    var f = "~/.config/themes/active"
    // resolve symlink target name; Quickshell's Quickshell.Io can read files but not readlink.
    // Easiest: read a single-line file we keep updated alongside the symlink.
    return Quickshell.env("DARKO_THEME") || "mono"
}
```

We also need `theme-switch` to export this for Quickshell to read. **Update `theme-switch` Step 1 (after the symlink flip) to also write `~/.config/themes/active.name`:**

In `~/.local/bin/theme-switch`, after the `ln -sfn "$target" "$ACTIVE"` line, add:

```bash
echo "$target" > "$THEMES_DIR/active.name"
```

And in `Lock.qml`, replace the property with:

```qml
readonly property string activeTheme: {
    try {
        // Read the file synchronously via Quickshell.Io.FileView if available;
        // else fall back to env var.
        return Qt.application.name === "" ? "" : ""  // placeholder
    } catch (e) { return "mono" }
}
```

Actually simpler: use a `Quickshell.Io.FileView` component synchronously (inline-loaded). If your Quickshell version doesn't support sync FileView, keep the env var path and have `~/.config/hypr/scripts/lock.sh` export `DARKO_THEME` from `~/.config/themes/active.name` before launching:

Edit `~/.config/hypr/scripts/lock.sh`:

```bash
#!/usr/bin/env bash
export DARKO_THEME="$(cat ~/.config/themes/active.name 2>/dev/null || echo mono)"
quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
```

Now `Quickshell.env("DARKO_THEME")` returns the right value at lock time.

- [ ] **Step 3: Add the Darko-only widgets**

Inside the `ShellRoot { ... }` body of `Lock.qml`, **inside the main visual area** (find where the clock/password is rendered — likely a `Item` or `Column`), add:

```qml
// Darko-only flourishes — visible when activeTheme == "darko"
Item {
    anchors.fill: parent
    visible: root.activeTheme === "darko"

    // "DARKO" wordmark — top of clock area
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -160
        text: "DARKO"
        font.family: "serif"
        font.pixelSize: 14
        font.letterSpacing: 8
        color: root.text
        opacity: 0.5
    }

    // Countdown widget
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 220
        width: 320
        height: 60

        Text {
            id: countdownLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: "END OF THE WORLD IN"
            font.family: "monospace"
            font.pixelSize: 11
            font.letterSpacing: 3
            color: root.peach   // sodium amber via matugen
            opacity: 0.7
        }

        Text {
            id: countdownValue
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: countdownLabel.bottom
            anchors.topMargin: 6
            text: "00:00:00:00"
            font.family: "monospace"
            font.pixelSize: 32
            font.letterSpacing: 8
            color: root.peach

            Timer {
                interval: 1000
                running: parent.parent.parent.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: countdownValue.text = root.computeCountdown()
            }
        }
    }

    // "wake up donnie" — above password input
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 130
        text: "— wake up, donnie —"
        font.family: "serif"
        font.italic: true
        font.pixelSize: 24
        font.letterSpacing: 4
        color: root.text
        opacity: 0.85
    }
}

// Property: end-date string read from manifest (default 28d6h42m12s ahead)
readonly property string countdownEnd: Quickshell.env("DARKO_COUNTDOWN_END") || "2026-05-28T06:42:12+02:00"

function computeCountdown() {
    var now = new Date();
    var end = new Date(root.countdownEnd);
    var diff = Math.max(0, Math.floor((end - now) / 1000));
    if (diff === 0) {
        // loop: end-date 28d6h42m12s in the future
        end = new Date(now.getTime() + (28*86400 + 6*3600 + 42*60 + 12) * 1000);
        diff = Math.floor((end - now) / 1000);
    }
    var days = Math.floor(diff / 86400); diff %= 86400;
    var hrs = Math.floor(diff / 3600); diff %= 3600;
    var mins = Math.floor(diff / 60); var secs = diff % 60;
    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    return pad(days) + ":" + pad(hrs) + ":" + pad(mins) + ":" + pad(secs);
}
```

Place the function alongside other JS functions inside `ShellRoot`. The `parent.parent.parent.visible` chain in the Timer accesses the Item's `visible` — confirm by checking the parent chain when you paste; adjust depth if your nesting differs.

- [ ] **Step 4: Pass DARKO_COUNTDOWN_END through lock.sh**

Edit `~/.config/hypr/scripts/lock.sh`:

```bash
#!/usr/bin/env bash
export DARKO_THEME="$(cat ~/.config/themes/active.name 2>/dev/null || echo mono)"
if [[ "$DARKO_THEME" == "darko" ]]; then
    export DARKO_COUNTDOWN_END="$(jq -r '.countdown_end // "2026-05-28T06:42:12+02:00"' ~/.config/themes/active/manifest.json 2>/dev/null)"
fi
quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
```

- [ ] **Step 5: Test**

```bash
theme-switch darko
loginctl lock-session
```

Expected: lockscreen shows DARKO wordmark, countdown ticking, "wake up donnie", and password input. Unlock with your password.

```bash
theme-switch mono
loginctl lock-session
```

Expected: lockscreen looks like before — none of the Darko widgets visible.

If the Darko widgets are missing under darko, check: is `DARKO_THEME` actually set? Quickshell's `Quickshell.env(...)` API may differ between versions — fallback is reading `~/.config/themes/active.name` via `Quickshell.Io.FileView`.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/hypr/ config/hypr/
cp ~/.local/bin/theme-switch local/bin/
git add config/hypr/scripts/quickshell/Lock.qml config/hypr/scripts/lock.sh local/bin/theme-switch
git commit -m "Lock.qml: darko-only countdown / wake-up / DARKO wordmark widgets"
```

### Task 17: Add a 5-second lavender pre-screen-off fade to hypridle

**Files:**
- Modify: `~/.config/hypr/hypridle.conf`

- [ ] **Step 1: Add a pre-fade listener**

In `~/.config/hypr/hypridle.conf`, find the existing `listener { timeout = 600 ... }` block. Add a new listener BEFORE it:

```conf
listener {
    timeout = 595
    on-timeout = ~/.local/bin/darko-fade.sh start
    on-resume  = ~/.local/bin/darko-fade.sh stop
}
```

- [ ] **Step 2: Write `darko-fade.sh`**

```bash
cat > ~/.local/bin/darko-fade.sh <<'EOF'
#!/usr/bin/env bash
# Fade screen brightness to a lavender-tinted dim over 5 seconds, only on darko theme.
ACTIVE="$(cat ~/.config/themes/active.name 2>/dev/null || echo mono)"
[[ "$ACTIVE" == "darko" ]] || exit 0

case "${1:-start}" in
    start)
        # gamma shift toward lavender via hyprsunset / wlsunset / hyprctl
        # using hyprctl gamma (hyprland 0.40+):
        if hyprctl getoption misc:disable_hyprland_logo >/dev/null 2>&1; then
            for i in 100 80 60 40 20 0; do
                hyprctl keyword decoration:dim_inactive true 2>/dev/null || true
                hyprctl keyword decoration:dim_strength "0.$(printf '%02d' $((100-i)))" 2>/dev/null || true
                sleep 1
            done
        fi
        ;;
    stop)
        hyprctl keyword decoration:dim_inactive false 2>/dev/null || true
        hyprctl keyword decoration:dim_strength 0.0 2>/dev/null || true
        ;;
esac
EOF
chmod +x ~/.local/bin/darko-fade.sh
```

(Lavender tinting via gamma shift requires `hyprsunset` or `wlsunset` — install if you want true tint; the dim-only path above is a no-tint fallback.)

- [ ] **Step 3: Reload hypridle**

```bash
pkill hypridle && (hypridle &)
```

- [ ] **Step 4: Test (manually)**

Set `timeout = 30` temporarily. Wait 25 seconds. Should see screen start dimming. After 35 seconds total, full screen-off. Move mouse — should restore.

Restore `timeout = 595` after test.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/hypr/ config/hypr/
cp ~/.local/bin/darko-fade.sh local/bin/
git add config/hypr/hypridle.conf local/bin/darko-fade.sh
git commit -m "hypridle: 5s lavender pre-fade before screen-off (darko only)"
```

---

## Phase 4 — Wallpaper pool (user-blocked)

### Task 18: Document the AI-gen prompts for the user

**Files:**
- Create: `~/dotfiles-rice/docs/superpowers/specs/darko-wallpaper-prompts.md`

- [ ] **Step 1: Copy the per-image prompts from the spec**

```bash
cat > ~/dotfiles-rice/docs/superpowers/specs/darko-wallpaper-prompts.md <<'EOF'
# Darko Wallpaper / Asset Generation Prompts

Run these through your image generator. Generate 2-4 variations per prompt.
Drop outputs into `~/Pictures/darko-source/`. We'll curate down to ~12 wallpapers
plus the SDDM background and the Frank silhouette PNG during Phase 4.

## Wallpapers — 16:9, 2560×1440 or higher

1. **Suburban night street, sodium streetlamps, Virginia 1988.** Wide tree-lined road, no people, deep navy sky, amber lamp pools on wet asphalt. Cinematic film grain. Style: Richard Kelly cinematography, Steven Poster DP.
2. **Single sodium streetlamp on empty road**, low angle, lamp dominates frame, halo of warm orange in cold blue night.
3. **Tangent-universe portal effect** in a suburban living room — translucent, swirling, water-like vortex emerging from a chest. Violet-blue glow. No people.
4. **Cellar door at night**, slightly ajar, faint amber light from below, leaves on the ground. Eerie but quiet, not horror.
5. **Sky with a single jet engine** falling silently through high clouds, dawn light, no plane visible. Wide aspect, cinematic.
6. **Empty school auditorium**, dim, single spotlight on stage, dust motes, navy wash.
7. **Suburban house at 4am**, exterior, one upstairs window glowing amber, rest dark. Quiet menace.
8. **Black card with white serif text** "28:06:42:12" centered, large, no decoration. Pure typographic wallpaper.
9. **Abstract wormhole** — concentric violet rings receding into a black point, soft glow, no hard edges. Looks like space-time distortion.
10. **Wet asphalt close-up** with sodium streetlamp reflection, vertical bokeh, very moody.
11. **Lone hooded figure** at the end of a long suburban driveway, back to camera, sodium-lamp lit. Generic enough to not need a Frank costume.
12. **Bedroom interior at night**, single window with violet sky outside, no people, soft static light from an unseen TV.

## SDDM background

13. **Suburban street wide-shot at twilight**, full bleed, no central focal point (login form sits center-right of the rendered output, so leave that area visually quiet). Sodium-amber + cold-violet color grading.

## Frank silhouette (for GRUB)

14. **Solid black silhouette** of a tall thin humanoid figure with elongated rabbit ears, head and shoulders only, on a transparent background, 512×512 PNG. No facial detail, no texture — pure cutout. Used at 12% opacity in the GRUB corner.

## Lockscreen accent (optional)

15. **Soft tangent-universe haze** as a 2560×1440 PNG — abstract, all-violet-and-blue, no clear subject. Used as a subtle background under the lockscreen gradient if the static-gradient approach feels flat.
EOF
```

- [ ] **Step 2: Commit**

```bash
cd ~/dotfiles-rice
git add docs/superpowers/specs/darko-wallpaper-prompts.md
git commit -m "docs: AI-gen prompts for darko wallpaper pool"
```

- [ ] **Step 3: Tell user to generate**

Stop here and ask the user to run the prompts and drop output into `~/Pictures/darko-source/`. **This blocks Task 19.**

### Task 19: Curate the wallpaper pool

**Files:**
- Populate: `~/.config/themes/darko/wallpapers/`

- [ ] **Step 1: Verify source dir has images**

```bash
ls ~/Pictures/darko-source/ 2>/dev/null | wc -l
```

Expected: ≥12 images. If 0, user hasn't generated yet — wait.

- [ ] **Step 2: Pick the keepers**

Open them in an image viewer (`feh ~/Pictures/darko-source/` or similar). For each image, decide keep or skip. Aim for 12 wallpapers.

For each kept wallpaper:

```bash
cp ~/Pictures/darko-source/<filename> ~/.config/themes/darko/wallpapers/
```

- [ ] **Step 3: Pick the SDDM background and Frank silhouette**

```bash
cp ~/Pictures/darko-source/<sddm-bg-pick> ~/.config/themes/darko/sddm-bg.png
cp ~/Pictures/darko-source/<frank-pick>   ~/.config/themes/darko/frank-silhouette.png
```

- [ ] **Step 4: Wire the wallpaper rotator to read from active theme**

The existing `wallpaper-rotate` (or whatever your service is named) script — find it:

```bash
ls ~/.config/systemd/user/ | grep -i wall
```

Edit the `.service` to point at `~/.config/themes/active/wallpapers/` instead of a hardcoded path:

```ini
ExecStart=/home/amir/.local/bin/rotate-wallpaper.sh %h/.config/themes/active/wallpapers
```

(or whatever the script name is). Reload:

```bash
systemctl --user daemon-reload
systemctl --user restart wallpaper-rotate.timer
```

- [ ] **Step 5: Test**

```bash
theme-switch darko
# wait for next rotate tick or trigger manually
systemctl --user start wallpaper-rotate.service
# verify wallpaper is from the darko pool
awww query 2>/dev/null
theme-switch mono
systemctl --user start wallpaper-rotate.service
# verify wallpaper switched back to mono pool
```

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/themes/darko/wallpapers/ config/themes/darko/wallpapers/
cp ~/.config/themes/darko/sddm-bg.png config/themes/darko/sddm-bg.png 2>/dev/null || true
cp ~/.config/themes/darko/frank-silhouette.png config/themes/darko/frank-silhouette.png 2>/dev/null || true
git add config/themes/darko/wallpapers/ config/themes/darko/sddm-bg.png config/themes/darko/frank-silhouette.png
git lfs track "config/themes/darko/wallpapers/*.{png,jpg,webp}" 2>/dev/null || true
git commit -m "darko: wallpaper pool + sddm bg + frank silhouette"
```

(If wallpaper files are large, set up git-lfs first:`pacman -S git-lfs && git lfs install`.)

---

## Phase 5 — SDDM + GRUB + Plymouth

### Task 20: Build `darko-sddm` SDDM theme

**Files:**
- Create: `~/.config/themes/darko/sddm-theme/`
- System-install copy at: `/usr/share/sddm/themes/darko-sddm/`

- [ ] **Step 1: Get the source: clone sddm-sugar-candy as a base**

```bash
cd /tmp
git clone --depth 1 https://framagit.org/MarianArlt/sddm-sugar-candy.git
sudo cp -r sddm-sugar-candy /usr/share/sddm/themes/darko-sddm
sudo chown -R root:root /usr/share/sddm/themes/darko-sddm
```

- [ ] **Step 2: Edit `theme.conf` to point at our background and recolor**

```bash
sudo $EDITOR /usr/share/sddm/themes/darko-sddm/theme.conf
```

Set:

```ini
[General]
Background=/usr/share/sddm/themes/darko-sddm/Backgrounds/sddm-bg.png
DimBackgroundImage=0.0
ScaleImageCropped=true
ScreenWidth=1920
ScreenHeight=1080
FullBlur=false
PartialBlur=false
HaveFormBackground=true
FormPosition=right

MainColor=#b4a8e8
AccentColor=#f5a040
BackgroundColor=#1c2440
PlaceholderColor=#7a8aa0
WarningColor=#c4506a

Font="JetBrainsMono Nerd Font"
FontSize=10

ForceRightToLeft=false
ForceLastUser=true
ForcePasswordFocus=true
ForceHideCompletePassword=false
ForceHideVirtualKeyboardButton=false

ShowSessionsOptionalArrow=false
ShowSessionAtTop=false

PartialBlurOpacity=0.15
HourFormat="HH:mm"
DateFormat="dddd, MMMM d"
```

- [ ] **Step 3: Drop the SDDM background into the theme**

```bash
sudo cp ~/.config/themes/darko/sddm-bg.png /usr/share/sddm/themes/darko-sddm/Backgrounds/sddm-bg.png
```

- [ ] **Step 4: Mirror the system theme into the theme dir**

```bash
sudo cp -r /usr/share/sddm/themes/darko-sddm/. ~/.config/themes/darko/sddm-theme/
sudo chown -R $USER:$USER ~/.config/themes/darko/sddm-theme/
```

- [ ] **Step 5: Test the SDDM theme without rebooting**

```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/darko-sddm
```

Expected: a fullscreen SDDM preview with the darko background, lavender form, sodium-amber accents. Close with Esc / Ctrl+C.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/themes/darko/sddm-theme/ config/themes/darko/sddm-theme/
git add config/themes/darko/sddm-theme/
git commit -m "darko-sddm: sugar-candy fork with cosmic palette"
```

### Task 21: Build `darko-grub` GRUB theme

**Files:**
- Create: `~/.config/themes/darko/grub-theme/`

- [ ] **Step 1: Write `theme.txt`**

```bash
mkdir -p ~/.config/themes/darko/grub-theme
cat > ~/.config/themes/darko/grub-theme/theme.txt <<'EOF'
desktop-image: ""
desktop-color: "#0a0e1a"
title-text: ""
terminal-font: "Unifont Regular 16"

# Frank silhouette in bottom-right
+ image {
    top = 100%-160
    left = 100%-160
    width = 128
    height = 128
    file = "frank.png"
}

# Title
+ label {
    top = 80
    left = 80
    text = "DARKO"
    color = "#f5a040"
    font = "DejaVu Serif Bold 28"
}

# Subtitle
+ label {
    top = 130
    left = 80
    text = "tangent universe"
    color = "#7a4a8a"
    font = "DejaVu Sans 12"
}

# Boot menu
+ boot_menu {
    top = 220
    left = 80
    width = 50%
    height = 50%
    item_font = "DejaVu Serif 14"
    item_color = "#b4a8e8"
    selected_item_color = "#f5a040"
    item_height = 36
    item_padding = 10
    item_spacing = 4
}

# Bottom hint
+ label {
    bottom = 30
    left = 80
    text = "↑↓ navigate · enter boot · e edit · c command"
    color = "#7a8aa0"
    font = "DejaVu Sans 10"
}
EOF
```

- [ ] **Step 2: Drop in Frank silhouette**

```bash
cp ~/.config/themes/darko/frank-silhouette.png ~/.config/themes/darko/grub-theme/frank.png
```

- [ ] **Step 3: Stage + test (NO grub-mkconfig yet)**

```bash
sudo mkdir -p /boot/grub/themes/darko-grub
sudo cp -r ~/.config/themes/darko/grub-theme/. /boot/grub/themes/darko-grub/
sudo cp /etc/default/grub /etc/default/grub.bak.$(date +%s)
```

- [ ] **Step 4: Edit `/etc/default/grub`**

```bash
sudo $EDITOR /etc/default/grub
```

Set / add:

```
GRUB_THEME="/boot/grub/themes/darko-grub/theme.txt"
GRUB_GFXMODE="1920x1080,auto"
GRUB_TERMINAL_OUTPUT="gfxterm"
```

- [ ] **Step 5: Backup current grub.cfg, then regenerate**

```bash
sudo cp /boot/grub/grub.cfg /boot/grub/grub.cfg.bak.$(date +%s)
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Expected: no errors. If errors, restore the latest `grub.cfg.bak.*` file.

- [ ] **Step 6: Visual test**

GRUB only renders at boot, so manual reboot needed eventually. For now:

```bash
sudo grub2-mkstandalone --themes=darko-grub --format=x86_64-efi -o /tmp/grub-test.efi 2>&1 | head -5
```

(May not work on all systems — best test is "reboot once and confirm".) Defer the reboot until end of Phase 5.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/themes/darko/grub-theme/ config/themes/darko/grub-theme/
git add config/themes/darko/grub-theme/
git commit -m "darko-grub: theme.txt + frank silhouette + sodium-amber serif menu"
```

### Task 22: Build `darko-boot` Plymouth theme

**Files:**
- Create: `~/.config/themes/darko/plymouth-theme/`

- [ ] **Step 1: Write `darko-boot.plymouth`**

```bash
mkdir -p ~/.config/themes/darko/plymouth-theme
cat > ~/.config/themes/darko/plymouth-theme/darko-boot.plymouth <<'EOF'
[Plymouth Theme]
Name=Darko Boot
Description=Wormhole expansion fade
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/darko-boot
ScriptFile=/usr/share/plymouth/themes/darko-boot/darko-boot.script
EOF
```

- [ ] **Step 2: Write the Plymouth script**

```bash
cat > ~/.config/themes/darko/plymouth-theme/darko-boot.script <<'EOF'
# Darko Plymouth — wormhole expansion + fade.
# Total runtime ~3.0s @ 60fps.

Window.SetBackgroundTopColor (0.04, 0.05, 0.10);
Window.SetBackgroundBottomColor (0.04, 0.05, 0.10);

cx = Window.GetX() + Window.GetWidth() / 2;
cy = Window.GetY() + Window.GetHeight() / 2;

# Single violet sprite expanding from center.
sprite = Sprite();
img = Image.Text("●", 1.0, 1.0, 1.0, 1.0, "Sans 1");
sprite.SetImage(img);
sprite.SetPosition(cx, cy, 1);

frame = 0;
fun refresh_callback () {
    frame = frame + 1;
    # Phases: 0..15 fade-in, 15..75 expand, 75..105 fade to white, 105+ done.
    if (frame < 15) {
        scale = frame / 15.0;
        opacity = scale * 0.8;
        sprite.SetOpacity(opacity);
    } else if (frame < 75) {
        scale = 1.0 + (frame - 15) * 4.0;  # grow up to ~240×
        # Use a soft-edged disc at high scale (we re-render the image scaled)
        new_img = Image.Text("●", 0.48, 0.28, 0.55, 0.7, "Sans " + IntegerToString(scale));
        sprite.SetImage(new_img);
        sprite.SetOpacity(0.7);
    } else if (frame < 105) {
        # Fade to white
        white_amt = (frame - 75) / 30.0;
        Window.SetBackgroundTopColor(0.04 + white_amt * 0.96, 0.05 + white_amt * 0.95, 0.10 + white_amt * 0.90);
        Window.SetBackgroundBottomColor(0.04 + white_amt * 0.96, 0.05 + white_amt * 0.95, 0.10 + white_amt * 0.90);
        sprite.SetOpacity(0.7 - white_amt * 0.7);
    }
}

Plymouth.SetRefreshFunction(refresh_callback);

# Boot progress (no UI; we ignore boot events visually)
fun boot_progress_callback (duration, progress) { }
Plymouth.SetBootProgressFunction(boot_progress_callback);
EOF
```

(Plymouth's `script` plugin is finicky — the script above is a starting point. If `Image.Text` with scale doesn't expand smoothly, fall back to pre-rendered PNG frames at 30fps in an `ImageDir`.)

- [ ] **Step 3: Stage and rebuild initramfs**

```bash
sudo mkdir -p /usr/share/plymouth/themes/darko-boot
sudo cp -r ~/.config/themes/darko/plymouth-theme/. /usr/share/plymouth/themes/darko-boot/
sudo cp /boot/initramfs-linux.img /boot/initramfs-linux.img.bak.$(date +%s)
sudo plymouth-set-default-theme darko-boot
sudo mkinitcpio -P
```

Watch for `==> Image generation successful`. If any error, restore: `sudo cp /boot/initramfs-linux.img.bak.<latest> /boot/initramfs-linux.img && sudo plymouth-set-default-theme bgrt`.

- [ ] **Step 4: Test (no reboot — preview)**

```bash
sudo plymouthd --tty=tty1 --debug --debug-file=/tmp/plymouth.log
sudo plymouth show-splash
sleep 3
sudo plymouth quit
```

If the test hangs or your screen freezes, ssh in from another session to run `sudo plymouth quit`. Plymouth previews are imperfect; the real test is reboot.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-rice
rsync -a ~/.config/themes/darko/plymouth-theme/ config/themes/darko/plymouth-theme/
git add config/themes/darko/plymouth-theme/
git commit -m "darko-boot: plymouth wormhole expansion script"
```

### Task 23: Wire SDDM/GRUB/Plymouth staging into `theme-switch`

**Files:**
- Modify: `~/.local/bin/theme-switch` (final v3)

- [ ] **Step 1: Replace with v3**

Append to `theme-switch` after the existing live-reload (right before `echo "active: ..."`):

```bash
cat >> ~/.local/bin/theme-switch <<'STAGE_BLOCK'

# 8. stage reboot-required surfaces
needs_sudo=0
if [[ -d "$ACTIVE/sddm-theme" ]] || [[ -d "$ACTIVE/plymouth-theme" ]] || [[ -d "$ACTIVE/grub-theme" ]]; then
    needs_sudo=1
fi

if [[ $needs_sudo -eq 1 ]]; then
    echo "  [stage] sddm/plymouth/grub for next boot (sudo required)"
    # Build a single sudo invocation
    sudo bash -s "$target" <<'SUDO_BLOCK'
set -euo pipefail
target="$1"
HOME_USER="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
ACTIVE="$HOME_USER/.config/themes/active"
MANIFEST="$ACTIVE/manifest.json"

# SDDM: copy theme dir into /usr/share/sddm/themes/<target>-sddm and update Current=
if [[ -d "$ACTIVE/sddm-theme" ]] && [[ -n "$(ls "$ACTIVE/sddm-theme" 2>/dev/null)" ]]; then
    sddm_name="${target}-sddm"
    [[ "$target" == "mono" ]] && sddm_name="matugen-minimal"
    if [[ -d "/usr/share/sddm/themes/$sddm_name" ]]; then
        sed -i "s|^Current=.*|Current=$sddm_name|" /etc/sddm.conf.d/10-wayland-matugen.conf 2>/dev/null \
            || echo -e "[Theme]\nCurrent=$sddm_name" > /etc/sddm.conf.d/10-wayland-matugen.conf
    fi
fi

# Plymouth: only restage if dir exists AND theme isn't already current
if [[ -d "$ACTIVE/plymouth-theme" ]] && [[ -n "$(ls "$ACTIVE/plymouth-theme" 2>/dev/null)" ]]; then
    plym_name="${target}-boot"
    [[ "$target" == "mono" ]] && plym_name="bgrt"  # default
    current="$(plymouth-set-default-theme 2>/dev/null || true)"
    if [[ "$current" != "$plym_name" ]]; then
        cp /boot/initramfs-linux.img "/boot/initramfs-linux.img.bak.$(date +%s)" 2>/dev/null || true
        plymouth-set-default-theme "$plym_name" 2>/dev/null || true
        mkinitcpio -P 2>&1 | tail -5
    fi
fi

# GRUB: copy theme + regen grub.cfg
if [[ -d "$ACTIVE/grub-theme" ]] && [[ -n "$(ls "$ACTIVE/grub-theme" 2>/dev/null)" ]]; then
    grub_name="${target}-grub"
    [[ "$target" == "mono" ]] && grub_name=""  # mono = no theme line
    if [[ -n "$grub_name" ]]; then
        sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/$grub_name/theme.txt\"|" /etc/default/grub
    else
        sed -i 's|^GRUB_THEME=.*|#GRUB_THEME=|' /etc/default/grub
    fi
    cp /boot/grub/grub.cfg "/boot/grub/grub.cfg.bak.$(date +%s)" 2>/dev/null || true
    grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -3
fi
SUDO_BLOCK
fi

STAGE_BLOCK
```

(The `STAGE_BLOCK`/`SUDO_BLOCK` heredoc nesting is the cleanest way to embed the sudo body. Verify the resulting file has no syntax errors with `bash -n ~/.local/bin/theme-switch`.)

- [ ] **Step 2: Validate**

```bash
bash -n ~/.local/bin/theme-switch
echo "$?"  # 0 = ok
```

- [ ] **Step 3: Test the staging**

```bash
theme-switch darko
# enter sudo password
# expected output: [stage] sddm/plymouth/grub ... lines from mkinitcpio + grub-mkconfig
```

Verify:

```bash
cat /etc/sddm.conf.d/10-wayland-matugen.conf  # Current=darko-sddm
plymouth-set-default-theme  # darko-boot
grep GRUB_THEME /etc/default/grub  # /boot/grub/themes/darko-grub/theme.txt
```

Reverse:

```bash
theme-switch mono
cat /etc/sddm.conf.d/10-wayland-matugen.conf  # Current=matugen-minimal
plymouth-set-default-theme  # bgrt (default)
grep GRUB_THEME /etc/default/grub  # commented out
```

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles-rice
cp ~/.local/bin/theme-switch local/bin/
git add local/bin/theme-switch
git commit -m "theme-switch v3: stage sddm/plymouth/grub via single sudo block"
```

### Task 24: Reboot test

- [ ] **Step 1: Make sure mono fallback works**

```bash
theme-switch mono
sudo reboot
```

Expected on reboot: GRUB shows default text (no theme), Plymouth shows default boot, SDDM shows old `matugen-minimal` look. Login. Confirm `theme` reports `mono`.

- [ ] **Step 2: Switch to darko, reboot**

```bash
theme-switch darko
sudo reboot
```

Expected: GRUB shows DARKO + Frank silhouette + cosmic-blue menu. Plymouth shows wormhole. SDDM shows Darko form. Login.

If any surface is broken, revert via the relevant `.bak.*` file (Plymouth: restore initramfs and `plymouth-set-default-theme bgrt`; GRUB: copy `grub.cfg.bak.<latest>` back).

- [ ] **Step 3: Document the rollback procedure**

```bash
cat > ~/dotfiles-rice/docs/superpowers/specs/darko-recovery.md <<'EOF'
# Darko Rice — Emergency Recovery

## Plymouth broke boot
1. Boot from arch USB or use single-user mode
2. `sudo plymouth-set-default-theme bgrt`
3. `sudo cp /boot/initramfs-linux.img.bak.<latest> /boot/initramfs-linux.img`

## GRUB hangs at black screen
1. From GRUB rescue prompt: `set prefix=(hd0,gpt2)/boot/grub` (adjust device)
2. `insmod normal && normal`
3. After boot: `sudo cp /boot/grub/grub.cfg.bak.<latest> /boot/grub/grub.cfg`
4. `sudo sed -i 's|^GRUB_THEME=.*|#GRUB_THEME=|' /etc/default/grub`
5. `sudo grub-mkconfig -o /boot/grub/grub.cfg`

## SDDM won't load
1. Switch TTY (Ctrl+Alt+F2), login, then:
2. `sudo systemctl stop sddm`
3. `echo -e "[Theme]\nCurrent=" | sudo tee /etc/sddm.conf.d/10-wayland-matugen.conf`
4. `sudo systemctl start sddm`
EOF
git add docs/superpowers/specs/darko-recovery.md
git commit -m "docs: emergency recovery for darko rice system surfaces"
```

---

## Phase 6 — Polish & finishing

### Task 25: Update CLAUDE.md / README with `theme` command docs

**Files:**
- Modify: `~/dotfiles-rice/README.md`

- [ ] **Step 1: Append section**

Append to `~/dotfiles-rice/README.md`:

```markdown
## Theme switching

Two coexisting variants live under `~/.config/themes/`:

- `mono` — the original monochrome rice (Catppuccin-mocha-derived, mango accents)
- `darko` — full Donnie Darko theme (cosmic blue + violet + sodium-amber, Frank lockscreen, wormhole boot)

Switch:

```sh
theme              # report current
theme darko        # switch to darko (live + stage system surfaces, sudo prompt for stage)
theme mono         # switch back
```

Live surfaces (Hyprland, Quickshell, GTK, Qt/Kvantum, kitty, yazi, mako, cursor, icons) repaint instantly. SDDM, Plymouth, and GRUB are staged and take effect on next login or boot.

If something breaks, see `docs/superpowers/specs/darko-recovery.md`.
```

- [ ] **Step 2: Commit**

```bash
cd ~/dotfiles-rice
git add README.md
git commit -m "docs: theme command + recovery pointer in README"
```

### Task 26: Final smoke-test pass

- [ ] **Step 1: Run all tests**

```bash
~/dotfiles-rice/tests/theme-switch.sh
```

Expected: all PASS.

- [ ] **Step 2: Manual full-stack walk-through under darko**

Switch to darko. For each surface, verify it looks Darko:

- [ ] Hyprland active border = portal magenta with glow
- [ ] TopBar accents sodium amber
- [ ] Kitty: open new term — repainted
- [ ] yazi: open — cosmic palette
- [ ] Dolphin: open — cosmic-blue chrome via darko-kv
- [ ] Nautilus: open — adw-gtk3-dark with darko colors-css
- [ ] Lockscreen: `loginctl lock-session` — DARKO + countdown + wake-up donnie
- [ ] Notification: `notify-send "test"` — cosmic palette
- [ ] (After next boot) GRUB shows DARKO menu
- [ ] (After next boot) Plymouth shows wormhole
- [ ] (After next login) SDDM shows darko-sddm

- [ ] **Step 3: Switch to mono, walk through again, confirm reverts**

- [ ] **Step 4: Final commit + push to dotfiles-rice**

```bash
cd ~/dotfiles-rice
~/.local/bin/save-rice "darko theme variant complete"
```

Or manually:

```bash
git status
git push origin main
```

---

## Self-review notes (append to plan if extending)

- Task 7 references `qs_colors.json.template` keys (`mauve`, `pink`, `peach`, etc.). Confirm against the actual upstream MatugenColors.qml at implementation time — if Quickshell consumers reference different key names (e.g. `accent` instead of `peach`), update the template's right-hand-sides accordingly.
- Task 16 (Lock.qml) uses `parent.parent.parent.visible` for the Timer running condition. Brittle. Replace with a top-level `id: darkoOverlay` and use `darkoOverlay.visible` instead during implementation.
- Task 22 (Plymouth) is the highest-risk single task. If `script` plugin behaves badly, fall back to pre-rendered PNG frames in `ImageDir` and a much simpler script that flips between frames.
- Task 23's heredoc-in-heredoc is fragile against editor auto-formatting. After writing it, `bash -n` to validate.
- The `awww query` call assumes `awww` is the wallpaper daemon — confirm at Phase 0 by checking what wallpaper system the rice actually uses; substitute `swww query` etc. if needed.

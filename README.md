# Hyprland Rice — Personal Backup

Snapshot of the imperative-dots-based rice with custom monochrome theme and tweaks.

## Restore on a fresh install

After installing imperative-dots:
```sh
cp -r config/hypr/*       ~/.config/hypr/
cp -r config/matugen/*    ~/.config/matugen/
cp -r config/cava/*       ~/.config/cava/
cp    config/kitty/*      ~/.config/kitty/
hyprctl reload
```

## Custom changes vs upstream imperative-dots

- monochrome matugen palette (`scheme-monochrome`)
- bar height s(55), uiScale 0.7
- mango active window border `#ffae42`
- workspace icons via Iosevka Nerd Font glyphs
- weather rain icon swapped U+F740 → U+E318
- cava raw visualizer in topbar
- kitty: JetBrainsMono Nerd Font, padding 14, opacity 0.75
- inactive_opacity 0.85, gaps_out top halved
- video wallpaper --panscan=1.0
- BrowserOS as default browser

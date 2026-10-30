# OBS Font Bridge

An OBS Studio (Windows) Lua script that adds a **Text (Bridge)** source (localized like Text (GDI+)).
Its settings page is borrowed from OBS's Text (GDI+) at runtime; it renders through Windows GDI, so fonts that OBS's built-in text sources can't read
(CFF-based OpenType `.otf`, fonts temporarily activated with font managers, etc.) display correctly.

- Same settings as Text (GDI+), applied in real time
- Fonts newly activated in a font manager are picked up automatically (no OBS restart)
- UI in English / 日本語 / 한국어 / Bahasa Indonesia / Français / 繁體中文 (other OBS languages → English)
- Debug Mode: a browser dock with font previews

## Install
1. Keep `obs_font_bridge.lua` and `obs_font_bridge_dock.html` in the same folder.
2. OBS → **Tools → Scripts → +** → select `obs_font_bridge.lua`.
3. **Sources → + → Text (Bridge)**.

## Debug dock
1. In the script settings, click **Debug Mode: OFF** to turn it on (previews are generated in the background).
2. Copy the **Dock URL**, then **Docks → Custom Browser Docks…** → paste it.
3. Enable **Tools → WebSocket Server Settings** and enter the port / password in the dock (⚙).

Requires OBS 28+ (built-in obs-websocket v5) on Windows.

Author: BlackDream feat. ChromeBread ・ License: GPL-2.0

This is an unofficial third-party script. It is not affiliated with or endorsed by the OBS Project.

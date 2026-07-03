# koreader-quicksettings

Custom Quick Settings patch for KOReader.
![Quick Settings Screenshot 3](assets/image.png)
## Complete feature set

This patch adds a dedicated Quick Settings tab at the far left of KOReader's top menu in both File Manager and Reader views, then extends that panel with configurable controls.

Core features:

- New Quick Settings tab injected into both main menu contexts (File Manager and Reader).
- Configurable top action-button row with reorder support.
- Button visibility toggles from KOReader settings (enable/disable each quick action).
- Optional "Always open on this tab" behavior.

Supported quick actions:

- Wi-Fi toggle (shows active state and SSID label when available).
- Night mode toggle.
- Screen rotation action.
- USB mass storage request.
- Restart KOReader (with confirmation).
- Exit KOReader (with confirmation).
- Sleep / suspend / power-off action based on device capability.
- File search.
- Cloud storage.
- Z-Library search.
- Calibre wireless connect/disconnect with active-state indicator.
- OPDS catalog entry.
- Optional plugin actions: QuickRSS, NotionSync, Reading Streak.

Frontlight and warmth controls:

- Custom rounded slider rendering for a cleaner, high-contrast look.
- Tap and swipe/pan gestures on sliders in the quick settings panel.
- Tri-state icon controls for both brightness and warmth (`off`, `mid`, `max`).
- Tri-state logic aligned with slider value boundaries.
- Optional show/hide for `+` and `-` slider control buttons.
- Slider expands when side controls are hidden.
- Warmth section is conditionally shown only on devices with natural light support.

Assets and theming:

- Custom icon pack in `icons/` (including dedicated brightness and warmth tri-state icons).
- Icons are loaded through KOReader's user icon lookup path.

## Reference

This has been blatantly copied from [qewer33/koreader-patches](https://github.com/qewer33/koreader-patches).

## Installation

1. Find your KOReader user directory for your device.
2. Copy `2-quick-settings.lua` into the `patches/` folder inside that KOReader directory.
3. Copy all SVG files from this repo's `icons/` folder into KOReader's `icons/` folder.
4. Fully restart KOReader.

## KOReader folder locations (by device)

Use these as common defaults; exact paths can vary by install method.

- Kindle: `/mnt/us/koreader/`
- Kobo: `.adds/koreader/` (device storage root)
- Android: `/storage/emulated/0/koreader/` or `/sdcard/koreader/`
- Linux desktop: `~/.config/koreader/`
- Other Linux-based readers: typically an app folder named `koreader/` in user storage

Inside that KOReader directory, this patch uses:

- `patches/2-quick-settings.lua`
- `icons/*.svg`

## Verify

After restart, open the Quick Settings tab and confirm:

- Action buttons are visible and respond.
- Frontlight slider works and updates icon state.
- Warmth slider appears only on natural-light devices.
- Custom icons render instead of defaults.

## Uninstall

Remove `patches/2-quick-settings.lua` and the copied `icons/quick_*.svg` files from your KOReader user directory, then restart KOReader.

## Screenshots

![Quick Settings Screenshot 1](assets/settings1.png)

![Quick Settings Screenshot 2](assets/settings2.png)



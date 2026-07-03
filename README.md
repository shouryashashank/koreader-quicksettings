# koreader-quicksettings

Custom Quick Settings patch for KOReader with a cleaner control layout, custom icons, and improved frontlight/warmth interactions.

## What this patch does

This patch replaces and extends KOReader's quick settings panel behavior.

Main changes include:

- Modernized frontlight and warmth slider rows.
- Custom tri-state icon controls for brightness and warmth (`off`, `mid`, `max`).
- Optional show/hide of `+`/`-` slider controls from patch settings.
- Better slider interaction (tap and swipe/pan handling in quick settings).
- Custom quick settings icons bundled in the `icons/` directory.
- Warmth row shown only on devices that support natural light.

In short: it makes quick settings faster to use and more touch-friendly while keeping KOReader's patch-based workflow.

## Reference

This has been blatantly copied from [qewer33/koreader-patches](https://github.com/qewer33/koreader-patches).

## Installation

### 1) Locate your KOReader user directory

You need the **KOReader user folder** that contains `patches/`, `settings/`, and other runtime files.

Common locations:

- **Linux desktop**: `~/.config/koreader/`
- **Android**: `/sdcard/koreader/` or `/storage/emulated/0/koreader/`
- **Kindle**: `/mnt/us/koreader/`
- **Kobo**: `.adds/koreader/` on the device storage
- **reMarkable / other Linux-based e-readers**: usually under the installed KOReader directory (often `koreader/` inside user storage)

If unsure, open KOReader once and search device storage for a folder named `koreader` containing a `settings/` directory.

### 2) Copy the patch file

Create the patches folder if it does not exist, then copy:

- Source: `2-quick-settings.lua`
- Destination: `<koreader_user_dir>/patches/2-quick-settings.lua`

Example on Linux:

```bash
mkdir -p ~/.config/koreader/patches
cp 2-quick-settings.lua ~/.config/koreader/patches/
```

### 3) Copy icons

Copy all SVG icons from this repository's `icons/` folder to your KOReader icon folder:

- Destination: `<koreader_user_dir>/icons/`

Example on Linux:

```bash
mkdir -p ~/.config/koreader/icons
cp -f icons/*.svg ~/.config/koreader/icons/
```

### 4) Restart KOReader

Fully close KOReader and open it again so patch and icon changes are loaded.

## Device-specific notes

### Kindle

- KOReader root is usually `/mnt/us/koreader/`.
- Copy patch to `/mnt/us/koreader/patches/`.
- Copy icons to `/mnt/us/koreader/icons/`.
- If using USB transfer, safely eject before launching KOReader.

### Kobo

- KOReader is usually installed under `.adds/koreader/`.
- Copy patch to `.adds/koreader/patches/`.
- Copy icons to `.adds/koreader/icons/`.
- On some setups, hidden folders must be enabled on your computer to see `.adds`.

### Android

- Common KOReader folder is `/storage/emulated/0/koreader/`.
- Copy patch to `.../koreader/patches/`.
- Copy icons to `.../koreader/icons/`.
- You may need file manager permission for "All files access".

### Linux desktop

- Typical location is `~/.config/koreader/`.
- Copy patch to `~/.config/koreader/patches/`.
- Copy icons to `~/.config/koreader/icons/`.

## Verify it loaded

After restart, open Quick Settings and check:

- Frontlight row uses custom slider and icon control.
- Warmth row appears only on natural-light-capable devices.
- Tri-state icon cycles values as expected.
- Custom icons are visible (not default placeholders).

If something does not appear:

- Recheck file paths and names.
- Confirm files copied into the correct KOReader user directory.
- Restart KOReader again.

## Uninstall

Delete these files from your KOReader user directory:

- `patches/2-quick-settings.lua`
- Any copied `quick_*.svg` files you added from this repository

Then restart KOReader.

## Screenshots

![Quick Settings Screenshot 1](assets/settings1.png)

![Quick Settings Screenshot 2](assets/settings2.png)

![Quick Settings Screenshot 3](assets/image.png)

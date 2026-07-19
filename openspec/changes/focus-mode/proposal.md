## Why

KOReader's top menu accumulates tabs from every installed plugin — Settings, Tools, Search, Navigation, Typesetting, plus whatever each plugin adds. Users who only use a few tabs end up with a cluttered menu bar. Focus Mode lets them pick exactly which tabs stay visible, reducing visual noise.

## What Changes

- Replace the placeholder `focus` button (currently shows "Focus mode control is available in the quicksettings plugin build") with a working Focus Mode dialog
- Add Focus Mode settings panel: a checklist of all detected menu tabs with checkboxes to hide each
- Persist hidden-tab list in `G_reader_settings` across restarts
- Patch `TouchMenu` to filter out hidden tabs from the tab bar
- Keep QuickSettings tab always visible (so Focus Mode is always accessible)
- Keep File Browser tab always visible in reader (prevent lock-out)
- Add "Apply & Restart" flow: save settings then trigger KOReader restart so the simplified menu takes effect
- Add setting to enable/disable Focus Mode from the QuickSettings config menu

## Capabilities

### New Capabilities
- `focus-mode`: Tab visibility filtering for KOReader's top menu. Users can select which tabs to hide via a checklist dialog shown from the Focus button. Hidden tabs are persisted in settings and filtered out from both File Manager and Reader menus. QuickSettings and File Browser (in reader) tabs are always protected from hiding.

### Modified Capabilities
- None

## Impact

- `2-quick-settings.lua`: add Focus Mode dialog UI, filtering logic, setting persistence, and TouchMenu tab-bar patching
- `icons/`: the `quick_focus` icon already exists
- No new external dependencies
- No API changes

## 1. Config & Persistence

- [x] 1.1 Add `focus_mode_enabled` and `focus_mode_hidden_tabs` fields to `config_default`
- [x] 1.2 Merged into existing `loadConfig()` (generic merge handles defaults)
- [x] 1.3 Handled by existing `saveConfig()` (stored in `quick_settings_panel`)

## 2. Focus Mode Dialog UI

- [x] 2.1 Create `showFocusModeDialog()` function that builds a checklist of all visible tabs from `tab_item_table`
- [x] 2.2 Exclude QuickSettings tab and File Browser tab (in reader) from the checklist
- [x] 2.3 Add "Apply & Restart" button that saves selection and broadcasts restart event
- [x] 2.4 Add "Cancel" button to dismiss dialog without changes
- [x] 2.5 Add "Uncheck all" option to clear all hidden tabs

## 3. Tab Filtering Logic

- [x] 3.1 Create `getFocusHiddenSet()` that returns a lookup table of hidden tab labels
- [x] 3.2 Create `isTabVisible(tab_label)` that checks if a tab should be shown
- [x] 3.3 Tab filtering applied at `setUpdateItemTable` time (not at `switchMenuTab`)
- [x] 3.4 Integrate filtering into `FileManagerMenu.setUpdateItemTable` after QuickSettings tab injection
- [x] 3.5 Integrate filtering into `ReaderMenu.setUpdateItemTable` after QuickSettings tab injection

## 4. Focus Button & Settings

- [x] 4.1 Replace placeholder `focus` button callback to call `showFocusModeDialog(touch_menu)`
- [x] 4.2 Add "Focus Mode" submenu entry in QuickSettings config: enable/disable toggle
- [x] 4.3 Add "Configure hidden tabs" entry in QuickSettings config that opens the dialog

## 5. Verification

- [x] 5.1 Verify Focus button opens dialog with correct tab list
- [x] 5.2 Verify hidden tabs are hidden after Apply & Restart
- [x] 5.3 Verify QuickSettings tab is never hidden
- [x] 5.4 Verify File Browser tab is never hidden in reader
- [x] 5.5 Verify Focus Mode toggle enable/disable works
- [x] 5.6 Verify hidden-tab list persists across KOReader restarts

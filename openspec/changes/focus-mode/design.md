## Context

Focus Mode currently exists as a placeholder button (`focus` in `button_defs`) that shows a "Focus mode control is available in the quicksettings plugin build" message. The upstream plugin at `renandeivison/quicksettings` implements Focus Mode as a full plugin, but this project is a patch-based approach (`2-quick-settings.lua` injected via KOReader's `patches/` directory). The implementation must work within patch constraints — no separate plugin directory, no `_meta.lua`, no new module files. All code lives in a single patch file that runs at KOReader startup.

Currently detected tabs come from KOReader's `TouchMenu` tab system — `self.tab_item_table` entries built by each menu's `setUpdateItemTable`. The patch already hooks into both `FileManagerMenu` and `ReaderMenu` to inject the QuickSettings tab.

## Goals / Non-Goals

**Goals:**
- Replace the placeholder Focus button with a working Focus Mode dialog
- Let users select which KOReader menu tabs to hide via a MultiCheckDialog-style checklist
- Persist hidden-tab list in `G_reader_settings` key (`quick_settings_focus_hidden_tabs`)
- Patch `TouchMenu` to filter hidden tabs from the tab bar on menu open
- Always keep QuickSettings tab visible (tab index 1)
- Always keep File Browser tab visible in reader
- Provide "Apply & Restart" flow so changes take effect everywhere
- Add Focus Mode toggle and "Configure hidden tabs" entry in QuickSettings settings menu

**Non-Goals:**
- Not implementing as a separate plugin (stays as a patch)
- No new external dependencies
- No changes to KOReader core source
- No per-device or per-profile tab hiding

## Decisions

1. **Tab detection approach** → Parse `tab_item_table` entries at render time. Each entry has a `text` field that is the tab label. We filter by label text stored in the hidden-set. This avoids fragile index-based tracking when plugins dynamically add/remove tabs.

2. **Filtering mechanism** → Post-process `self.tab_item_table` after the parent `setUpdateItemTable` runs. The existing patches to `FileManagerMenu.setUpdateItemTable` and `ReaderMenu.setUpdateItemTable` already add the QuickSettings tab; we insert tab filtering after that point.

3. **Persistence** → Use `G_reader_settings:readSetting`/`saveSetting` with a dedicated key `"quick_settings_focus_hidden_tabs"` storing a table of tab label strings. This follows the existing pattern used for `quick_settings_panel` config.

4. **Protected tabs** → QuickSettings tab is identified by position (always index 1 since we insert it first). File Browser tab is identified by its label text (varies by locale — use the localized `_("File browser")` string). These are hard-coded as always-visible.

5. **UI: checklist dialog** → Use KOReader's `MultiCheckDialog` (or build one from `ButtonDialog` if MC is unavailable) showing all detected tab labels with checkboxes pre-filled for currently hidden tabs. "Apply & Restart" button triggers save + restart event.

6. **Restart trigger** → Use the existing `Event:new("Restart")` broadcast, which is already used by the Restart button.

7. **Tab label localization** → Store hidden tab labels using the localized display text. This is imperfect if the user changes language, but it's the simplest approach and matches how KOReader identifies tabs internally. An alternative (storing internal tab IDs) is fragile because tabs are just `{text, callback}` tables.

## Risks / Trade-offs

- **Localized tab labels** → Mitigation: tabs use KOReader's `_()` function, so labels change with locale. If the language changes, hidden-tab list may not match. Acceptable trade-off since language changes are rare.
- **Plugin tabs may have dynamic labels** → Mitigation: tab labels from plugins are resolved by the time they reach `tab_item_table`, so they match what the user sees.
- **Patch size increase** → Mitigation: Focus Mode adds ~150 lines to the patch. Manageable for a single-file patch.
- **Menu freeze on large tab lists** → Mitigation: checklist uses KOReader's standard scrolling dialog, which handles long lists natively.

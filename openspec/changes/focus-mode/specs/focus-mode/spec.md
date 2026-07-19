## ADDED Requirements

### Requirement: Tab visibility filtering
The system SHALL allow users to select which KOReader top-menu tabs to hide. The QuickSettings tab MUST always remain visible. The File Browser tab MUST always remain visible in the Reader menu.

#### Scenario: Toggle tab visibility
- **WHEN** user opens the Focus Mode dialog
- **THEN** user sees a checklist of all currently available menu tabs
- **WHEN** user checks a tab and taps "Apply & Restart"
- **THEN** that tab is hidden from both File Manager and Reader menus after restart

#### Scenario: Protected tabs
- **WHEN** the QuickSettings tab exists in the tab list
- **THEN** it SHALL NOT appear in the hidden-tab checklist
- **WHEN** in Reader menu with a File Browser tab
- **THEN** the File Browser tab SHALL NOT appear in the hidden-tab checklist

### Requirement: Persistence
The system SHALL persist the user's hidden-tab selection across KOReader restarts.

#### Scenario: Restart persistence
- **WHEN** user hides tabs via Focus Mode and restarts KOReader
- **THEN** the same tabs remain hidden after restart
- **WHEN** user unhides tabs and restarts
- **THEN** the tabs reappear

### Requirement: Focus Mode toggle
The system SHALL provide a setting to enable or disable Focus Mode filtering entirely, without losing the saved hidden-tab list.

#### Scenario: Enable/disable Focus Mode
- **WHEN** Focus Mode is disabled in QuickSettings config
- **THEN** all tabs SHALL be visible regardless of the hidden-tab list
- **WHEN** Focus Mode is re-enabled
- **THEN** previously hidden tabs SHALL become hidden again after restart

### Requirement: Focus button in button grid
The Focus button in the QuickSettings button grid SHALL open the Focus Mode dialog instead of showing a placeholder message.

#### Scenario: Focus button behavior
- **WHEN** user taps the Focus button in the button grid
- **THEN** the Focus Mode dialog SHALL open with the tab checklist

### Requirement: Tab label-based filtering
The system SHALL identify tabs by their display label text for filtering purposes.

#### Scenario: Label matching
- **WHEN** a tab has display label "Settings"
- **THEN** hiding "Settings" via Focus Mode SHALL prevent that tab from appearing
- **WHEN** a plugin adds a tab with label "My Plugin"
- **THEN** that tab SHALL appear in the checklist and can be hidden

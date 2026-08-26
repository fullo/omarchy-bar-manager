# Bar Manager for Omarchy

> **⚠ EXPERIMENTAL** — This plugin is under active development. APIs, UI, and behavior may change without notice. Use at your own risk.

A panel plugin for [Omarchy](https://omarchy.org/) that lets you manage bar plugins from a graphical interface — reorder, move between sections, and configure settings without editing `shell.json` manually.

No external dependencies required.

## Features

- **Move between sections** — shift plugins left/right between Left, Center, and Right
- **Reorder** — move plugins up/down within a section
- **Remove plugins** — remove any plugin from a section
- **Edit settings** — configure per-widget settings (clock format, gcal URLs, etc.) with Save/Undo
- **Add plugins** — install any unused plugin directly from the Add tab
- **Bar position** — change bar position (top/bottom/left/right)
- **Settings discovery** — scans plugin source code to discover all available settings with defaults
- **Safety first** — validates JSON and asks for confirmation before writing to `shell.json`
- **Auto-reload** — bar hot-reloads automatically after changes

## Requirements

- [Omarchy](https://omarchy.org/) with Quickshell

## Installation

```bash
omarchy plugin add https://github.com/fullo/omarchy-bar-manager.git --enable
```

Or manually clone:

```bash
git clone https://github.com/fullo/omarchy-bar-manager.git ~/.config/omarchy/plugins/io.github.fullo.omarchy-bar-manager
```

## Usage

### As a bar widget

After installation, a gear icon (⚙) appears in the bar. Click it to open the management panel.

### As a standalone panel

You can also open the panel without the bar widget:

```bash
omarchy-shell shell summon io.github.fullo.omarchy-bar-manager '{}'
```

### Panel tabs

| Tab | Description |
|-----|-------------|
| **Left** | Plugins in the left section — move left/right, reorder, remove, configure |
| **Center** | Plugins in the center section — same controls |
| **Right** | Plugins in the right section — same controls |
| **Add** | Shows plugins not yet in the layout — add them to any section |
| **Bar** | Change bar position (top/bottom/left/right) |

### Per-plugin controls

Each plugin row shows contextual buttons:

- **← →** — Move to adjacent section (hidden at section boundaries)
- **↑ ↓** — Reorder within section (hidden for first/last)
- **⚙** — Open settings editor
- **×** — Remove from section

### Settings editor

The settings editor:
- Scans plugin QML source to discover all available `setting()` calls with defaults
- Shows current values and allows editing
- **Save** — writes changes to `shell.json` and reloads
- **Undo** — reverts to original values
- **←** — discards changes and returns

## Shell.json safety

The plugin validates all changes before writing:
- Checks JSON structure integrity
- Requires explicit confirmation via dialog
- Uses `shell.mutateShellConfig()` when available (bar context)
- Falls back to direct file write when opened as standalone panel

## Removal

```bash
omarchy plugin remove io.github.fullo.omarchy-bar-manager
```

## License

MIT

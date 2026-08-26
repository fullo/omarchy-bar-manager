# io.github.fullo.omarchy-bar-manager — Bar Manager for Omarchy

A bar widget plugin for [Omarchy](https://omarchy.org/) that lets you manage bar plugins from a panel — enable, disable, reorder, and configure settings without editing `shell.json` manually.

No external dependencies required.

## Features

- **Toggle plugins** — enable/disable any installed plugin in left/center/right sections
- **Reorder** — move plugins up/down within a section
- **Move between sections** — shift plugins between left, center, and right
- **Edit settings** — modify per-widget settings (clock format, gcal URLs, etc.)
- **Add new plugins** — install any unused plugin directly from the panel
- **Bar position** — change bar position (top/bottom/left/right)
- **Safety first** — validates JSON and asks for confirmation before saving
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

## Setup

1. The bar manager icon (⚙) appears in the bar after installation
2. Click it to open the management panel
3. Use the tabs (Left / Center / Right / Add / Bar) to manage your layout
4. Click **Save** when done — the panel validates and confirms before writing

## Removal

```bash
omarchy plugin remove io.github.fullo.omarchy-bar-manager
```

## License

MIT

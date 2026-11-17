#  Mercurio

> **One-click AppImage installer & desktop integrator for Omarchy Linux.**

Mercurio is a native Omarchy Linux plugin that lives in your top bar as a theme-reactive planet icon. Click it or drop any `.AppImage` file, and Mercurio automatically validates the binary, extracts its original high-resolution vector or PNG icons, creates an XDG desktop entry, and integrates the app seamlessly into your Omarchy menu and dock.

---

##  Features

- **Theme-Reactive Planet Icon**: Renders an animated Mercury planet that dynamically adapts to your active Omarchy theme colors.
- **Drag & Drop or File Picker**: Easily select any AppImage via file dialog (`zenity`) or drag it onto the card.
- **High-Res Icon Extraction**: Automatically inspects `.DirIcon`, root PNGs/SVGs, and internal icon hierarchies to extract crisp, full-resolution icons into `~/.local/share/icons/hicolor/`.
- **Instant Menu Integration**: Registers `.desktop` files in `~/.local/share/applications/` and updates the desktop database immediately.
- **Launch from UI**: Launch the app or open its folder right after installation.

---

##  Installation

### Option 1: Native Omarchy Command (Recommended)

Run this in your terminal:

```bash
omarchy plugin install https://github.com/alvyn16/mercurio --enable
```

Omarchy will prompt you to choose where you want the planet icon on your top bar (left, center, tray, or right).

### Option 2: One-Line Curl

```bash
curl -fsSL https://raw.githubusercontent.com/alvyn16/mercurio/main/install.sh | bash
```

---

##  Usage

1. Click the **Planet icon** on your top bar.
2. Click **Select .AppImage** (or drag and drop your file).
3. Mercurio installs the executable into `~/.local/share/appimages/` and registers the app in your Omarchy menu with its original icon.
4. Open your Omarchy launcher (`Super` / Menu) to find your newly installed app!

---

##  License

MIT © [Alvyn](https://github.com/alvyn16)

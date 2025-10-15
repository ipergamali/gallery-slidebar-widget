# 🌄 Gallery Slidebar Widget

A minimal and elegant **KDE Plasma 6 widget** that displays your favorite pictures in a smooth sliding gallery right on your desktop.  
Developed with **QML** and **Kirigami**, this widget brings a clean and modern photo experience to your Plasma workspace.

---

## ✨ Features

- 🖼️ Displays images from your **Pictures** folder (or any custom path)
- 🎞️ Smooth horizontal **slidebar animation**
- 🌓 Adapts automatically to **light and dark Plasma themes**
- 🖱️ Click on an image to open it in your default viewer
- 🔁 Auto-refresh of new images in the folder
- ⚙️ Lightweight and optimized for Plasma 6

---

## 🧩 Installation

### 🪄 From KDE Plasma (Recommended)
1. Right-click on the desktop → **Add Widgets**
2. Click **“Get New Widgets…” → “Download New Plasma Widgets”**
3. Search for **“Gallery Slidebar”** and install it directly

### 🧰 Manual Installation
If you cloned or downloaded the source:
```bash
kpackagetool6 --type Plasma/Applet --install ~/path/to/gallery-slidebar-widget
```
> ℹ️ **Εξάρτηση KIO QML:** Για να ανοίγουν τα αρχεία εικόνας στον προεπιλεγμένο προβολέα εκτός του plasmoid, βεβαιώσου ότι στο σύστημα Plasma 6 είναι εγκατεστημένο το πακέτο `qml6-module-org-kde-kio`.

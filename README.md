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

### ℹ️ QtQuick Controls import
Στο Plasma 6 / Qt 6 τα στοιχεία των QtQuick Controls πρέπει να εισάγονται ρητά. Μπορείς είτε να χρησιμοποιήσεις alias:

```qml
import QtQuick.Controls 6.5 as Controls

Controls.Menu {
    Controls.MenuItem { text: qsTr("Άνοιγμα") }
    Controls.MenuItem { text: qsTr("Αφαίρεση") }
}
```

ή να αποφύγεις το alias και να χρησιμοποιήσεις απευθείας τους τύπους:

```qml
import QtQuick.Controls 6.5

Menu {
    MenuItem { text: qsTr("Άνοιγμα") }
    MenuItem { text: qsTr("Αφαίρεση") }
}
```

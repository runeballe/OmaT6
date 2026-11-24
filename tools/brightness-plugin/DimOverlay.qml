import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Software dimming for a screen with neither DDC/CI nor gamma control, such as
// one on an MCT T6 USB adapter (an EVDI virtual output, DVI-I-N in Hyprland).
// The bundled brightness-display writes the level (10-100) to
// ~/.local/state/omat6-brightness/overlay-<screen name>; this draws a
// click-through black layer over that one screen with opacity 1 - level/100.
//
// The bar has one widget per screen, so each instance only dims the screen its
// own bar is on. That keeps the layers from stacking.
Item {
  id: root

  property var targetScreen: null

  // Same rule as brightness-display: OMAT6_OVERLAY_MONITORS if set, else DVI-I-*.
  readonly property var overrideNames: {
    var v = String(Quickshell.env("OMAT6_OVERLAY_MONITORS") || "").trim()
    return v === "" ? [] : v.split(/\s+/)
  }
  readonly property string screenName: targetScreen ? String(targetScreen.name) : ""
  readonly property bool active: {
    if (!/^[A-Za-z0-9-]+$/.test(screenName)) return false
    if (overrideNames.length > 0) return overrideNames.indexOf(screenName) !== -1
    return screenName.indexOf("DVI-I-") === 0
  }
  readonly property string stateDir: {
    var xdg = String(Quickshell.env("XDG_STATE_HOME") || "")
    return (xdg !== "" ? xdg : Quickshell.env("HOME") + "/.local/state") + "/omat6-brightness"
  }

  property int level: 100

  function parse(text) {
    var v = parseInt(String(text).trim(), 10)
    level = isNaN(v) ? 100 : Math.max(10, Math.min(100, v))
  }

  FileView {
    path: root.active ? root.stateDir + "/overlay-" + root.screenName : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.level = 100
  }

  Loader {
    active: root.active && root.level < 100

    sourceComponent: PanelWindow {
      screen: root.targetScreen
      color: Qt.rgba(0, 0, 0, 1 - root.level / 100)
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "omat6-dim-overlay"
      // Empty input region: every click goes through to the windows below.
      mask: Region {}
      anchors { top: true; left: true; right: true; bottom: true }
    }
  }
}

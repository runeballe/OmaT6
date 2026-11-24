import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon with a popup holding one brightness slider per connected display.
// All work happens in the `display-brightness` helper next to this file, which
// wraps the bundled brightness-display (overlay for T6 screens, Omarchy brightness for the rest).
Panel {
  id: root
  moduleName: "io.github.runeballe.omat6-brightness"
  ipcTarget: "io.github.runeballe.omat6-brightness"

  readonly property string helper: Qt.resolvedUrl("display-brightness").toString().replace(/^file:\/\//, "")
  readonly property string scrollMonitor: String(setting("scrollMonitor", "DVI-I-1"))
  readonly property color dim: Qt.darker(bar ? bar.foreground : Color.foreground, 1.4)

  property var monitors: []
  property string error: ""
  property var queued: null           // { name, value } waiting for the running write
  property real wheelAccumulator: 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function valueOf(name) {
    for (var i = 0; i < monitors.length; i++)
      if (monitors[i].name === name) return monitors[i].value
    return null
  }

  function apply(text) {
    var data
    try { data = JSON.parse(text) } catch (e) { error = "No answer from helper"; return }
    if (!data.ok) { error = String(data.error || "Unknown error").slice(0, 120); return }
    error = ""
    if (Array.isArray(data.monitors)) {
      var list = []
      for (var i = 0; i < data.monitors.length && i < 8; i++) {
        var m = data.monitors[i]
        list.push({
          name: String(m.name || "").slice(0, 32),
          description: String(m.description || "").slice(0, 64),
          value: (typeof m.value === "number") ? Math.max(0, Math.min(100, m.value)) : null
        })
      }
      monitors = list
    }
  }

  function refresh() {
    if (!readProc.running && !writeProc.running) readProc.running = true
  }

  // Dragging fires many values; send one at a time and keep only the newest.
  function setLevel(name, value) {
    value = Math.max(1, Math.min(100, Math.round(value)))
    var next = []
    for (var i = 0; i < monitors.length; i++) {
      var m = Object.assign({}, monitors[i])
      if (m.name === name) m.value = value
      next.push(m)
    }
    monitors = next
    if (writeProc.running) { queued = { name: name, value: value }; return }
    writeProc.command = [helper, "set", name, String(value)]
    writeProc.running = true
  }

  onOpenedChanged: if (opened) refresh()
  Component.onCompleted: refresh()

  Process {
    id: readProc
    command: [root.helper, "list"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
  }

  Process {
    id: writeProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: if (!root.queued) root.apply(text) }
    onExited: {
      if (!root.queued) return
      var q = root.queued
      root.queued = null
      root.setLevel(q.name, q.value)
    }
  }

  // Dims this bar's own screen when it is a T6 / EVDI screen (DVI-I-*, or the
  // names in OMAT6_OVERLAY_MONITORS), matching the bundled brightness-display.
  DimOverlay {
    targetScreen: root.QsWindow.window ? root.QsWindow.window.screen : null
  }

  // Pick up changes made with the keyboard shortcuts while the popup is open.
  Timer { interval: 3000; repeat: true; running: root.opened; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(0xF00E0)
    tooltipText: {
      var v = root.valueOf(root.scrollMonitor)
      return v !== null ? "Brightness · " + root.scrollMonitor + " " + v + "%" : "Display brightness"
    }
    onPressed: function(b) { root.toggle() }
    onWheelMoved: function(delta) {
      var current = root.valueOf(root.scrollMonitor)
      if (current === null) { root.refresh(); return }
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps !== 0) root.setLevel(root.scrollMonitor, current + wheel.steps * 5)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(400))

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          text: "Display brightness"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          visible: root.error !== ""
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: root.error
          color: Color.urgent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.monitors

          Column {
            id: row
            required property var modelData
            width: content.width
            spacing: Style.space(4)

            Text {
              width: parent.width
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: row.modelData.name + " · " + row.modelData.description
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Item {
              width: parent.width
              height: row.modelData.value === null ? unsupported.implicitHeight : slider.implicitHeight

              Text {
                id: unsupported
                visible: row.modelData.value === null
                textFormat: Text.PlainText
                text: "Brightness control not available"
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }

              PanelSlider {
                id: slider
                visible: row.modelData.value !== null
                anchors.left: parent.left
                anchors.right: number.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                bar: root.bar
                minimum: 1
                maximum: 100
                step: 1
                integer: true
                value: row.modelData.value || 0
                onMoved: function(v) { root.setLevel(row.modelData.name, v) }
                onReleased: function(v) { root.setLevel(row.modelData.name, v) }
                // Right-click jumps back to full brightness.
                onRightClicked: root.setLevel(row.modelData.name, 100)
              }

              Text {
                id: number
                visible: row.modelData.value !== null
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(36)
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                text: Math.round(slider.dragging ? slider.liveValue : (row.modelData.value || 0)) + "%"
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: "Right-click a slider for 100%."
          color: root.dim
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}

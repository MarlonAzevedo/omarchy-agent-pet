import QtQuick
import Quickshell.Io

Item {
  id: root
  visible: false
  required property string path
  property var record: null

  FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var value = JSON.parse(String(text() || ""))
        root.record = value && typeof value === "object" ? value : null
      } catch (error) {
        root.record = null
      }
    }
    onLoadFailed: root.record = null
  }
}

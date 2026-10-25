pragma Singleton
import QtQuick
QtObject {
  property color foreground: "#ffd8b8"; property color accent: "#8a9bff"; property color urgent: "#e0605a"
  readonly property QtObject popups: QtObject { property color background: "#070b1c" }
}

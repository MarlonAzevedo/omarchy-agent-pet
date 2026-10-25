import QtQuick
import "Model.js" as Model

Item {
  id: root

  property string petState: "idle"
  property color inkColor: "#202630"
  property color outlineColor: inkColor
  property color bodyColor: "#f3e5c8"
  property color faceColor: "#e7b744"
  property color accentColor: "#79bdc5"
  property color warningColor: "#e06a59"
  property int frame: 0
  readonly property var rows: Model.petRows(petState, frame)

  implicitWidth: 16
  implicitHeight: 16
  clip: true

  function pixelColor(pixel) {
    if (pixel === "O") return outlineColor
    if (pixel === "E" || pixel === "C") return inkColor
    if (pixel === "B") return bodyColor
    if (pixel === "F") return faceColor
    if (pixel === "A" || pixel === "Z") return accentColor
    if (pixel === "X") return warningColor
    return "transparent"
  }

  onPetStateChanged: {
    frame = 0
  }

  Timer {
    interval: root.petState === "working" ? 280 : root.petState === "attention" || root.petState === "limit" ? 420 : 0
    running: interval > 0
    repeat: true
    onTriggered: root.frame = 1 - root.frame
  }

  Repeater {
    model: 256
    delegate: Rectangle {
      required property int index
      readonly property string pixel: root.rows[Math.floor(index / 16)].charAt(index % 16)

      x: (index % 16) * width
      y: Math.floor(index / 16) * height
      width: root.width / 16
      height: root.height / 16
      color: root.pixelColor(pixel)
      visible: pixel !== "."
    }
  }
}

import QtQuick
import "Model.js" as Model

Item {
  id: root

  property string character: "computer"
  property string petState: "idle"
  property color inkColor: "#202630"
  property color outlineColor: inkColor
  property color bodyColor: "#f3e5c8"
  property color faceColor: "#e7b744"
  property color accentColor: "#79bdc5"
  property color warningColor: "#e06a59"
  property int frame: 0
  readonly property var rows: Model.petRows(petState, frame, character, width >= 32)
  readonly property int gridSize: rows.length

  implicitWidth: 16
  implicitHeight: 16
  clip: true

  function pixelColor(pixel) {
    if (pixel === "O") return outlineColor
    if (pixel === "E" || pixel === "C") return inkColor
    if (pixel === "B") return bodyColor
    if (pixel === "H") return Qt.lighter(bodyColor, 1.18)
    if (pixel === "S") return Qt.darker(bodyColor, 1.4)
    if (pixel === "F") return faceColor
    if (pixel === "G") return Qt.lighter(faceColor, 1.25)
    if (pixel === "D") return Qt.darker(faceColor, 1.35)
    if (pixel === "A" || pixel === "Z") return accentColor
    if (pixel === "X") return warningColor
    return "transparent"
  }

  onCharacterChanged: frame = 0

  onPetStateChanged: {
    frame = 0
  }

  Timer {
    interval: root.petState === "working" ? 280 : root.petState === "attention" || root.petState === "limit" ? 420 : 0
    running: interval > 0
    repeat: true
    onTriggered: root.frame = (root.frame + 1) % (root.character === "robot" ? 4 : 2)
  }

  Repeater {
    model: root.gridSize * root.gridSize
    delegate: Rectangle {
      required property int index
      readonly property string pixel: root.rows[Math.floor(index / root.gridSize)].charAt(index % root.gridSize)

      x: Math.round((index % root.gridSize) * root.width / root.gridSize)
      y: Math.round(Math.floor(index / root.gridSize) * root.height / root.gridSize)
      width: Math.round((index % root.gridSize + 1) * root.width / root.gridSize) - x
      height: Math.round((Math.floor(index / root.gridSize) + 1) * root.height / root.gridSize) - y
      color: root.pixelColor(pixel)
      visible: pixel !== "."
    }
  }
}

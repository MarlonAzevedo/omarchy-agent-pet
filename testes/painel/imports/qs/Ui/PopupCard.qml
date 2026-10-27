import QtQuick
Rectangle {
  property var anchorItem; property var owner; property var bar; property bool open; property string triggerMode
  property int contentWidth; property int contentHeight; property bool centerOnBar
  objectName: "card"
  width: contentWidth; height: contentHeight; color: "#070b1c"; border.color: "#8a9bff"; radius: 8
  property real availableCardWidth: 0
  property real availableCardHeight: 0
  function fittedContentWidth(w) { return availableCardWidth > 0 ? Math.min(w, availableCardWidth) : w }
  function cappedContentHeight(h) { return availableCardHeight > 0 ? Math.min(h, availableCardHeight) : h }
  function fittedContentHeight(h, cap) { return Math.min(h + 32, cap) }
  default property alias content: holder.data
  Item { id: holder; anchors.fill: parent; anchors.margins: 16 }
}

pragma Singleton
import QtQuick
QtObject {
  // Aponta para o Main.qml falso de testes/painel/shell, que não roda coletores
  readonly property string shellDir: Qt.resolvedUrl("../../shell").toString().replace("file://", "")
  function env(name) { return name === "HOME" ? "/nonexistent" : "" }
}

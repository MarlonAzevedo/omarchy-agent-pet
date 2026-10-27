// Uso: QT_QPA_PLATFORM=offscreen qml6 testes/painel/robot-animation.qml
import QtQuick
import QtQuick.Window
import "../.."

Window {
  id: test
  visible: true
  width: 200
  height: 200
  property string initialRows: ""
  property int step: 0
  Pet { id: pet; character: "robot"; width: 192; height: 192 }
  Timer {
    interval: 900
    running: true
    repeat: true
    onTriggered: {
      if (test.step === 0) {
        if (pet.frame !== 0) { console.error("Robô ocioso se move sem atividade da IA"); Qt.exit(1); return }
        pet.petState = "working"
      } else if (test.step === 1) {
        if (!pet.frame) { console.error("Robô trabalhando sem animação"); Qt.exit(1); return }
        test.initialRows = pet.rows.join("")
      } else if (test.step === 2) {
        if (pet.rows.join("") === test.initialRows) { console.error("Quadros do robô não mudam"); Qt.exit(1); return }
        pet.petState = "idle"
      } else {
        if (pet.frame !== 0) { console.error("Robô continuou animando após a IA parar"); Qt.exit(1); return }
        console.log("Robô ocioso parado; anima durante o trabalho e para ao terminar")
        Qt.quit()
      }
      test.step++
    }
  }
}

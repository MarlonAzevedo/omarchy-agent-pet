// Uso: QT_QPA_PLATFORM=offscreen qml6 -I testes/painel/imports testes/painel/alignment.qml
import QtQuick
import QtQuick.Window

Window {
  id: test
  width: 500
  height: 750
  visible: true
  property int step: 0
  property int failures: 0
  property real baselineWidth: 0
  property real baselineHeight: 0
  property real menuY: 0
  property var screens: ["agents", "home", "sessions", "limits", "usage", "attention", "about", "home-focus", "sessions-long"]
  Loader { id: loader; source: "../../Panel.qml" }

  function findText(item, text) {
    if (item.text === text) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = findText(item.children[i], text)
      if (found) return found
    }
    return null
  }
  function expect(condition, message) {
    if (!condition) { failures++; console.error(message) }
  }
  function findItem(item, name) {
    if (item.objectName === name) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = findItem(item.children[i], name)
      if (found) return found
    }
    return null
  }
  Timer {
    interval: 150
    running: true
    repeat: true
    onTriggered: {
      var panel = loader.item
      if (!panel) { test.expect(false, "Panel.qml não carregou"); Qt.exit(1); return }
      var index = Math.floor(test.step / 2)
      var screen = test.screens[index % test.screens.length]
      var portuguese = index < test.screens.length || index >= test.screens.length * 2
      var small = index >= test.screens.length * 2
      if (test.step % 2 === 0) {
        var popup = test.findItem(panel, "card")
        popup.availableCardHeight = small ? 400 : 0
        if (index === test.screens.length * 2) test.baselineWidth = 0
        panel.screen = screen.split("-")[0]
        panel.config = { language: portuguese ? "pt" : "en", character: "dog" }
        panel.pomodoro = screen === "home-focus" ? { work_min: 25, break_min: 5, rounds: 4, started_at: Date.now(), paused_at: null } : {}
        panel.sessions = screen === "sessions-long" ? Array.from({ length: 30 }, function(_, i) { return { session_id: "session-" + i, cwd: "/project/" + i, status: "idle" } }) : []
      } else {
        var card = test.findItem(panel, "card")
        var menu = test.findText(panel, "ⓘ")
        test.expect(!!card && !!menu, "Painel/menu ausente")
        if (card && menu) {
          if (!test.baselineWidth) {
            test.baselineWidth = card.width
            test.baselineHeight = card.height
            test.menuY = menu.mapToItem(card, 0, 0).y
          }
          test.expect(card.width === test.baselineWidth && card.height === test.baselineHeight, "Tamanho diferente em " + screen)
          test.expect(Math.abs(menu.mapToItem(card, 0, 0).y - test.menuY) < 1, "Menu mudou de posição em " + screen)
          test.expect(menu.mapToItem(card, 0, 0).y + menu.height <= card.height - 8, "Menu fora do painel em " + screen)
        }
        var viewport = test.findItem(panel, "screenViewport")
        test.expect(!!viewport, "Área de rolagem ausente")
        if (viewport) {
          if (screen === "sessions-long") {
            test.expect(viewport.contentHeight > viewport.height, "Lista longa sem rolagem")
            var scrollbar = test.findItem(panel, "contentScrollBar")
            test.expect(!!scrollbar && scrollbar.visible && scrollbar.size < 1, "Lista longa sem barra de rolagem")
            viewport.contentY = 50
            if (scrollbar) {
              scrollbar.increase()
              test.expect(viewport.contentY > 50, "Barra não controla a rolagem")
            }
            test.expect(Math.abs(menu.mapToItem(card, 0, 0).y - test.menuY) < 1, "Rolagem moveu o menu")
          } else {
            test.expect(viewport.contentY === 0, "Troca de tela manteve a rolagem anterior")
            if (viewport.contentHeight <= viewport.height) {
              var shortBar = test.findItem(panel, "contentScrollBar")
              test.expect(!!shortBar && !shortBar.visible, "Barra visível sem conteúdo excedente")
            }
          }
        }
        if (small) test.expect(card.height <= 400, "Painel excede altura disponível")
        if (screen === "agents") {
          var title = test.findText(panel, portuguese ? "Personagem" : "Character")
          var language = test.findText(panel, portuguese ? "Idioma" : "Language")
          var discreet = test.findText(panel, portuguese ? "Modo discreto" : "Discreet mode")
          test.expect(!!title && !!language && !!discreet, "Títulos ausentes")
          if (title && language && discreet) {
            var x = title.mapToItem(panel, 0, 0).x
            test.expect(Math.abs(x - language.mapToItem(panel, 0, 0).x) < 1, "Personagens desalinhados com Idioma")
            test.expect(Math.abs(x - discreet.mapToItem(panel, 0, 0).x) < 1, "Personagens desalinhados com Modo discreto")
            var labels = portuguese ? ["Computador", "Gato", "Robô", "Cachorro"] : ["Computer", "Cat", "Robot", "Dog"]
            labels.forEach(function(text) {
              var label = test.findText(panel, text)
              test.expect(!!label && label.implicitWidth <= label.parent.parent.width - 4, "Nome cortado: " + text)
            })
          }
        }
      }
      test.step++
      if (test.step === test.screens.length * 6) {
        if (!test.failures) console.log("Alinhamento, tamanho das telas, menu fixo e altura reduzida: passaram")
        Qt.exit(test.failures ? 1 : 0)
      }
    }
  }
}

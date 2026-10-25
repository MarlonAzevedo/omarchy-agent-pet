// Renderiza cada tela do painel com dados de teste, fora do Omarchy Shell.
// Uso: QT_QPA_PLATFORM=offscreen qml6 -I testes/painel/imports testes/painel/render.qml -- <pasta-de-saída>
import QtQuick
import QtQuick.Window
Window {
  id: w
  width: 400; height: 700; visible: true; color: "#000"
  Loader { id: loader; source: "../../Panel.qml" }
  // "tela@agente" escolhe o agente dos gráficos
  property var screens: ["home", "sessions", "limits", "attention", "agents", "home@codex", "limits@codex"]
  readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
  property int step: 0
  function findCard(item) {
    if (!item) return null
    if (item.objectName === "card") return item
    for (var i = 0; i < item.children.length; i++) { var f = findCard(item.children[i]); if (f) return f }
    return null
  }
  Timer {
    id: t; interval: 400; running: true; repeat: true
    onTriggered: {
      var p = loader.item
      var now = Date.now()
      if (p.sessions.length === 0) {
        p.usageRecords = [
          { id: "claude", name: "Claude Code", tierLabel: "Pro", limits: [
            { label: "Session (5-hour)", percent: 0.78, resetsAt: new Date(now + 130 * 60000).toISOString() },
            { label: "Weekly (7-day)", percent: 0.41, resetsAt: new Date(now + 5 * 86400000).toISOString() } ] },
          { id: "codex", name: "Codex", tierLabel: "free", limits: [{ label: "720h window", percent: 0.62, resetsAt: new Date(now + 20 * 86400000).toISOString() }] },
          { id: "fireworks", name: "Fireworks", tierLabel: "Prepaid", usageStatusText: "Fireworks unavailable", limits: [] } ]
        p.sessions = [
          { session_id: "a", status: "working", cwd: "/x/landing-page", current_tool: "Edit", tool_detail: "Hero.tsx", activity_started_at: now - 190000, updated_at: now },
          { session_id: "b", agent: "codex", status: "working", cwd: "/x/worker", current_tool: "Bash", tool_detail: "npm test", activity_started_at: now - 20000, updated_at: now - 1 },
          { session_id: "c", status: "attention", attention_reason: "permission", cwd: "/x/checkout", current_tool: "Bash", tool_detail: "npm run migrate", activity_started_at: now - 30000, updated_at: now - 2 } ]
        p.config = ({ hidden_agents: ["fireworks"] })
        p.daily = ({ completed_responses: 12, active_seconds: 5400 })
        return
      }
      // Passos ímpares trocam a tela; pares capturam (o grab desenha no quadro seguinte)
      var index = Math.floor(w.step / 2)
      if (index >= w.screens.length) { t.stop(); Qt.quit(); return }
      var parts = w.screens[index].split("@")
      if (w.step % 2 === 0) {
        p.screen = parts[0]
        p.selectedAgent = parts[1] || ""
      } else {
        var name = w.screens[index].replace("@", "-")
        findCard(p).grabToImage(function(r) { r.saveToFile(w.outDir + "/" + name + ".png") })
      }
      w.step++
    }
  }
}

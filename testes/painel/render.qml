// Renderiza cada tela do painel com dados de teste, fora do Omarchy Shell.
// Uso: QT_QPA_PLATFORM=offscreen qml6 -I testes/painel/imports testes/painel/render.qml -- <pasta-de-saída>
import QtQuick
import QtQuick.Window
Window {
  id: w
  width: 400; height: 700; visible: true; color: "#000"
  Loader { id: loader; source: "../../Panel.qml" }
  // "tela@agente" escolhe o agente dos gráficos; "tela#foco" mostra um foco em andamento
  property var screens: ["home", "sessions", "limits", "attention", "agents", "home@codex", "limits@codex", "usage", "usage@codex", "about", "home#foco"]
  readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
  property int step: 0
  // Últimos 7 dias terminando hoje
  function week(tokens) {
    return tokens.map(function(count, i) { return { date: Qt.formatDate(new Date(Date.now() - (6 - i) * 86400000), "yyyy-MM-dd"), messageCount: count } })
  }
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
          { id: "claude", name: "Claude Code", tierLabel: "Pro", todayPrompts: 15, todaySessions: 2, todayTotalTokens: 2400000,
            recentDays: w.week([800000, 0, 1200000, 3100000, 600000, 1900000, 2400000]),
            modelUsage: { "Opus 5.5": { inputTokens: 900000, outputTokens: 300000, cacheReadInputTokens: 7000000 }, "Haiku 5.5": { outputTokens: 400000 } }, limits: [
            { label: "Session (5-hour)", percent: 0.78, resetsAt: new Date(now + 130 * 60000).toISOString() },
            { label: "Weekly (7-day)", percent: 0.41, resetsAt: new Date(now + 5 * 86400000).toISOString() } ] },
          { id: "codex", name: "Codex", tierLabel: "free", todayPrompts: 4, todaySessions: 1, todayTotalTokens: 500000,
            recentDays: w.week([0, 0, 0, 0, 0, 0, 500000]), modelUsage: { "GPT 6 Luna": { inputTokens: 400000, outputTokens: 100000 } }, limits: [{ label: "720h window", percent: 0.62, resetsAt: new Date(now + 20 * 86400000).toISOString() }] },
          { id: "fireworks", name: "Fireworks", tierLabel: "Prepaid", usageStatusText: "Fireworks unavailable", limits: [] } ]
        p.sessions = [
          { session_id: "a", status: "working", cwd: "/x/landing-page", current_tool: "Edit", tool_detail: "Hero.tsx", activity_started_at: now - 190000, updated_at: now },
          { session_id: "b", agent: "codex", status: "working", cwd: "/x/worker", current_tool: "Bash", tool_detail: "npm test", activity_started_at: now - 20000, updated_at: now - 1 },
          { session_id: "c", status: "attention", attention_reason: "permission", cwd: "/x/checkout", current_tool: "Bash", tool_detail: "npm run migrate", activity_started_at: now - 30000, updated_at: now - 2 } ]
        p.config = ({ hidden_agents: ["fireworks"] })
        // O FileView de teste não lê arquivos; o manifest real vem daqui
        p.manifest = ({ name: "Retro Agent Pet", version: "0.3.0", author: "Marlon Azevedo", license: "MIT", homepage: "https://github.com/MarlonAzevedo/omarchy-retro-agent-pet" })
        p.daily = ({ completed_responses: 12, active_seconds: 5400 })
        return
      }
      // Passos ímpares trocam a tela; pares capturam (o grab desenha no quadro seguinte)
      var index = Math.floor(w.step / 2)
      if (index >= w.screens.length) { t.stop(); Qt.quit(); return }
      var focused = w.screens[index].indexOf("#foco") >= 0
      var parts = w.screens[index].replace("#foco", "").split("@")
      if (w.step % 2 === 0) {
        p.screen = parts[0]
        p.selectedAgent = parts[1] || ""
        p.pomodoro = focused ? ({ work_min: 25, break_min: 5, rounds: 4, started_at: now - 35 * 60000 - 6 * 60000 - 32000, paused_at: null }) : ({})
      } else {
        var name = w.screens[index].replace("@", "-").replace("#", "-")
        findCard(p).grabToImage(function(r) { r.saveToFile(w.outDir + "/" + name + ".png") })
      }
      w.step++
    }
  }
}

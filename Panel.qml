import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons as Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.marlonazevedo.agent-pet"
  ipcTarget: "io.github.marlonazevedo.agent-pet"
  manageIpc: false

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"
  readonly property string sessionsDir: stateHome + "/agent-pet/sessions"
  readonly property string usageDir: stateHome + "/omarchy/agents/usage"
  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/agent-pet/config.json"
  property var config: ({})
  readonly property var hiddenAgents: Array.isArray(config.hidden_agents) ? config.hidden_agents : []
  // Tela do painel: home, sessions, limits, agents ou attention
  property string screen: "home"
  property var sessionFiles: []
  property var sessions: []
  property var usageFiles: []
  property var usageRecords: []
  property var daily: ({ date: "", completed_responses: 0, active_seconds: 0 })
  property double nowMs: Date.now()

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color surface: Commons.Color.popups.background
  // Sessões dos agentes não ocultos na tela Agentes
  readonly property var shownSessions: Model.visibleSessions(sessions, hiddenAgents)
  readonly property var orderedSessions: Model.sortSessions(shownSessions)
  readonly property bool attention: Model.hasAttention(shownSessions)
  readonly property bool alarm: attention || Model.alarmingLimit(allLimits, 90)
  readonly property string computedPetState: Model.petState(shownSessions, allLimits, nowMs)
  property string petState: "idle"
  readonly property color secondTint: Qt.hsla((Math.max(0, Commons.Color.accent.hslHue) + 0.12) % 1, Math.max(0.35, Commons.Color.accent.hslSaturation), Commons.Color.accent.hslLightness, 1)
  // Gráficos por agente: o seletor escolhe de quem são os limites mostrados
  property string selectedAgent: ""
  readonly property var limitRecords: Model.limitRecords(usageRecords, hiddenAgents)
  readonly property var currentRecord: Model.pickRecord(limitRecords, selectedAgent)
  readonly property var agentLimits: currentRecord ? currentRecord.limits : []
  readonly property var allLimits: {
    var result = []
    var records = Model.visibleRecords(usageRecords, hiddenAgents)
    for (var i = 0; i < records.length; i++)
      if (records[i] && Array.isArray(records[i].limits)) result = result.concat(records[i].limits)
    return result
  }

  Process {
    id: sessionScan
    command: ["find", root.sessionsDir, "-maxdepth", "1", "-name", "*.json", "-printf", "%p\\n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.sessionFiles = String(text || "").split("\n").filter(function(path) { return path.endsWith(".json") })
    }
  }
  Process {
    id: usageScan
    command: ["find", root.usageDir, "-maxdepth", "1", "-name", "*.json", "-printf", "%p\\n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.usageFiles = String(text || "").split("\n").filter(function(path) { return path.endsWith(".json") })
    }
  }

  Instantiator {
    id: sessionInstantiator
    model: root.sessionFiles
    delegate: SessionRecord {
      required property var modelData
      path: modelData
      onRecordChanged: root.collectSessions()
    }
    onObjectAdded: root.collectSessions()
    onObjectRemoved: root.collectSessions()
  }
  Instantiator {
    id: usageInstantiator
    model: root.usageFiles
    delegate: SessionRecord {
      required property var modelData
      path: modelData
      onRecordChanged: root.collectUsage()
    }
    onObjectAdded: root.collectUsage()
    onObjectRemoved: root.collectUsage()
  }

  function collectSessions() {
    var result = []
    for (var i = 0; i < sessionInstantiator.count; i++) {
      var record = sessionInstantiator.objectAt(i)
      if (record && record.record) result.push(record.record)
    }
    sessions = result
  }
  function collectUsage() {
    var result = []
    for (var i = 0; i < usageInstantiator.count; i++) {
      var record = usageInstantiator.objectAt(i)
      if (record && record.record) result.push(record.record)
    }
    usageRecords = result
  }
  function readDaily() {
    dailyFile.path = stateHome + "/agent-pet/day/" + Qt.formatDate(new Date(), "yyyy-MM-dd") + ".json"
    dailyFile.reload()
  }

  FileView {
    id: dailyFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.daily = JSON.parse(String(text() || "{}")) }
      catch (error) { root.daily = ({ date: "", completed_responses: 0, active_seconds: 0 }) }
    }
  }
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.config = JSON.parse(String(text() || "{}")) || ({}) }
      catch (error) { root.config = ({}) }
    }
  }
  // Mostra ou oculta um agente nas telas; preserva as demais chaves do config
  function toggleAgent(id) {
    var hidden = hiddenAgents.slice()
    var index = hidden.indexOf(id)
    if (index < 0) hidden.push(id)
    else hidden.splice(index, 1)
    var next = Object.assign({}, config, { hidden_agents: hidden })
    config = next
    configFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.nowMs = Date.now()
      if (!sessionScan.running) sessionScan.running = true
      if (!usageScan.running) usageScan.running = true
      root.readDaily()
    }
  }

  visible: shownSessions.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) close(); else open() }

  onAttentionChanged: root.screen = root.attention ? "attention" : (root.screen === "attention" ? "home" : root.screen)
  Component.onCompleted: {
    root.petState = root.computedPetState
    if (root.attention) root.screen = "attention"
  }
  onComputedPetStateChanged: {
    if (root.petState === "working" && root.computedPetState === "idle") {
      root.petState = "done"
      doneTimer.restart()
    } else {
      doneTimer.stop()
      root.petState = root.computedPetState
    }
  }

  Timer {
    id: doneTimer
    interval: 1800
    onTriggered: root.petState = root.computedPetState
  }

  // Medidor circular de um limite: arco de 270°, percentual, janela e renovação
  component Gauge: Item {
    id: gauge
    required property var limit
    property color tint: Commons.Color.accent
    property real size: 132
    property string caption: Model.windowShort(limit.label)
    readonly property real percent: Model.limitPercent(limit, root.nowMs)
    readonly property real stroke: Math.round(size / 13)
    readonly property real radius: size / 2 - stroke
    implicitWidth: size
    implicitHeight: size

    Shape {
      anchors.fill: parent
      ShapePath {
        strokeColor: Qt.alpha(root.foreground, 0.12)
        strokeWidth: gauge.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: gauge.width / 2; centerY: gauge.height / 2; radiusX: gauge.radius; radiusY: gauge.radius; startAngle: 135; sweepAngle: 270 }
      }
      ShapePath {
        strokeColor: gauge.percent >= 90 ? root.urgent : gauge.tint
        strokeWidth: gauge.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: gauge.width / 2; centerY: gauge.height / 2; radiusX: gauge.radius; radiusY: gauge.radius; startAngle: 135; sweepAngle: 270 * gauge.percent / 100 }
      }
    }
    Column {
      anchors.centerIn: parent
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(gauge.percent) + "%"; color: root.foreground; font.pixelSize: Math.round(gauge.size / 5); font.bold: true }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: gauge.caption; color: root.dim; font.pixelSize: Math.max(12, Math.round(gauge.size / 12)) }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      text: Model.resetLabel(gauge.limit.resetsAt, root.nowMs)
      color: root.dim
      font.pixelSize: Math.max(12, Math.round(gauge.size / 12))
    }
  }

  // Barra fina de um limite: janela, barra e percentual
  component LimitBar: RowLayout {
    id: limitBar
    required property var limit
    property color tint: Commons.Color.accent
    property bool labels: true
    readonly property real percent: Model.limitPercent(limit, root.nowMs)
    spacing: 6
    Text { visible: limitBar.labels; text: Model.windowShort(limitBar.limit.label); color: root.dim; font.pixelSize: 11 }
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 5
      radius: 3
      color: Qt.alpha(root.foreground, 0.12)
      Rectangle { width: parent.width * limitBar.percent / 100; height: parent.height; radius: 3; color: limitBar.percent >= 90 ? root.urgent : limitBar.tint }
    }
    Text { visible: limitBar.labels; text: Math.round(limitBar.percent) + "%"; color: root.foreground; font.pixelSize: 12; font.bold: true }
  }

  // Seletor de agente dos gráficos; some quando só um agente tem limites
  component AgentTabs: RowLayout {
    Layout.alignment: Qt.AlignHCenter
    visible: root.limitRecords.length > 1
    spacing: 6
    Repeater {
      model: root.limitRecords.length
      delegate: Rectangle {
        id: chip
        required property int index
        readonly property var record: root.limitRecords[index]
        readonly property bool current: root.currentRecord && root.currentRecord.id === record.id
        implicitWidth: chipText.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: current ? Qt.alpha(Commons.Color.accent, 0.2) : Qt.alpha(root.foreground, 0.06)
        Text { id: chipText; anchors.centerIn: parent; text: chip.record.name || chip.record.id; color: chip.current ? Commons.Color.accent : root.dim; font.pixelSize: 11; font.bold: chip.current }
        TapHandler { onTapped: root.selectedAgent = chip.record.id }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
      }
    }
  }

  // Item do menu inferior
  component MenuItem: Item {
    id: menuItem
    required property string target
    required property string label
    property bool badge: false
    readonly property bool current: root.screen === target
    Layout.fillWidth: true
    implicitHeight: 28
    Rectangle { anchors.fill: parent; radius: 6; color: Qt.alpha(Commons.Color.accent, menuItem.current ? 0.18 : (hover.hovered ? 0.08 : 0)) }
    Text { anchors.centerIn: parent; text: menuItem.label; color: menuItem.current ? Commons.Color.accent : root.dim; font.pixelSize: 12; font.bold: menuItem.current }
    Rectangle { visible: menuItem.badge; width: 6; height: 6; radius: 3; color: root.urgent; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4 }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.screen = menuItem.target }
  }

  // Cabeçalho das telas
  // fillWidth faz a coluna da tela ocupar a largura toda mesmo sem outros filhos largos
  component ScreenHeader: Text {
    required property string title
    property color titleColor: root.dim
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    text: title
    color: titleColor
    font.pixelSize: 13
    font.bold: true
    font.capitalization: Font.AllUppercase
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Pet {
        anchors.centerIn: parent
        width: 16
        height: 16
        petState: root.petState
        inkColor: root.surface
        bodyColor: root.foreground
        faceColor: Commons.Color.accent
        accentColor: root.petState === "attention" ? root.urgent : Commons.Color.accent
        warningColor: root.urgent
      }
    }
    active: root.attention || root.alarm
    onPressed: function(buttonCode) { root.toggle() }
    SequentialAnimation on opacity {
      running: root.attention
      loops: Animation.Infinite
      NumberAnimation { to: 0.45; duration: 450 }
      NumberAnimation { to: 1; duration: 450 }
      onStopped: button.opacity = 1
    }
  }

  PopupCard {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    triggerMode: "hover"
    contentWidth: 300
    contentHeight: panel.fittedContentHeight(column.implicitHeight, 620)

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      ColumnLayout {
        id: column
        width: parent.width
        spacing: 12

        // Início: agente grande e medidores
        ColumnLayout {
          visible: root.screen === "home"
          Layout.fillWidth: true
          spacing: 12
          Pet {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            petState: root.petState
            inkColor: root.surface
            outlineColor: root.dim
            bodyColor: root.foreground
            faceColor: Commons.Color.accent
            accentColor: root.petState === "attention" ? root.urgent : Commons.Color.accent
            warningColor: root.urgent
          }
          AgentTabs {}
          GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: Math.max(1, Math.min(2, root.agentLimits.length))
            columnSpacing: 12
            rowSpacing: 12
            Repeater {
              model: root.agentLimits
              delegate: Gauge {
                required property var modelData
                required property int index
                size: 118
                limit: modelData
                tint: index % 2 ? root.secondTint : Commons.Color.accent
              }
            }
          }
          Text { text: "Sem dados de limite"; visible: root.agentLimits.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Hoje · " + Number(root.daily.completed_responses || 0) + " respostas · " + Model.formatDuration(root.daily.active_seconds || 0)
            color: root.dim
            font.pixelSize: 12
          }
        }

        // Sessões: limites resumidos e um cartão por sessão
        ColumnLayout {
          visible: root.screen === "sessions"
          Layout.fillWidth: true
          spacing: 8
          ScreenHeader { title: "Sessões" }
          RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Repeater {
              model: root.agentLimits.slice(0, 2)
              delegate: LimitBar {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                limit: modelData
                tint: index % 2 ? root.secondTint : Commons.Color.accent
              }
            }
          }
          Repeater {
            model: root.orderedSessions
            delegate: Rectangle {
              id: card
              required property var modelData
              readonly property color statusColor: modelData.status === "attention" ? root.urgent : modelData.status === "working" ? Commons.Color.accent : root.dim
              readonly property var elapsed: Model.sessionElapsed(modelData, root.nowMs)
              Layout.fillWidth: true
              implicitHeight: cardText.implicitHeight + 16
              radius: 6
              color: Qt.alpha(root.foreground, 0.05)
              Rectangle { width: 3; height: parent.height; radius: 2; color: card.statusColor }
              ColumnLayout {
                id: cardText
                anchors.left: parent.left
                anchors.right: elapsedText.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 2
                RowLayout {
                  spacing: 6
                  Rectangle { width: 7; height: 7; radius: 4; color: card.statusColor }
                  Text { text: Model.sessionName(card.modelData); color: root.foreground; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                  Text { text: Model.agentLabel(card.modelData); color: root.dim; font.pixelSize: 10 }
                }
                Text { text: Model.activityText(card.modelData); color: card.modelData.status === "attention" ? root.urgent : root.dim; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
              }
              Text {
                id: elapsedText
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 8
                text: card.elapsed === null ? "" : Model.shortDuration(card.elapsed)
                color: root.dim
                font.pixelSize: 12
              }
            }
          }
          Text { text: "Nenhuma sessão ativa"; visible: root.shownSessions.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "● " + Model.runningCount(root.shownSessions) + " rodando · " + root.shownSessions.length + " no total"
            color: Commons.Color.accent
            font.pixelSize: 12
            font.bold: true
            font.capitalization: Font.AllUppercase
          }
        }

        // Limites: medidor grande, previsão no ritmo atual e demais janelas em barras
        ColumnLayout {
          visible: root.screen === "limits"
          Layout.fillWidth: true
          spacing: 8
          readonly property var main: root.agentLimits.length ? root.agentLimits[0] : null
          readonly property var depletion: main ? Model.depletionTime(main, root.nowMs) : null
          ScreenHeader { title: "Limites" }
          AgentTabs {}
          Gauge {
            visible: !!parent.main
            Layout.alignment: Qt.AlignHCenter
            size: 170
            limit: parent.main || ({})
          }
          Text {
            visible: parent.depletion !== null
            Layout.alignment: Qt.AlignHCenter
            text: "no ritmo atual, acaba às " + Qt.formatTime(new Date(parent.depletion || 0), "hh:mm")
            color: root.urgent
            font.pixelSize: 13
          }
          Repeater {
            model: root.agentLimits.slice(1)
            delegate: ColumnLayout {
              required property var modelData
              Layout.fillWidth: true
              spacing: 2
              RowLayout {
                Layout.fillWidth: true
                Text { text: modelData.label || "Limite"; color: root.foreground; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text {
                  text: Math.round(Model.limitPercent(modelData, root.nowMs)) + "%" + (Model.resetLabel(modelData.resetsAt, root.nowMs) ? " · " + Model.resetLabel(modelData.resetsAt, root.nowMs) : "")
                  color: root.dim
                  font.pixelSize: 12
                }
              }
              LimitBar { Layout.fillWidth: true; limit: modelData; tint: root.secondTint; labels: false }
            }
          }
          Text { text: "Sem dados de limite"; visible: root.agentLimits.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
        }

        // Precisa de você: sessão mais urgente e o que ela pediu
        ColumnLayout {
          visible: root.screen === "attention"
          Layout.fillWidth: true
          spacing: 8
          readonly property var waiting: root.orderedSessions.filter(function(session) { return session.status === "attention" })
          readonly property var first: waiting.length ? waiting[0] : null
          readonly property var elapsed: first ? Model.sessionElapsed(first, root.nowMs) : null
          ScreenHeader { title: "● Precisa de você"; titleColor: root.urgent }
          Text { text: parent.first ? Model.sessionName(parent.first) : ""; color: root.foreground; font.pixelSize: 26; font.bold: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
          Text { text: parent.first ? Model.activityText(parent.first) : ""; color: root.urgent; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter }
          Rectangle {
            visible: !!parent.first && parent.first.attention_reason === "permission"
            Layout.fillWidth: true
            implicitHeight: permissionLabel.implicitHeight + 16
            radius: 6
            color: Qt.alpha(root.foreground, 0.08)
            Text {
              id: permissionLabel
              anchors.fill: parent
              anchors.margins: 8
              text: parent.parent.first ? Model.permissionText(parent.parent.first) : ""
              color: root.foreground
              font.pixelSize: 13
              wrapMode: Text.WrapAnywhere
              horizontalAlignment: Text.AlignHCenter
            }
          }
          Text { text: parent.elapsed === null ? "" : "esperando há " + Model.shortDuration(parent.elapsed); color: root.dim; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
          Text { text: "Responda no " + (parent.first ? Model.agentLabel(parent.first) : "agente") + "; este painel continua aberto."; color: root.dim; font.pixelSize: 11; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
          Text {
            text: [parent.waiting.length > 1 ? "+" + (parent.waiting.length - 1) + " esperando" : "", Model.runningCount(root.shownSessions) ? "+" + Model.runningCount(root.shownSessions) + " rodando" : ""].filter(function(item) { return item }).join(" · ")
            color: root.dim
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
          }
          Text { text: "Nenhum pedido pendente"; visible: !parent.first; color: root.dim; Layout.alignment: Qt.AlignHCenter }
        }

        // Agentes: todos os registros de uso do Omarchy, com opção de mostrar/ocultar
        ColumnLayout {
          visible: root.screen === "agents"
          Layout.fillWidth: true
          spacing: 8
          ScreenHeader { title: "Agentes" }
          Repeater {
            model: root.usageRecords.length
            delegate: Rectangle {
              id: agentCard
              required property int index
              readonly property var modelData: root.usageRecords[index]
              readonly property bool shown: root.hiddenAgents.indexOf(modelData.id) < 0
              readonly property var limits: Array.isArray(modelData.limits) ? modelData.limits : []
              Layout.fillWidth: true
              implicitHeight: agentText.implicitHeight + 16
              radius: 6
              color: Qt.alpha(root.foreground, 0.05)
              opacity: shown ? 1 : 0.55
              ColumnLayout {
                id: agentText
                anchors.left: parent.left
                anchors.right: toggle.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 2
                Text { text: (agentCard.modelData.name || agentCard.modelData.id) + (agentCard.modelData.tierLabel ? " · " + agentCard.modelData.tierLabel : ""); color: root.foreground; font.pixelSize: 14; font.bold: true }
                Text {
                  readonly property int sessionCount: root.sessions.filter(function(session) { return (session.agent || "claude") === agentCard.modelData.id }).length
                  text: (agentCard.limits.length
                    ? agentCard.limits.map(function(limit) { return Model.windowShort(limit.label) + " " + Math.round(Model.limitPercent(limit, root.nowMs)) + "%" }).join(" · ")
                    : (agentCard.modelData.usageStatusText || "Sem limites"))
                    + (sessionCount ? " · " + sessionCount + (sessionCount === 1 ? " sessão" : " sessões") : "")
                  color: root.dim
                  font.pixelSize: 12
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
              Rectangle {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 18
                radius: 9
                color: agentCard.shown ? Commons.Color.accent : Qt.alpha(root.foreground, 0.2)
                Rectangle { width: 14; height: 14; radius: 7; y: 2; x: agentCard.shown ? parent.width - width - 2 : 2; color: root.surface }
                TapHandler { onTapped: root.toggleAgent(agentCard.modelData.id) }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
              }
            }
          }
          Text { text: "Nenhum agente encontrado"; visible: root.usageRecords.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
          Text { text: "Agentes ocultos saem das telas de início, sessões e limites."; color: root.dim; font.pixelSize: 11; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
        }

        // Menu inferior
        Rectangle { Layout.fillWidth: true; height: 1; color: root.dim; opacity: 0.35 }
        RowLayout {
          Layout.fillWidth: true
          spacing: 4
          MenuItem { target: "home"; label: "Início" }
          MenuItem { target: "sessions"; label: "Sessões"; badge: root.attention && root.screen !== "attention" }
          MenuItem { target: "limits"; label: "Limites" }
          MenuItem { target: "agents"; label: "Agentes" }
          MenuItem { target: "attention"; label: "Pedido"; visible: root.attention }
        }
      }
    }
  }
}

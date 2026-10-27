import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as Controls
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
  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/agent-pet/config.json"
  property var config: ({})
  readonly property string character: Model.characterId(config.character)
  readonly property var hiddenAgents: Array.isArray(config.hidden_agents) ? config.hidden_agents : []
  // Modo discreto: sem notificações e sem piscar o ícone
  readonly property bool discreet: config.discreet === true
  // Idioma: "pt", "en" ou automático pelo LANG do sistema
  readonly property string language: Model.language(config.language, Quickshell.env("LANG"))
  function tr(key) { return Model.t(root.language, key) }
  function trf(key, values) { return Model.format(root.language, key, values) }
  // Foco/pomodoro gravado em focus.json: continua com o painel fechado ou o shell reiniciado
  property var pomodoro: ({})
  readonly property var focusInfo: Model.focusPhase(pomodoro, nowMs)
  readonly property bool focusing: !!focusInfo && focusInfo.phase === "work" && !focusInfo.paused
  property string focusKey: ""
  // Tela do painel: home, sessions, limits, usage, agents, attention ou about
  property string screen: "home"
  onScreenChanged: contentViewport.contentY = 0
  property var sessionFiles: []
  property var sessions: []
  property var usageRecords: []
  property var daily: ({ date: "", completed_responses: 0, active_seconds: 0 })
  // Nome, versão, autor, licença e link da tela Sobre
  property var manifest: ({})
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
  readonly property string computedPetState: Model.petState(shownSessions, allLimits, nowMs, focusing)
  property string petState: "idle"
  readonly property color secondTint: Qt.hsla((Math.max(0, Commons.Color.accent.hslHue) + 0.12) % 1, Math.max(0.35, Commons.Color.accent.hslSaturation), Commons.Color.accent.hslLightness, 1)
  // Gráficos por agente: o seletor escolhe de quem são os limites mostrados
  property string selectedAgent: ""
  readonly property var limitRecords: Model.limitRecords(usageRecords, hiddenAgents)
  readonly property var currentRecord: Model.pickRecord(limitRecords, selectedAgent)
  readonly property var agentLimits: currentRecord ? currentRecord.limits : []
  readonly property var usageList: Model.usageRecords(usageRecords, hiddenAgents)
  readonly property var usageRecord: Model.pickRecord(usageList, selectedAgent)
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
      onStreamFinished: root.sessionFiles = Model.jsonFiles(text)
    }
  }
  // Uso e limites vêm do Main.qml do widget Agents do Omarchy: ele roda os coletores
  // e descobre os registros, então o Agents pode ficar desativado na barra
  Loader {
    id: usageLoader
    source: Quickshell.shellDir + "/plugins/agents/Main.qml"
  }
  readonly property var usage: usageLoader.item
  Connections {
    target: root.usage
    function onDataRevisionChanged() { root.collectUsage() }
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

  function collectSessions() {
    var result = []
    for (var i = 0; i < sessionInstantiator.count; i++) {
      var record = sessionInstantiator.objectAt(i)
      if (record && record.record) result.push(record.record)
    }
    sessions = result
  }
  function collectUsage() {
    var agents = root.usage ? root.usage.agents : []
    var result = []
    for (var i = 0; i < agents.length; i++)
      if (agents[i] && agents[i].record) result.push(agents[i].record)
    usageRecords = Model.keepLimits(usageRecords, result, Date.now(), 1800000)
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
    path: Qt.resolvedUrl("manifest.json").toString().replace("file://", "")
    printErrors: false
    onLoaded: {
      try { root.manifest = JSON.parse(String(text() || "{}")) || ({}) }
      catch (error) { root.manifest = ({}) }
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
  // Grava uma chave do config preservando as demais
  function setConfig(key, value) {
    var change = {}
    change[key] = value
    var next = Object.assign({}, config, change)
    config = next
    configFile.setText(JSON.stringify(next, null, 2) + "\n")
  }
  // Mostra ou oculta um agente nas telas
  function toggleAgent(id) {
    var hidden = hiddenAgents.slice()
    var index = hidden.indexOf(id)
    if (index < 0) hidden.push(id)
    else hidden.splice(index, 1)
    setConfig("hidden_agents", hidden)
  }

  FileView {
    id: focusFile
    path: root.stateHome + "/agent-pet/focus.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.pomodoro = JSON.parse(String(text() || "{}")) || ({}) }
      catch (error) { root.pomodoro = ({}) }
    }
  }
  function writeFocus(next) {
    pomodoro = next
    focusFile.setText(JSON.stringify(next) + "\n")
  }
  function startFocus(work, rest) {
    writeFocus({ work_min: work, break_min: rest, rounds: Number(config.focus_rounds) || 4, started_at: Date.now(), paused_at: null })
  }
  function pauseFocus() { writeFocus(Object.assign({}, pomodoro, { paused_at: Date.now() })) }
  // Continuar desloca o início pelo tempo pausado
  function resumeFocus() {
    writeFocus(Object.assign({}, pomodoro, { started_at: pomodoro.started_at + Date.now() - pomodoro.paused_at, paused_at: null }))
  }
  function stopFocus() { writeFocus({}) }

  Process { id: notifier }

  // Hooks das sessões: o painel instala com o botão da tela Agentes (setup --yes)
  readonly property string agentPetBin: Qt.resolvedUrl("bin/agent-pet").toString().replace("file://", "")
  // "", ok, missing, installing ou error
  property string hooksState: ""
  Process {
    id: hooksCheck
    command: ["python3", root.agentPetBin, "check"]
    onExited: function(exitCode) { root.hooksState = exitCode === 0 ? "ok" : exitCode === 3 ? "missing" : "error" }
  }
  Process {
    id: hooksSetup
    command: ["python3", root.agentPetBin, "setup", "--yes"]
    onExited: function(exitCode) {
      if (exitCode === 0) hooksCheck.running = true
      else root.hooksState = "error"
    }
  }
  function installHooks() {
    root.hooksState = "installing"
    hooksSetup.running = true
  }
  // Avisa ao entrar em cada etapa; a primeira leitura (início ou shell reiniciado) só registra
  onFocusInfoChanged: {
    var info = root.focusInfo
    var key = info ? root.pomodoro.started_at + ":" + info.phase + ":" + info.round : ""
    if (key === root.focusKey) return
    var first = root.focusKey === ""
    root.focusKey = key
    if (!info) return
    if (info.phase === "done") root.stopFocus()
    if (first || root.discreet || !Model.claimOnce(key)) return
    notifier.command = ["notify-send", "-a", "Retro Agent Pet", "Retro Agent Pet", Model.focusMessage(info, root.pomodoro, root.language)]
    notifier.running = true
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.nowMs = Date.now()
      if (!sessionScan.running) sessionScan.running = true
      root.readDaily()
    }
  }

  // Fica na barra com sessões ou com uso registrado, no lugar do widget Agents
  visible: shownSessions.length > 0 || usageList.length > 0 || !!focusInfo
  implicitWidth: button.implicitWidth + (focusCount.visible ? focusCount.implicitWidth + 4 : 0)
  implicitHeight: button.implicitHeight

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) close(); else open() }
  // Clique direito: abre o agente padrão, como no widget Agents
  function launchAgent() {
    if (root.bar) root.bar.run("omarchy-agent --pick")
    root.close()
  }
  onOpenedChanged: {
    if (!opened) return
    if (root.usage) root.usage.refreshLimits()
    if (!hooksSetup.running) hooksCheck.running = true
  }

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
      text: Model.resetLabel(gauge.limit.resetsAt, root.nowMs, root.language)
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

  // Botão em forma de chip; strong destaca o selecionado
  component ActionChip: Rectangle {
    id: chip
    required property string label
    property bool strong: false
    signal clicked()
    implicitWidth: chipText.implicitWidth + 16
    implicitHeight: 22
    radius: 11
    color: strong ? Qt.alpha(Commons.Color.accent, 0.2) : Qt.alpha(root.foreground, chipHover.hovered ? 0.12 : 0.06)
    Text { id: chipText; anchors.centerIn: parent; text: chip.label; color: chip.strong ? Commons.Color.accent : root.dim; font.pixelSize: 11; font.bold: chip.strong }
    TapHandler { onTapped: chip.clicked() }
    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
  }

  // Chave liga/desliga
  component Toggle: Rectangle {
    id: toggleSwitch
    property bool on: false
    signal toggled()
    width: 34
    height: 18
    radius: 9
    color: on ? Commons.Color.accent : Qt.alpha(root.foreground, 0.2)
    Rectangle { width: 14; height: 14; radius: 7; y: 2; x: toggleSwitch.on ? parent.width - width - 2 : 2; color: root.surface }
    TapHandler { onTapped: toggleSwitch.toggled() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
  }

  // Seletor de agente dos gráficos; some quando só há um agente na lista
  component AgentTabs: RowLayout {
    id: tabs
    property var records: root.limitRecords
    readonly property var picked: Model.pickRecord(records, root.selectedAgent)
    Layout.alignment: Qt.AlignHCenter
    visible: records.length > 1
    spacing: 6
    Repeater {
      model: tabs.records.length
      delegate: ActionChip {
        required property int index
        readonly property var record: tabs.records[index]
        label: record.name || record.id
        strong: !!tabs.picked && tabs.picked.id === record.id
        onClicked: root.selectedAgent = record.id
      }
    }
  }

  // Linha da tela Uso: rótulo, barra proporcional e valor
  component UsageRow: RowLayout {
    id: usageRow
    property string label: ""
    property real share: 0
    property string value: ""
    property bool strong: false
    property real labelWidth: 40
    property color tint: Commons.Color.accent
    Layout.fillWidth: true
    spacing: 6
    Text { text: usageRow.label; color: usageRow.strong ? root.foreground : root.dim; font.pixelSize: 12; font.bold: usageRow.strong; elide: Text.ElideRight; Layout.preferredWidth: usageRow.labelWidth }
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 5
      radius: 3
      color: Qt.alpha(root.foreground, 0.12)
      Rectangle { width: parent.width * usageRow.share; height: parent.height; radius: 3; color: usageRow.tint }
    }
    Text { text: usageRow.value; color: usageRow.strong ? root.foreground : root.dim; font.pixelSize: 12; font.bold: usageRow.strong; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
  }

  // Tokens no formato do Omarchy (1.5M); sem o Main.qml, o número cru
  function tokens(count) { return root.usage ? root.usage.formatTokenCount(Number(count || 0)) : String(Number(count || 0)) }

  // Linha de crédito da tela Sobre; com url, abre no navegador ou no e-mail
  component CreditRow: RowLayout {
    id: credit
    required property string label
    required property string value
    property string url: ""
    Layout.fillWidth: true
    spacing: 8
    Text { text: credit.label; color: root.dim; font.pixelSize: 12; Layout.preferredWidth: 70 }
    Text {
      text: credit.value
      color: credit.url ? Commons.Color.accent : root.foreground
      font.pixelSize: 12
      font.underline: credit.url !== "" && link.hovered
      elide: Text.ElideRight
      Layout.fillWidth: true
      HoverHandler { id: link; enabled: credit.url !== ""; cursorShape: Qt.PointingHandCursor }
      TapHandler { enabled: credit.url !== ""; onTapped: Qt.openUrlExternally(credit.url) }
    }
  }

  // Item do menu inferior
  component MenuItem: Item {
    id: menuItem
    required property string target
    required property string label
    property bool badge: false
    readonly property bool current: root.screen === target
    // Largura pelo texto: partes iguais encostariam os rótulos longos (Sobre é só o ícone ⓘ)
    Layout.fillWidth: true
    implicitWidth: menuLabel.implicitWidth + 8
    implicitHeight: 28
    Rectangle { anchors.fill: parent; radius: 6; color: Qt.alpha(Commons.Color.accent, menuItem.current ? 0.18 : (hover.hovered ? 0.08 : 0)) }
    Text { id: menuLabel; anchors.centerIn: parent; text: menuItem.label; color: menuItem.current ? Commons.Color.accent : root.dim; font.pixelSize: 11; font.bold: menuItem.current }
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
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: implicitWidth
    bar: root.bar
    iconComponent: Component {
      Pet {
        anchors.centerIn: parent
        width: 16
        height: 16
        character: root.character
        petState: root.petState
        inkColor: root.surface
        bodyColor: root.foreground
        faceColor: Commons.Color.accent
        accentColor: root.petState === "attention" ? root.urgent : Commons.Color.accent
        warningColor: root.urgent
      }
    }
    active: root.attention || root.alarm
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launchAgent()
      else root.toggle()
    }
    SequentialAnimation on opacity {
      running: root.attention && !root.discreet
      loops: Animation.Infinite
      NumberAnimation { to: 0.45; duration: 450 }
      NumberAnimation { to: 1; duration: 450 }
      onStopped: button.opacity = 1
    }
  }

  // Minutos restantes do foco ao lado do ícone (barra horizontal)
  Text {
    id: focusCount
    visible: !!root.focusInfo && !(root.bar && root.bar.vertical)
    anchors.left: button.right
    anchors.leftMargin: 2
    anchors.verticalCenter: parent.verticalCenter
    text: root.focusInfo ? (root.focusInfo.paused ? "❚❚" : Math.ceil(root.focusInfo.remainingMs / 60000) + "m") : ""
    color: root.focusInfo && root.focusInfo.phase === "break" ? root.dim : root.foreground
    font.family: root.bar ? root.bar.fontFamily : ""
    font.pixelSize: 12
    TapHandler { onTapped: root.toggle() }
  }

  PopupCard {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    triggerMode: "hover"
    contentWidth: panel.fittedContentWidth(320)
    contentHeight: panel.cappedContentHeight(560)

    Flickable {
      id: contentViewport
      objectName: "screenViewport"
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: navigation.top
      anchors.bottomMargin: 12
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      Controls.ScrollBar.vertical: Controls.ScrollBar {
        id: scrollBar
        objectName: "contentScrollBar"
        policy: Controls.ScrollBar.AsNeeded
        visible: contentViewport.contentHeight > contentViewport.height
        width: 6
        minimumSize: 0.08
        padding: 0
        contentItem: Rectangle {
          implicitWidth: 6
          radius: 3
          color: Qt.alpha(root.foreground, scrollBar.pressed || scrollBar.hovered ? 0.8 : 0.4)
        }
        background: Rectangle { radius: 3; color: Qt.alpha(root.foreground, 0.08) }
      }
      ColumnLayout {
        id: column
        width: parent.width - (scrollBar.visible ? scrollBar.width + 8 : 0)
        y: ["home", "limits", "attention", "about"].indexOf(root.screen) >= 0 ? Math.max(0, (contentViewport.height - implicitHeight) / 2) : 0
        spacing: 12

        // Início: agente grande e medidores
        ColumnLayout {
          visible: root.screen === "home"
          Layout.fillWidth: true
          spacing: 12
          Pet {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.focusInfo ? 160 : 192
            Layout.preferredHeight: Layout.preferredWidth
            character: root.character
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
                size: Math.min(138, (contentViewport.width - 12) / 2)
                limit: modelData
                tint: index % 2 ? root.secondTint : Commons.Color.accent
              }
            }
          }
          Text { text: root.tr("noLimitData"); visible: root.agentLimits.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
          // Foco/pomodoro: atalhos para iniciar; em andamento, etapa, tempo e controles
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: focusColumn.implicitHeight + 16
            radius: 6
            color: Qt.alpha(root.foreground, 0.05)
            ColumnLayout {
              id: focusColumn
              anchors.fill: parent
              anchors.margins: 8
              spacing: 6
              RowLayout {
                visible: !root.focusInfo
                Layout.fillWidth: true
                spacing: 6
                Text { text: root.tr("focus"); color: root.foreground; font.pixelSize: 13; font.bold: true }
                Text { text: "× " + (Number(root.config.focus_rounds) || 4); color: root.dim; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                ActionChip { label: "25/5"; onClicked: root.startFocus(25, 5) }
                ActionChip { label: "50/10"; onClicked: root.startFocus(50, 10) }
              }
              RowLayout {
                visible: !!root.focusInfo
                Layout.fillWidth: true
                Text {
                  text: root.focusInfo ? root.trf(root.focusInfo.phase === "break" ? "breakRound" : "focusRound", [root.focusInfo.round, root.focusInfo.rounds]) + (root.focusInfo.paused ? root.tr("paused") : "") : ""
                  color: root.focusInfo && root.focusInfo.phase === "break" ? root.dim : root.foreground
                  font.pixelSize: 13
                  font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text { text: root.focusInfo ? Model.focusClock(root.focusInfo.remainingMs) : ""; color: root.foreground; font.pixelSize: 18; font.bold: true }
              }
              Rectangle {
                visible: !!root.focusInfo
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.alpha(root.foreground, 0.12)
                Rectangle { width: parent.width * (root.focusInfo ? root.focusInfo.share : 0); height: parent.height; radius: 3; color: root.focusInfo && root.focusInfo.phase === "break" ? root.secondTint : Commons.Color.accent }
              }
              RowLayout {
                visible: !!root.focusInfo
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                ActionChip {
                  label: root.focusInfo && root.focusInfo.paused ? root.tr("resume") : root.tr("pause")
                  onClicked: root.focusInfo.paused ? root.resumeFocus() : root.pauseFocus()
                }
                ActionChip { label: root.tr("stop"); onClicked: root.stopFocus() }
              }
            }
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.trf("todaySummary", [Number(root.daily.completed_responses || 0), Model.formatDuration(root.daily.active_seconds || 0)])
            color: root.dim
            font.pixelSize: 12
          }
        }

        // Sessões: limites resumidos e um cartão por sessão
        ColumnLayout {
          visible: root.screen === "sessions"
          Layout.fillWidth: true
          spacing: 8
          ScreenHeader { title: root.tr("sessions") }
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
                Text { text: Model.activityText(card.modelData, root.language); color: card.modelData.status === "attention" ? root.urgent : root.dim; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
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
          Text { text: root.tr("noSessions"); visible: root.shownSessions.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.trf("sessionsSummary", [Model.runningCount(root.shownSessions), root.shownSessions.length])
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
          ScreenHeader { title: root.tr("limits") }
          AgentTabs {}
          Gauge {
            visible: !!parent.main
            Layout.alignment: Qt.AlignHCenter
            size: Math.min(240, contentViewport.width)
            limit: parent.main || ({})
          }
          Text {
            visible: parent.depletion !== null
            Layout.alignment: Qt.AlignHCenter
            text: root.trf("depletion", [Qt.formatTime(new Date(parent.depletion || 0), "hh:mm")])
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
                Text { text: modelData.label || root.tr("limit"); color: root.foreground; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text {
                  text: Math.round(Model.limitPercent(modelData, root.nowMs)) + "%" + (Model.resetLabel(modelData.resetsAt, root.nowMs, root.language) ? " · " + Model.resetLabel(modelData.resetsAt, root.nowMs, root.language) : "")
                  color: root.dim
                  font.pixelSize: 12
                }
              }
              LimitBar { Layout.fillWidth: true; limit: modelData; tint: root.secondTint; labels: false }
            }
          }
          Text { text: root.tr("noLimitData"); visible: root.agentLimits.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
        }

        // Uso: plano, hoje, tokens por dia e por modelo, como no widget Agents
        ColumnLayout {
          id: usageScreen
          visible: root.screen === "usage"
          Layout.fillWidth: true
          spacing: 8
          readonly property var record: root.usageRecord
          readonly property var days: record ? Model.dayRows(record.recentDays, Qt.formatDate(new Date(root.nowMs), "yyyy-MM-dd"), root.language) : []
          readonly property var models: record ? Model.modelRows(record.modelUsage) : []
          ScreenHeader { title: root.tr("usage") }
          AgentTabs { records: root.usageList }
          Text {
            visible: !!usageScreen.record
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: usageScreen.record ? (usageScreen.record.name || usageScreen.record.id)
              + " · " + (usageScreen.record.usageStatusText || usageScreen.record.tierLabel || root.tr("plan")) : ""
            color: root.foreground
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            visible: !!usageScreen.record
            Layout.alignment: Qt.AlignHCenter
            text: usageScreen.record ? root.trf("usageToday", [Number(usageScreen.record.todayPrompts || 0),
              root.trf(Number(usageScreen.record.todaySessions) === 1 ? "oneSession" : "manySessions", [Number(usageScreen.record.todaySessions || 0)]), root.tokens(usageScreen.record.todayTotalTokens)]) : ""
            color: root.dim
            font.pixelSize: 12
          }
          Text { visible: usageScreen.days.length > 0; text: root.tr("tokensPerDay"); color: root.dim; font.pixelSize: 11; font.bold: true }
          Repeater {
            model: usageScreen.days
            delegate: UsageRow {
              required property var modelData
              label: modelData.label
              share: modelData.share
              value: root.tokens(modelData.tokens)
              strong: modelData.today
            }
          }
          Text { visible: usageScreen.models.length > 0; text: root.tr("tokensPerModel"); color: root.dim; font.pixelSize: 11; font.bold: true }
          Repeater {
            model: usageScreen.models
            delegate: UsageRow {
              required property var modelData
              label: root.usage ? root.usage.friendlyModelName(modelData.id) : modelData.id
              labelWidth: 110
              share: modelData.share
              value: root.tokens(modelData.total)
              tint: root.secondTint
            }
          }
          Text { text: root.tr("noUsage"); visible: !usageScreen.record; color: root.dim; Layout.alignment: Qt.AlignHCenter }
        }

        // Precisa de você: sessão mais urgente e o que ela pediu
        ColumnLayout {
          visible: root.screen === "attention"
          Layout.fillWidth: true
          spacing: 8
          readonly property var waiting: root.orderedSessions.filter(function(session) { return session.status === "attention" })
          readonly property var first: waiting.length ? waiting[0] : null
          readonly property var elapsed: first ? Model.sessionElapsed(first, root.nowMs) : null
          ScreenHeader { title: root.tr("needsYou"); titleColor: root.urgent }
          Text { text: parent.first ? Model.sessionName(parent.first) : ""; color: root.foreground; font.pixelSize: 26; font.bold: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
          Text { text: parent.first ? Model.activityText(parent.first, root.language) : ""; color: root.urgent; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter }
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
          Text { text: parent.elapsed === null ? "" : root.trf("waitingFor", [Model.shortDuration(parent.elapsed)]); color: root.dim; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
          Text { text: root.trf("answerIn", [parent.first ? Model.agentLabel(parent.first) : root.tr("agent")]); color: root.dim; font.pixelSize: 11; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
          Text {
            text: [parent.waiting.length > 1 ? root.trf("moreWaiting", [parent.waiting.length - 1]) : "", Model.runningCount(root.shownSessions) ? root.trf("moreRunning", [Model.runningCount(root.shownSessions)]) : ""].filter(function(item) { return item }).join(" · ")
            color: root.dim
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
          }
          Text { text: root.tr("noRequest"); visible: !parent.first; color: root.dim; Layout.alignment: Qt.AlignHCenter }
        }

        // Agentes: todos os registros de uso do Omarchy, com opção de mostrar/ocultar
        ColumnLayout {
          visible: root.screen === "agents"
          Layout.fillWidth: true
          spacing: 8
          ScreenHeader { title: root.tr("agents") }
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
                    : (agentCard.modelData.usageStatusText || root.tr("noLimits")))
                    + (sessionCount ? " · " + root.trf(sessionCount === 1 ? "oneSession" : "manySessions", [sessionCount]) : "")
                  color: root.dim
                  font.pixelSize: 12
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
              Toggle {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                on: agentCard.shown
                onToggled: root.toggleAgent(agentCard.modelData.id)
              }
            }
          }
          Text { text: root.tr("noAgents"); visible: root.usageRecords.length === 0; color: root.dim; Layout.alignment: Qt.AlignHCenter }
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0
              Text { text: root.tr("discreet"); color: root.foreground; font.pixelSize: 14; font.bold: true }
              Text { text: root.tr("discreetHint"); color: root.dim; font.pixelSize: 11 }
            }
            Toggle { on: root.discreet; onToggled: root.setConfig("discreet", !root.discreet) }
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 6
            Text { text: root.tr("character"); color: root.foreground; font.pixelSize: 14; font.bold: true }
            RowLayout {
              Layout.fillWidth: true
              spacing: 4
              Repeater {
                model: ["computer", "cat", "robot", "dog"]
                delegate: Rectangle {
                  id: characterCard
                  required property string modelData
                  Layout.fillWidth: true
                  implicitHeight: 70
                  radius: 6
                  color: Qt.alpha(root.foreground, root.character === modelData ? 0.16 : 0.05)
                  border.width: root.character === modelData ? 1 : 0
                  border.color: Commons.Color.accent
                  Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Pet {
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: 32; height: 32
                      character: characterCard.modelData
                      petState: root.petState
                      inkColor: root.surface
                      outlineColor: root.dim
                      bodyColor: root.foreground
                      faceColor: Commons.Color.accent
                      accentColor: Commons.Color.accent
                      warningColor: root.urgent
                    }
                    Text { text: root.tr(characterCard.modelData); color: root.foreground; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setConfig("character", characterCard.modelData) }
                }
              }
            }
          }
          ColumnLayout {
            id: languageRow
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 4
            readonly property string choice: root.config.language === "pt" || root.config.language === "en" ? root.config.language : "auto"
            Text { text: root.tr("language"); color: root.foreground; font.pixelSize: 14; font.bold: true }
            RowLayout {
              spacing: 4
              ActionChip { label: root.tr("auto"); strong: languageRow.choice === "auto"; onClicked: root.setConfig("language", "auto") }
              ActionChip { label: "Português"; strong: languageRow.choice === "pt"; onClicked: root.setConfig("language", "pt") }
              ActionChip { label: "English"; strong: languageRow.choice === "en"; onClicked: root.setConfig("language", "en") }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0
              Text { text: root.tr("sessions"); color: root.foreground; font.pixelSize: 14; font.bold: true }
              Text {
                text: Model.hooksText(root.hooksState, root.language)
                color: root.hooksState === "error" ? root.urgent : root.dim
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }
            }
            ActionChip {
              visible: root.hooksState === "missing" || root.hooksState === "error"
              label: root.tr("enable")
              strong: true
              onClicked: root.installHooks()
            }
          }
          Text { text: root.tr("hiddenHint"); color: root.dim; font.pixelSize: 11; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
        }

        // Sobre: créditos do autor e do projeto
        ColumnLayout {
          id: aboutScreen
          visible: root.screen === "about"
          Layout.fillWidth: true
          spacing: 8
          readonly property string homepage: root.manifest.homepage || ""
          ScreenHeader { title: root.tr("about") }
          Pet {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            character: root.character
            petState: "idle"
            inkColor: root.surface
            outlineColor: root.dim
            bodyColor: root.foreground
            faceColor: Commons.Color.accent
            accentColor: Commons.Color.accent
            warningColor: root.urgent
          }
          Text { text: root.manifest.name || "Retro Agent Pet"; color: root.foreground; font.pixelSize: 16; font.bold: true; Layout.alignment: Qt.AlignHCenter }
          Text {
            text: [root.trf("version", [root.manifest.version || "?"]), root.manifest.license ? root.trf("license", [root.manifest.license]) : ""].filter(function(item) { return item }).join(" · ")
            color: root.dim
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: root.tr("aboutText")
            color: root.dim
            font.pixelSize: 11
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
          Rectangle { Layout.fillWidth: true; height: 1; color: root.dim; opacity: 0.2 }
          CreditRow { label: root.tr("createdBy"); value: root.manifest.author || "Marlon Azevedo" }
          CreditRow { label: root.tr("email"); value: "foxwnobr@gmail.com"; url: "mailto:foxwnobr@gmail.com" }
          CreditRow { visible: aboutScreen.homepage !== ""; label: "GitHub"; value: aboutScreen.homepage.split("/")[3] || ""; url: aboutScreen.homepage.split("/").slice(0, 4).join("/") }
          CreditRow { visible: aboutScreen.homepage !== ""; label: root.tr("project"); value: aboutScreen.homepage.split("/")[4] || ""; url: aboutScreen.homepage }
          CreditRow { visible: aboutScreen.homepage !== ""; label: root.tr("issues"); value: root.tr("openIssue"); url: aboutScreen.homepage + "/issues" }
          Text {
            text: root.tr("credits")
            color: root.dim
            font.pixelSize: 11
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
        }
      }
    }

    // Menu inferior permanece acessível durante a rolagem
    ColumnLayout {
      id: navigation
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      spacing: 12
      Rectangle { Layout.fillWidth: true; height: 1; color: root.dim; opacity: 0.35 }
      RowLayout {
        Layout.fillWidth: true
        spacing: 2
        MenuItem { target: "home"; label: root.tr("home") }
        MenuItem { target: "sessions"; label: root.tr("sessions"); badge: root.attention && root.screen !== "attention" }
        MenuItem { target: "limits"; label: root.tr("limits") }
        MenuItem { target: "usage"; label: root.tr("usage") }
        MenuItem { target: "agents"; label: root.tr("agents") }
        MenuItem { target: "attention"; label: root.tr("request"); visible: root.attention }
        MenuItem { target: "about"; label: "ⓘ" }
      }
    }
  }
}

.pragma library

// Textos do painel; chave sem tradução cai no português
var TEXTS = {
  pt: {
    character: "Personagem", computer: "Computador", cat: "Gato", robot: "Robô", dog: "Cachorro",
    noLimitData: "Sem dados de limite", focus: "Foco", focusRound: "Foco {0}/{1}", breakRound: "Pausa {0}/{1}", paused: " · pausado",
    resume: "Continuar", pause: "Pausar", stop: "Parar", todaySummary: "Hoje · {0} respostas · {1}",
    sessions: "Sessões", noSessions: "Nenhuma sessão ativa", sessionsSummary: "● {0} rodando · {1} no total",
    limits: "Limites", depletion: "no ritmo atual, acaba às {0}", limit: "Limite", usage: "Uso", plan: "Assinatura",
    usageToday: "Hoje · {0} prompts · {1} · {2} tokens", oneSession: "{0} sessão", manySessions: "{0} sessões",
    tokensPerDay: "Tokens por dia", tokensPerModel: "Tokens por modelo", noUsage: "Sem dados de uso",
    needsYou: "● Precisa de você", waitingFor: "esperando há {0}", answerIn: "Responda no {0}; este painel continua aberto.",
    agent: "agente", moreWaiting: "+{0} esperando", moreRunning: "+{0} rodando", noRequest: "Nenhum pedido pendente",
    agents: "Agentes", noLimits: "Sem limites", noAgents: "Nenhum agente encontrado", discreet: "Modo discreto",
    discreetHint: "Sem notificações e sem piscar o ícone", enable: "Ativar", language: "Idioma", auto: "Automático",
    hiddenHint: "Agentes ocultos saem das telas de início, sessões e limites.", about: "Sobre", version: "versão {0}",
    license: "licença {0}", aboutText: "Acompanha as sessões do Claude Code e do Codex, os pedidos de permissão, os limites e o uso de cada agente.",
    createdBy: "Criado por", email: "E-mail", project: "Projeto", issues: "Problemas", openIssue: "abrir uma issue",
    credits: "Uso e limites: coletores do widget Agents do Omarchy. Inspirado no Mupli.", home: "Início", request: "Pedido",
    asked: "Pediu permissão", waitingAnswer: "Esperando resposta", idle: "Ocioso", thinking: "Pensando",
    focusDone: "Foco concluído · {0} rodadas", focusBreak: "Pausa de {0} min · rodada {1}/{2} concluída", focusWork: "Foco: rodada {0}/{1} · {2} min",
    hooksOk: "Acompanhando Claude Code e Codex", hooksMissing: "Desativado: ative para ver as sessões dos agentes", hooksInstalling: "Ativando…",
    hooksError: "Falhou; rode bin/agent-pet setup na pasta do plugin", hooksChecking: "Conferindo…", inTime: "em {0}", today: "Hoje"
  },
  en: {
    character: "Character", computer: "Computer", cat: "Cat", robot: "Robot", dog: "Dog",
    noLimitData: "No limit data", focus: "Focus", focusRound: "Focus {0}/{1}", breakRound: "Break {0}/{1}", paused: " · paused",
    resume: "Resume", pause: "Pause", stop: "Stop", todaySummary: "Today · {0} replies · {1}",
    sessions: "Sessions", noSessions: "No active sessions", sessionsSummary: "● {0} running · {1} total",
    limits: "Limits", depletion: "at this pace, runs out at {0}", limit: "Limit", usage: "Usage", plan: "Subscription",
    usageToday: "Today · {0} prompts · {1} · {2} tokens", oneSession: "{0} session", manySessions: "{0} sessions",
    tokensPerDay: "Tokens per day", tokensPerModel: "Tokens per model", noUsage: "No usage data",
    needsYou: "● Needs you", waitingFor: "waiting {0}", answerIn: "Answer in {0}; this panel stays open.",
    agent: "the agent", moreWaiting: "+{0} waiting", moreRunning: "+{0} running", noRequest: "No pending request",
    agents: "Agents", noLimits: "No limits", noAgents: "No agents found", discreet: "Discreet mode",
    discreetHint: "No notifications and no blinking icon", enable: "Turn on", language: "Language", auto: "Automatic",
    hiddenHint: "Hidden agents leave the home, sessions and limits screens.", about: "About", version: "version {0}",
    license: "license {0}", aboutText: "Follows your Claude Code and Codex sessions, permission requests, limits and usage per agent.",
    createdBy: "Created by", email: "E-mail", project: "Project", issues: "Issues", openIssue: "open an issue",
    credits: "Usage and limits: collectors of Omarchy's Agents widget. Inspired by Mupli.", home: "Home", request: "Request",
    asked: "Asked for permission", waitingAnswer: "Waiting for an answer", idle: "Idle", thinking: "Thinking",
    focusDone: "Focus done · {0} rounds", focusBreak: "{0} min break · round {1}/{2} done", focusWork: "Focus: round {0}/{1} · {2} min",
    hooksOk: "Following Claude Code and Codex", hooksMissing: "Off: turn it on to see your agents' sessions", hooksInstalling: "Turning on…",
    hooksError: "Failed; run bin/agent-pet setup in the plugin folder", hooksChecking: "Checking…", inTime: "in {0}", today: "Today"
  }
}
var DAYS = { pt: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"], en: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] }
var VERBS = {
  pt: { Edit: "Editando", apply_patch: "Editando", MultiEdit: "Editando", Write: "Escrevendo", Read: "Lendo", NotebookEdit: "Editando",
    Grep: "Buscando", Glob: "Buscando", WebSearch: "Pesquisando", Task: "Subagente ·", Agent: "Subagente ·" },
  en: { Edit: "Editing", apply_patch: "Editing", MultiEdit: "Editing", Write: "Writing", Read: "Reading", NotebookEdit: "Editing",
    Grep: "Searching", Glob: "Searching", WebSearch: "Searching the web", Task: "Subagent ·", Agent: "Subagent ·" }
}

// "pt" ou "en": escolha do config, ou o LANG do sistema no automático
function language(setting, envLang) {
  if (setting === "pt" || setting === "en") return setting
  return /^pt/i.test(String(envLang || "")) ? "pt" : "en"
}

function t(lang, key) {
  var table = TEXTS[lang] || TEXTS.pt
  return table[key] !== undefined ? table[key] : (TEXTS.pt[key] !== undefined ? TEXTS.pt[key] : key)
}

// Preenche {0}, {1}… do texto
function format(lang, key, values) {
  return t(lang, key).replace(/\{(\d+)\}/g, function(match, index) { return String((values || [])[Number(index)]) })
}

function sortSessions(sessions) {
  return (sessions || []).slice().sort(function(a, b) {
    var attention = (b.status === "attention" ? 1 : 0) - (a.status === "attention" ? 1 : 0)
    if (attention) return attention
    return Number(b.updated_at || 0) - Number(a.updated_at || 0)
  })
}

function hasAttention(sessions) {
  return (sessions || []).some(function(session) { return session.status === "attention" })
}

function petState(sessions, limits, now, focusing) {
  if (hasAttention(sessions)) return "attention"
  if (alarmingLimit(limits, 90, now)) return "limit"
  if (focusing) return "focus"
  if ((sessions || []).some(function(session) { return session.status === "working" })) return "working"
  return "idle"
}

function alarmingLimit(limits, threshold, now) {
  var cutoff = threshold === undefined ? 90 : Number(threshold)
  return (limits || []).some(function(limit) { return limitPercent(limit, now) >= cutoff })
}

function isExpired(value, now) {
  if (!value) return false
  var time = new Date(String(value)).getTime()
  return isFinite(time) && time <= (now === undefined ? Date.now() : Number(now))
}

function visible(sessions) {
  return (sessions || []).length > 0
}

function formatDuration(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  return hours > 0 ? hours + "h " + minutes + "min" : minutes + " min"
}

function sessionElapsed(session, now) {
  if (!session || (session.status !== "working" && session.status !== "attention")) return null
  var since = Number(session.activity_started_at || session.turn_started_at || session.updated_at)
  if (!isFinite(since) || since <= 0) return null
  return Math.max(0, Math.floor(((now === undefined ? Date.now() : Number(now)) - since) / 1000))
}

// Omarchy grava percent como fração (0..1); devolve 0..100
function limitPercent(limit, now) {
  return isExpired(limit && limit.resetsAt, now) ? 0 : Math.max(0, Math.min(100, (Number(limit && limit.percent) || 0) * 100))
}

// Horas da janela: "Session (5-hour)", "Weekly (7-day)", "720h window"
function windowHours(label) {
  var text = String(label || "")
  var match = text.match(/(\d+)-(hour|day)/i)
  if (match) return Number(match[1]) * (match[2].toLowerCase() === "hour" ? 1 : 24)
  match = text.match(/(\d+)h\b/i)
  return match ? Number(match[1]) : 0
}

// "5h", "7d", "30d"; sem janela reconhecida mantém o rótulo
function windowShort(label) {
  var hours = windowHours(label)
  if (!hours) return String(label || "")
  return hours >= 24 && hours % 24 === 0 ? hours / 24 + "d" : hours + "h"
}

// Renovação: "em 2h10" até 24 h; depois "sex 19:32"
function resetLabel(resetsAt, now, lang) {
  if (!resetsAt) return ""
  var time = new Date(String(resetsAt)).getTime()
  var current = now === undefined ? Date.now() : Number(now)
  if (!isFinite(time) || time <= current) return ""
  var minutes = Math.ceil((time - current) / 60000)
  if (minutes < 60) return format(lang, "inTime", [minutes + "min"])
  if (minutes < 24 * 60) {
    var rest = minutes % 60
    return format(lang, "inTime", [Math.floor(minutes / 60) + "h" + (rest < 10 ? "0" : "") + rest])
  }
  var date = new Date(time)
  var pad = function(value) { return (value < 10 ? "0" : "") + value }
  return (DAYS[lang] || DAYS.pt)[date.getDay()] + " " + pad(date.getHours()) + ":" + pad(date.getMinutes())
}

function sessionName(session) {
  if (session.session_title) return session.session_title
  var parts = String(session.cwd || "").split("/").filter(function(part) { return part })
  return parts.length ? parts[parts.length - 1] : session.session_id
}

function activityText(session, lang) {
  if (session.status === "attention") return t(lang, session.attention_reason === "permission" ? "asked" : "waitingAnswer")
  if (session.status !== "working") return t(lang, "idle")
  if (!session.current_tool) return t(lang, "thinking")
  if (!session.tool_detail) return session.current_tool
  return ((VERBS[lang] || VERBS.pt)[session.current_tool] || session.current_tool + " ·") + " " + session.tool_detail
}

function permissionText(session) {
  return (session.current_tool || "Claude Code") + (session.tool_detail ? ": " + session.tool_detail : "")
}

// "<1m", "3m", "1h05"
function shortDuration(seconds) {
  var minutes = Math.floor(Math.max(0, Number(seconds) || 0) / 60)
  if (minutes < 1) return "<1m"
  if (minutes < 60) return minutes + "m"
  var rest = minutes % 60
  return Math.floor(minutes / 60) + "h" + (rest < 10 ? "0" : "") + rest
}

function runningCount(sessions) {
  return (sessions || []).filter(function(session) { return session.status === "working" }).length
}

// No ritmo atual, quando o limite chega a 100%; null se durar até a renovação
function depletionTime(limit, now) {
  var hours = windowHours(limit && limit.label)
  var reset = new Date(String(limit && limit.resetsAt)).getTime()
  var percent = limitPercent(limit, now)
  if (!hours || !isFinite(reset) || percent <= 0) return null
  var current = now === undefined ? Date.now() : Number(now)
  var start = reset - hours * 3600000
  if (current <= start) return null
  var end = start + Math.round((current - start) * 100 / percent)
  return end < reset ? end : null
}

var AGENT_LABELS = { claude: "Claude Code", codex: "Codex" }

function agentLabel(session) {
  var agent = session && session.agent || "claude"
  return AGENT_LABELS[agent] || agent
}

// Sessão sem agent é do Claude Code (arquivos anteriores ao campo)
function visibleSessions(sessions, hidden) {
  return (sessions || []).filter(function(session) { return (hidden || []).indexOf(session.agent || "claude") < 0 })
}

// Agentes visíveis que têm limites, para o seletor dos gráficos
function limitRecords(records, hidden) {
  return visibleRecords(records, hidden).filter(function(record) { return record.limits && record.limits.length > 0 })
}

function pickRecord(records, id) {
  var list = records || []
  for (var i = 0; i < list.length; i++)
    if (list[i].id === id) return list[i]
  return list.length ? list[0] : null
}

// Saída do find em ordem fixa: a ordem de gravação muda e recriaria os leitores
function jsonFiles(text) {
  return String(text || "").split("\n").filter(function(path) { return path.endsWith(".json") }).sort()
}

// Falha passageira do coletor grava limites vazios; mantém os últimos bons até maxAgeMs
function keepLimits(previous, current, now, maxAgeMs) {
  return (current || []).map(function(record) {
    if (record.limits && record.limits.length) return record
    var old = (previous || []).filter(function(item) { return item.id === record.id })[0]
    if (!old || !old.limits || !old.limits.length) return record
    var limitsAt = old.limitsAt || old.updatedAt
    if (now - Date.parse(limitsAt) > maxAgeMs) return record
    return Object.assign({}, record, { limits: old.limits, tierLabel: record.tierLabel || old.tierLabel, limitsAt: limitsAt })
  })
}

function visibleRecords(records, hidden) {
  return (records || []).filter(function(record) { return (hidden || []).indexOf(record.id) < 0 })
}

// Tela Uso: agentes visíveis que já registraram algum uso
function usageRecords(records, hidden) {
  return visibleRecords(records, hidden).filter(function(record) {
    return record.todayPrompts > 0 || record.todaySessions > 0 || record.totalPrompts > 0
      || record.totalSessions > 0 || record.activeDays > 0 || (record.limits && record.limits.length > 0)
  })
}

// Tokens dos últimos dias; share é a fração do dia mais movimentado
function dayRows(recentDays, today, lang) {
  var list = recentDays || []
  var peak = Math.max.apply(null, [0].concat(list.map(function(day) { return Number(day.messageCount) || 0 })))
  return list.map(function(day) {
    var tokens = Number(day.messageCount) || 0
    var date = new Date(day.date + "T00:00:00")
    return { date: day.date, label: day.date === today ? t(lang, "today") : (DAYS[lang] || DAYS.pt)[date.getDay()], tokens: tokens, share: peak ? tokens / peak : 0, today: day.date === today }
  })
}

// Os 4 modelos com mais tokens (entrada, saída e cache)
function modelRows(modelUsage) {
  var rows = Object.keys(modelUsage || {}).map(function(id) {
    var bucket = modelUsage[id] || {}
    var total = (Number(bucket.inputTokens) || 0) + (Number(bucket.outputTokens) || 0)
      + (Number(bucket.cacheReadInputTokens) || 0) + (Number(bucket.cacheCreationInputTokens) || 0)
    return { id: id, total: total }
  }).sort(function(a, b) { return b.total - a.total }).slice(0, 4)
  var peak = rows.length ? rows[0].total : 0
  return rows.map(function(row) { return { id: row.id, total: row.total, share: peak ? row.total / peak : 0 } })
}

// Foco/pomodoro: rodadas de trabalho com pausa entre elas (sem pausa após a última)
function focusPhase(focus, now) {
  if (!focus || typeof focus.started_at !== "number") return null
  var work = Number(focus.work_min) * 60000
  var rest = Number(focus.break_min) * 60000
  var rounds = Number(focus.rounds) || 1
  var cycle = work + rest
  var elapsed = Math.max(0, (typeof focus.paused_at === "number" ? focus.paused_at : now) - focus.started_at)
  var base = { rounds: rounds, paused: typeof focus.paused_at === "number" }
  if (elapsed >= rounds * work + (rounds - 1) * rest)
    return Object.assign({ phase: "done", round: rounds, remainingMs: 0, share: 1 }, base)
  var round = Math.floor(elapsed / cycle)
  var within = elapsed - round * cycle
  var working = within < work
  return Object.assign({
    phase: working ? "work" : "break",
    round: round + 1,
    remainingMs: working ? work - within : cycle - within,
    share: working ? within / work : (within - work) / rest
  }, base)
}

// "15:04"; segundos arredondados para cima, para não mostrar 0:00 antes do fim
function focusClock(ms) {
  var seconds = Math.ceil(Math.max(0, ms) / 1000)
  var rest = seconds % 60
  return Math.floor(seconds / 60) + ":" + (rest < 10 ? "0" : "") + rest
}

// Texto do aviso ao entrar em cada etapa do foco
function focusMessage(info, focus, lang) {
  if (info.phase === "done") return format(lang, "focusDone", [info.rounds])
  if (info.phase === "break") return format(lang, "focusBreak", [focus.break_min, info.round, info.rounds])
  return format(lang, "focusWork", [info.round, info.rounds, focus.work_min])
}

// Estado dos hooks na tela Agentes ("", ok, missing, installing, error)
var HOOKS_KEYS = { ok: "hooksOk", missing: "hooksMissing", installing: "hooksInstalling", error: "hooksError" }
function hooksText(state, lang) {
  return t(lang, HOOKS_KEYS[state] || "hooksChecking")
}

// Biblioteca compartilhada: só a primeira cópia do painel (um por monitor) avisa
var CLAIMED = {}
function claimOnce(key) {
  if (CLAIMED[key]) return false
  CLAIMED[key] = true
  return true
}

// Sprite 16x16 do computador antigo: O/E/C tinta, B gabinete, F tela, A destaque, X alerta, Z sono
function characterId(value) {
  return ["computer", "cat", "robot", "dog"].indexOf(value) >= 0 ? value : "computer"
}

function petRows(state, frame, character, detailed) {
  character = characterId(character)
  if (detailed) return detailedPetRows(state, frame, character)
  if (character !== "computer") return characterRows(state, frame, character)
  var eye = state === "limit" && !frame ? "X" : "E"
  var upper = state === "sleep" || state === "focus" ? "F" : eye
  var lower = state === "done" ? "F" : state === "focus" ? "C" : eye
  var mouth = state === "attention" ? "XX" : "EE"
  return [
    state === "attention" && !frame ? ".......XX......." : state === "sleep" ? "......Z..Z......"
      : state === "working" && !frame ? ".A............A." : "................",
    "..OOOOOOOOOOOO..",
    "..OBBBBBBBBBBO..",
    "..OBOOOOOOOOBO..",
    "..OBOFFFFFFOBO..",
    state === "working" && frame ? "..OBOBBBBBBOBO.." : "..OBOFFFFFFOBO..",
    "..OBOF" + upper + "FF" + upper + "FOBO..",
    "..OBOF" + lower + "FF" + lower + "FOBO..",
    "..OBOFF" + mouth + "FFOBO..",
    "..OBOFFFFFFOBO..",
    "..OBOOOOOOOOBO..",
    "..OBBBBAABBBBO..",
    "..OOOOOOOOOOOO..",
    "......OOOO......",
    "....OBBBBBBO....",
    "....OOOOOOOO...."
  ]
}

// Silhuetas de 16×16; expressões e sinais seguem os mesmos estados do computador.
function characterRows(state, frame, character) {
  var rows
  if (character === "cat") rows = [
    "................", "..OO........OO..", "..OBO......OBO..", "..OBBOOOOOOBBO..",
    "..OBBBBBBBBBBO..", "..OBBBBBBBBBBO..", "..OBBBBBBBBBBO..", ".AOBBBBBBBBBBOA.",
    "..OBBBBAABBBBO..", ".AOBBBBBBBBBBOA.", "...OOOOOOOOOO...", "....OBBBBBO.....",
    "....OBBBBBO..OO.", "....OBBBBBO..BO.", "...OOBBBBBOOOBO.", "...OOOOOOOOOOO.."
  ]
  else if (character === "dog") rows = [
    "................", "................", "...OOOOOOOOOO...", ".OOOBBBBBBBBOOO.",
    ".OBOBBBBBBBBOBO.", ".OBOBBBBBBBBOBO.", ".OBOBBBBBBBBOBO.", ".OOOBBBBBBBBOOO.",
    "...OBFFAFFFBO...", "...OBFFAAFFBO...", "....OOOOOOOO....", ".....OBBBBO.....",
    ".....OBBBBO.OO..", ".....OBBBBOOBO..", "....OOBBBBOBO...", "....OOOOOOOO...."
  ]
  else rows = [
    ".......AA.......", ".......OO.......", "...OOOOOOOOOO...", "...OBBBBBBBBO...",
    ".OOOFFFFFFFFOOO.", ".OBOFFFFFFFFOBO.", ".OBOFFFFFFFFOBO.", ".OOOFFFFFFFFOOO.",
    "...OFFFFFFFFO...", "...OOOOOOOOOO...", "......OOOO......", "...OOOBBBAOOO...",
    "...OBOBAABOBO...", "...OOOBBBBOOO...", ".....OO..OO.....", "....OOO..OOO...."
  ]
  var face = character === "robot" ? "F" : "B"
  var eye = state === "limit" && !frame ? "X" : state === "sleep" || state === "focus" ? face : "E"
  var lower = state === "done" ? face : state === "focus" ? "C" : eye
  function pixel(x, y, value) { rows[y] = rows[y].slice(0, x) + value + rows[y].slice(x + 1) }
  ;[5, 10].forEach(function(x) { pixel(x, 6, eye); pixel(x, 7, lower) })
  if (state === "attention") { pixel(7, 8, "X"); pixel(8, 8, "X") }
  if (state === "focus") { pixel(3, 6, "A"); pixel(12, 6, "A") }
  if (state === "working") {
    pixel(frame ? 9 : 6, 12, "A")
    pixel(frame ? 6 : 9, 12, face)
  }
  if (state === "attention" && !frame) rows[0] = ".......XX......."
  if (state === "sleep") rows[0] = "......Z..Z......"
  if (character === "robot") {
    var phase = frame % 4
    var leftUp = state === "idle" ? phase === 1 || phase === 2 : state !== "sleep" && phase % 2 === 0
    var rightUp = state === "idle" ? phase === 2 || phase === 3 : state !== "sleep" && phase % 2 === 1
    for (var armY = 10; armY <= 13; armY++) {
      for (var armX = 1; armX <= 4; armX++) {
        pixel(armX, armY, "."); pixel(15 - armX, armY, ".")
      }
    }
    function arm(right, raised) {
      var x = raised ? 2 : 3
      var y = raised ? 10 : 11
      ;["OO", "BO", "OO"].forEach(function(row, offset) {
        row.split("").forEach(function(color, col) { pixel(right ? 15 - x - col : x + col, y + offset, color) })
      })
      pixel(right ? 11 : 4, 12, "O")
    }
    arm(false, leftUp); arm(true, rightUp)
    if (state === "idle" && phase === 3) {
      ;[5, 10].forEach(function(x) { pixel(x, 6, "F"); pixel(x, 7, "E") })
    }
    if (state === "idle" && phase % 2) rows[0] = ".......FF......."
  }
  return rows
}

// A versão ampliada ganha contorno, volume e detalhes sem perder a leitura do ícone.
function detailedPetRows(state, frame, character) {
  var small = petRows(state, frame, character)
  var pixels = []
  small.forEach(function(row) {
    var doubled = row.split("").map(function(pixel) { return pixel + pixel }).join("")
    pixels.push(doubled.split(""), doubled.split(""))
  })
  function dot(x, y, color) { pixels[y][x] = color }
  function line(x, y, text) { text.split("").forEach(function(color, offset) { dot(x + offset, y, color) }) }
  function body(x, y, color) { if (pixels[y][x] === "B") dot(x, y, color) }
  // Luz à esquerda, sombra à direita; somente dentro do corpo.
  for (var y = 1; y < 31; y++) {
    for (var x = 1; x < 31; x++) {
      if (pixels[y][x] !== "B") continue
      if (pixels[y][x - 1] === "O" || pixels[y - 1][x] === "O") body(x, y, "H")
      else if (pixels[y][x + 1] === "O" || pixels[y + 1][x] === "O") body(x, y, "S")
    }
  }
  if (character === "computer") {
    line(9, 8, "GGGGGGGGGGGGGG")
    for (var edge = 10; edge < 20; edge++) dot(23, edge, "D")
    line(7, 22, "SBSB")
    line(21, 22, "BSBS")
    line(14, 23, "AHHA")
    line(10, 28, "HHHHHHHHHHHH")
    line(10, 29, "SSSSSSSSSSSS")
    if (state !== "sleep" && state !== "focus" && state !== "limit") {
      dot(12, 12, "G"); dot(18, 12, "G")
    }
  } else if (character === "cat" || character === "dog") {
    if (character === "cat") {
      line(6, 5, "AS"); line(24, 5, "SA")
      line(6, 6, "AAS"); line(23, 6, "SAA")
      line(12, 9, "SBBSSBBS")
      line(3, 15, "EEE"); line(26, 15, "EEE")
      line(2, 18, "EEE"); line(27, 18, "EEE")
      line(13, 23, "HHHH")
      line(12, 24, "HHHHHH")
      line(12, 25, "HHHHHH")
      line(12, 26, "HHHHHH")
      line(12, 28, "SHHS")
      dot(11, 28, "E"); dot(18, 28, "E")
      line(26, 26, "HA")
    } else {
      line(3, 9, "SS"); line(27, 9, "SS")
      line(3, 10, "SS"); line(27, 10, "SS")
      line(3, 11, "SS"); line(27, 11, "SS")
      line(12, 22, "AAAAAA")
      line(15, 23, "AH")
      line(13, 25, "HHHH")
      line(13, 26, "HHHH")
      dot(13, 28, "E"); dot(18, 28, "E")
      dot(26, 25, "H")
    }
    line(12, 16, "HHHHHHHH")
    line(12, 17, character === "dog" ? "HHHEEHHH" : "HHHAAHHH")
    line(13, 18, "HHEEHH")
    line(13, 19, "HEHHEH")
    if (state === "attention") line(14, 17, "XXXX")
    if (state === "working") line(14, 19, frame ? "AAAA" : "HEEH")
    if (state !== "sleep" && state !== "focus" && state !== "limit") {
      dot(10, 12, "H"); dot(20, 12, "H")
    }
  } else {
    line(14, 0, frame % 2 ? "AGGA" : "AHHA")
    line(9, 8, "GGGGGGGGGGGGGG")
    line(9, 17, "DDDDDDDDDDDDDD")
    line(6, 10, "HS"); line(24, 10, "SH")
    line(13, 23, "EAAE")
    line(13, 24, "EAAE")
    line(13, 26, "SSSSSS")
    line(8, 30, "HHHHHH"); line(18, 30, "HHHHHH")
    if (state !== "sleep" && state !== "focus" && state !== "limit" && !(state === "idle" && frame % 4 === 3)) {
      dot(10, 12, "G"); dot(20, 12, "G")
    }
  }
  return pixels.map(function(row) { return row.join("") })
}

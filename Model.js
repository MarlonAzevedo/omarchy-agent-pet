.pragma library

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

function petState(sessions, limits, now) {
  if (hasAttention(sessions)) return "attention"
  if (alarmingLimit(limits, 90, now)) return "limit"
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
function resetLabel(resetsAt, now) {
  if (!resetsAt) return ""
  var time = new Date(String(resetsAt)).getTime()
  var current = now === undefined ? Date.now() : Number(now)
  if (!isFinite(time) || time <= current) return ""
  var minutes = Math.ceil((time - current) / 60000)
  if (minutes < 60) return "em " + minutes + "min"
  if (minutes < 24 * 60) {
    var rest = minutes % 60
    return "em " + Math.floor(minutes / 60) + "h" + (rest < 10 ? "0" : "") + rest
  }
  var date = new Date(time)
  var days = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
  var pad = function(value) { return (value < 10 ? "0" : "") + value }
  return days[date.getDay()] + " " + pad(date.getHours()) + ":" + pad(date.getMinutes())
}

function sessionName(session) {
  if (session.session_title) return session.session_title
  var parts = String(session.cwd || "").split("/").filter(function(part) { return part })
  return parts.length ? parts[parts.length - 1] : session.session_id
}

var VERBS = { Edit: "Editando", apply_patch: "Editando", MultiEdit: "Editando", Write: "Escrevendo", Read: "Lendo", NotebookEdit: "Editando",
  Grep: "Buscando", Glob: "Buscando", WebSearch: "Pesquisando", Task: "Subagente ·", Agent: "Subagente ·" }

function activityText(session) {
  if (session.status === "attention") return session.attention_reason === "permission" ? "Pediu permissão" : "Esperando resposta"
  if (session.status !== "working") return "Ocioso"
  if (!session.current_tool) return "Pensando"
  if (!session.tool_detail) return session.current_tool
  return (VERBS[session.current_tool] || session.current_tool + " ·") + " " + session.tool_detail
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

// Sprite 16x16 do computador antigo: O/E/C tinta, B gabinete, F tela, A destaque, X alerta, Z sono
function petRows(state, frame) {
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

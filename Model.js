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

var DAYS = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]

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
  var pad = function(value) { return (value < 10 ? "0" : "") + value }
  return DAYS[date.getDay()] + " " + pad(date.getHours()) + ":" + pad(date.getMinutes())
}

function sessionName(session) {
  if (session.session_title) return session.session_title
  var parts = String(session.cwd || "").split("/").filter(function(part) { return part })
  return parts.length ? parts[parts.length - 1] : session.session_id
}

var VERBS = { Edit: "Editando", apply_patch: "Editando", MultiEdit: "Editando", Write: "Escrevendo", Read: "Lendo", NotebookEdit: "Editando",
  Grep: "Buscando", Glob: "Buscando", WebSearch: "Pesquisando", Task: "Subagente ·", Agent: "Subagente ·",
  read_file: "Lendo", write_file: "Escrevendo", edit_file: "Editando", run_command: "Rodando" }

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

var AGENT_LABELS = { claude: "Claude Code", codex: "Codex", antigravity: "Antigravity" }

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
function dayRows(recentDays, today) {
  var list = recentDays || []
  var peak = Math.max.apply(null, [0].concat(list.map(function(day) { return Number(day.messageCount) || 0 })))
  return list.map(function(day) {
    var tokens = Number(day.messageCount) || 0
    var date = new Date(day.date + "T00:00:00")
    return { date: day.date, label: day.date === today ? "Hoje" : DAYS[date.getDay()], tokens: tokens, share: peak ? tokens / peak : 0, today: day.date === today }
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
function focusMessage(info, focus) {
  if (info.phase === "done") return "Foco concluído · " + info.rounds + " rodadas"
  if (info.phase === "break") return "Pausa de " + focus.break_min + " min · rodada " + info.round + "/" + info.rounds + " concluída"
  return "Foco: rodada " + info.round + "/" + info.rounds + " · " + focus.work_min + " min"
}

// Biblioteca compartilhada: só a primeira cópia do painel (um por monitor) avisa
var CLAIMED = {}
function claimOnce(key) {
  if (CLAIMED[key]) return false
  CLAIMED[key] = true
  return true
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

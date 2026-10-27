import { readFileSync } from "node:fs"
const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "; return { sortSessions, hasAttention, alarmingLimit, visible, formatDuration, limitPercent, sessionElapsed, petState, petRows, windowShort, resetLabel, sessionName, activityText, permissionText, shortDuration, runningCount, depletionTime, visibleRecords, visibleSessions, agentLabel, limitRecords, pickRecord, keepLimits, jsonFiles, usageRecords, dayRows, modelRows, focusPhase, focusClock, claimOnce, focusMessage, hooksText }")()
let failures = 0

function expect(name, actual, expected) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures++
    console.error(`${name}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`)
  }
}

const sessions = [
  { session_id: "idle", status: "idle", updated_at: 30 },
  { session_id: "attention-old", status: "attention", updated_at: 10 },
  { session_id: "working", status: "working", updated_at: 40 },
  { session_id: "attention-new", status: "attention", updated_at: 20 },
]
expect("attention first, then most recent", Model.sortSessions(sessions).map(item => item.session_id), ["attention-new", "attention-old", "working", "idle"])
expect("attention detection", Model.hasAttention(sessions), true)
expect("empty hidden, including when limits exist", Model.visible([], [{ percent: 80 }]), false)
expect("session visible", Model.visible([{ status: "idle" }]), true)
// Omarchy grava percent como fração (0.04 = 4%)
expect("near limit alarms", Model.alarmingLimit([{ percent: 0.9 }]), true)
expect("low limit does not alarm", Model.alarmingLimit([{ percent: 0.5 }]), false)
expect("expired limit does not alarm", Model.alarmingLimit([{ percent: 1, resetsAt: "2000-01-01T00:00:00Z" }]), false)
expect("fraction shown as percent", Model.limitPercent({ percent: 0.04 }), 4)
expect("percent bounded", Model.limitPercent({ percent: 1.2 }), 100)
expect("duration formatting", Model.formatDuration(3661), "1h 1min")
expect("working activity duration", Model.sessionElapsed({ status: "working", turn_started_at: 1000 }, 62000), 61)
expect("idle has no active duration", Model.sessionElapsed({ status: "idle", updated_at: 1000 }, 62000), null)

expect("attention wins over limit", Model.petState([{ status: "attention" }, { status: "working" }], [{ percent: 0.95 }], 0), "attention")
expect("limit wins over working", Model.petState([{ status: "working" }], [{ percent: 0.95 }], 0), "limit")
expect("working state", Model.petState([{ status: "working" }, { status: "idle" }], [{ percent: 0.2 }], 0), "working")
expect("idle state", Model.petState([{ status: "idle" }], [], 0), "idle")

for (const state of ["idle", "working", "attention", "done", "focus", "sleep", "limit"]) {
  for (const frame of [0, 1]) {
    const rows = Model.petRows(state, frame)
    expect(`${state}/${frame} is 16x16`, rows.length === 16 && rows.every(row => row.length === 16), true)
    expect(`${state}/${frame} is symmetric`, rows.every(row => row === [...row].reverse().join("")), true)
  }
}
expect("working animates", Model.petRows("working", 0).join() !== Model.petRows("working", 1).join(), true)
expect("attention animates", Model.petRows("attention", 0).join() !== Model.petRows("attention", 1).join(), true)
expect("states are distinct", new Set(["idle", "working", "attention", "done", "sleep", "limit"].map(state => Model.petRows(state, 0).join())).size, 6)

expect("5-hour window short", Model.windowShort("Session (5-hour)"), "5h")
expect("7-day window short", Model.windowShort("Weekly (7-day)"), "7d")
expect("unknown window keeps label", Model.windowShort("Créditos"), "Créditos")
const base = new Date(2026, 9, 25, 12, 0).getTime()
expect("reset within a day as countdown", Model.resetLabel(new Date(base + (2 * 60 + 10) * 60000).toISOString(), base), "em 2h10")
expect("reset within an hour in minutes", Model.resetLabel(new Date(base + 45 * 60000).toISOString(), base), "em 45min")
expect("reset after a day as weekday and time", Model.resetLabel(new Date(2026, 9, 30, 19, 32).toISOString(), base), "sex 19:32")
expect("expired reset is empty", Model.resetLabel(new Date(base - 60000).toISOString(), base), "")
expect("missing reset is empty", Model.resetLabel(null, base), "")

expect("session name from cwd", Model.sessionName({ cwd: "/home/u/landing-page" }), "landing-page")
expect("session title wins", Model.sessionName({ session_title: "worker", cwd: "/x/y" }), "worker")
expect("editing activity", Model.activityText({ status: "working", current_tool: "Edit", tool_detail: "Hero.tsx" }), "Editando Hero.tsx")
expect("bash activity", Model.activityText({ status: "working", current_tool: "Bash", tool_detail: "npm test" }), "Bash · npm test")
expect("search activity", Model.activityText({ status: "working", current_tool: "Grep", tool_detail: "TODO" }), "Buscando TODO")
expect("thinking without tool", Model.activityText({ status: "working" }), "Pensando")
expect("permission activity", Model.activityText({ status: "attention", attention_reason: "permission" }), "Pediu permissão")
expect("input activity", Model.activityText({ status: "attention", attention_reason: "input" }), "Esperando resposta")
expect("idle activity", Model.activityText({ status: "idle" }), "Ocioso")
expect("permission text", Model.permissionText({ current_tool: "Bash", tool_detail: "npm run migrate" }), "Bash: npm run migrate")
expect("permission text without detail", Model.permissionText({ current_tool: "Bash" }), "Bash")
expect("short duration under a minute", Model.shortDuration(40), "<1m")
expect("short duration minutes", Model.shortDuration(185), "3m")
expect("short duration hours", Model.shortDuration(3900), "1h05")
expect("running count", Model.runningCount([{ status: "working" }, { status: "attention" }, { status: "working" }, { status: "idle" }]), 2)
const reset = base + 2 * 3600000
expect("depletion before reset", Model.depletionTime({ label: "Session (5-hour)", percent: 0.78, resetsAt: new Date(reset).toISOString() }, base), base - 3 * 3600000 + Math.round(3 * 3600000 / 0.78))
expect("no depletion when pace lasts", Model.depletionTime({ label: "Session (5-hour)", percent: 0.2, resetsAt: new Date(reset).toISOString() }, base), null)
expect("no depletion for unknown window", Model.depletionTime({ label: "Créditos", percent: 0.9, resetsAt: new Date(reset).toISOString() }, base), null)
const records = [{ id: "claude", limits: [] }, { id: "codex", limits: [] }]
expect("hidden agents filtered", Model.visibleRecords(records, ["codex"]).map(record => record.id), ["claude"])
expect("no hidden list keeps all", Model.visibleRecords(records, undefined).length, 2)

expect("codex hour window short", Model.windowShort("720h window"), "30d")
expect("plain hour window short", Model.windowShort("5h window"), "5h")
expect("depletion for codex window", Model.depletionTime({ label: "720h window", percent: 0.9, resetsAt: new Date(base + 360 * 3600000).toISOString() }, base), base - 360 * 3600000 + Math.round(360 * 3600000 / 0.9))
expect("patch activity", Model.activityText({ status: "working", current_tool: "apply_patch", tool_detail: "Hero.tsx" }), "Editando Hero.tsx")
const mixed = [{ session_id: "a", agent: "codex" }, { session_id: "b", agent: "claude" }, { session_id: "c" }]
expect("hidden agent hides its sessions", Model.visibleSessions(mixed, ["codex"]).map(item => item.session_id), ["b", "c"])
expect("missing agent counts as claude", Model.visibleSessions(mixed, ["claude"]).map(item => item.session_id), ["a"])
expect("codex label", Model.agentLabel({ agent: "codex" }), "Codex")
expect("default label", Model.agentLabel({}), "Claude Code")

const usage = [
  { id: "claude", limits: [{ label: "Session (5-hour)", percent: 0.2 }] },
  { id: "codex", limits: [{ label: "720h window", percent: 0.6 }] },
  { id: "fireworks", limits: [] },
]
expect("only agents with limits are selectable", Model.limitRecords(usage, []).map(record => record.id), ["claude", "codex"])
expect("hidden agent is not selectable", Model.limitRecords(usage, ["claude"]).map(record => record.id), ["codex"])
expect("selected agent is picked", Model.pickRecord(Model.limitRecords(usage, []), "codex").id, "codex")
expect("unknown selection falls back to first", Model.pickRecord(Model.limitRecords(usage, []), "fireworks").id, "claude")
expect("no records picks nothing", Model.pickRecord([], "codex"), null)

// Coletor do Omarchy grava limites vazios quando o Codex demora no account/read
const good = [{ id: "codex", updatedAt: "2026-10-25T20:00:00Z", tierLabel: "free", limits: [{ label: "720h window", percent: 0.62 }] }]
const blank = [{ id: "codex", updatedAt: "2026-10-25T20:15:00Z", tierLabel: "", limits: [] }]
const at = iso => Date.parse(iso)
const kept = Model.keepLimits(good, blank, at("2026-10-25T20:15:00Z"), 1800000)
expect("transient failure keeps last limits", kept[0].limits, good[0].limits)
expect("transient failure keeps tier", kept[0].tierLabel, "free")
expect("kept record stays selectable", Model.limitRecords(kept, []).map(record => record.id), ["codex"])
const later = Model.keepLimits(kept, blank, at("2026-10-25T20:45:00Z"), 1800000)
expect("old limits expire by original time", later[0].limits, [])
expect("fresh limits win", Model.keepLimits(blank, good, at("2026-10-25T20:15:00Z"), 1800000)[0].limits, good[0].limits)
expect("no previous keeps current", Model.keepLimits([], blank, at("2026-10-25T20:15:00Z"), 1800000)[0].limits, [])

// A ordem do find segue a última gravação; lista fora de ordem recria os leitores e perde os limites guardados
expect("scan order does not depend on write order", Model.jsonFiles("/u/fireworks.json\n/u/codex.json\n/u/claude.json\n"), Model.jsonFiles("/u/claude.json\n/u/fireworks.json\n/u/codex.json\n"))
expect("scan keeps only json files", Model.jsonFiles("/u/b.json\n/u/.codex.tmp\n\n/u/a.json"), ["/u/a.json", "/u/b.json"])
expect("empty scan", Model.jsonFiles(""), [])

// Tela Uso: agentes com dados, tokens por dia e por modelo (como o widget Agents do Omarchy)
const usageData = [
  { id: "claude", todayPrompts: 3, limits: [] },
  { id: "codex", totalSessions: 5, limits: [] },
  { id: "fireworks", limits: [] },
]
expect("usage lists agents with data", Model.usageRecords(usageData, []).map(record => record.id), ["claude", "codex"])
expect("usage hides hidden agents", Model.usageRecords(usageData, ["codex"]).map(record => record.id), ["claude"])
const days = [{ date: "2026-10-24", messageCount: 50 }, { date: "2026-10-25", messageCount: 200 }]
expect("day rows scale to the busiest day", Model.dayRows(days, "2026-10-25"), [
  { date: "2026-10-24", label: "sáb", tokens: 50, share: 0.25, today: false },
  { date: "2026-10-25", label: "Hoje", tokens: 200, share: 1, today: true },
])
expect("quiet week has zero shares", Model.dayRows([{ date: "2026-10-24", messageCount: 0 }], "2026-10-25")[0].share, 0)
const byModel = {
  "a": { inputTokens: 10, outputTokens: 10 },
  "b": { inputTokens: 100, cacheReadInputTokens: 300 },
  "c": { outputTokens: 5 }, "d": { outputTokens: 1 }, "e": { outputTokens: 2 },
}
expect("model rows sorted, top 4, scaled", Model.modelRows(byModel), [
  { id: "b", total: 400, share: 1 }, { id: "a", total: 20, share: 0.05 },
  { id: "c", total: 5, share: 0.0125 }, { id: "e", total: 2, share: 0.005 },
])
expect("no model usage", Model.modelRows(undefined), [])

// Foco/pomodoro: fase calculada só pelo início e pelas durações, sobrevive ao painel fechado
const min = 60000
const focus = { work_min: 25, break_min: 5, rounds: 2, started_at: 0, paused_at: null }
expect("focus starts in work", Model.focusPhase(focus, 10 * min), { phase: "work", round: 1, remainingMs: 15 * min, share: 0.4, rounds: 2, paused: false })
expect("focus break after work", Model.focusPhase(focus, 27 * min), { phase: "break", round: 1, remainingMs: 3 * min, share: 0.4, rounds: 2, paused: false })
expect("focus second round", Model.focusPhase(focus, 30 * min).round, 2)
expect("no break after last round", Model.focusPhase(focus, 55 * min).phase, "done")
expect("paused focus stops the clock", Model.focusPhase({ ...focus, paused_at: 10 * min }, 20 * min).remainingMs, 15 * min)
expect("paused flag", Model.focusPhase({ ...focus, paused_at: 10 * min }, 20 * min).paused, true)
expect("no focus", Model.focusPhase({}, 0), null)
expect("focus clock", Model.focusClock(15 * min + 4000), "15:04")
expect("focus clock rounds seconds up", Model.focusClock(1500), "0:02")
expect("focusing pet", Model.petState([{ status: "working" }], [], 0, true), "focus")
expect("attention wins over focus", Model.petState([{ status: "attention" }], [], 0, true), "attention")
expect("claim once per key", [Model.claimOnce("a"), Model.claimOnce("a"), Model.claimOnce("b")], [true, false, true])

expect("work message", Model.focusMessage({ phase: "work", round: 2, rounds: 4 }, focus), "Foco: rodada 2/4 · 25 min")
expect("break message", Model.focusMessage({ phase: "break", round: 1, rounds: 4 }, focus), "Pausa de 5 min · rodada 1/4 concluída")
expect("done message", Model.focusMessage({ phase: "done", round: 4, rounds: 4 }, focus), "Foco concluído · 4 rodadas")

expect("hooks ok text", Model.hooksText("ok"), "Acompanhando Claude Code e Codex")
expect("hooks missing text", Model.hooksText("missing"), "Desativado: ative para ver as sessões dos agentes")
expect("hooks error text", Model.hooksText("error"), "Falhou; rode bin/agent-pet setup na pasta do plugin")

if (failures) process.exit(1)
console.log("checks passed")

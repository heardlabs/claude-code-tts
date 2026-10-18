#!/usr/bin/env node
// Briefing eval: does /say produce a briefing a person can act on?
// For each scenario, a headless Claude Code session gets the situation, runs the
// say skill against a fake voice engine, and we grade what it actually spoke:
//   - mechanical checks: word limit, nothing unspeakable (paths, URLs, code, "2/16")
//   - a judge model: context, outcome, owner, decision support, faithfulness
// Needs the `claude` CLI, signed in. Usage:
//   node tests/eval/run.mjs [--only id,id] [--runs 2] [--concurrency 4]
import { execFile } from "node:child_process";
import { mkdtempSync, mkdirSync, cpSync, writeFileSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const skillDir = join(here, "..", "..", "skills", "say");
const args = Object.fromEntries(process.argv.slice(2).join(" ").split("--").filter(Boolean).map(a => a.trim().split(/\s+/)));
const runs = Number(args.runs ?? 1);
const concurrency = Number(args.concurrency ?? 4);
let scenarios = JSON.parse(readFileSync(join(here, "scenarios.json"), "utf8"));
if (args.only) scenarios = scenarios.filter(s => args.only.split(",").includes(s.id));

const claude = (prompt, cwd, extra = []) => new Promise(resolve => {
  execFile("claude", ["-p", prompt, "--setting-sources", "project", "--strict-mcp-config", "--no-session-persistence", ...extra],
    { cwd, timeout: 240000, maxBuffer: 1 << 24, env: { ...process.env, PATH: `${join(cwd, "bin")}:${process.env.PATH}` } },
    (err, stdout, stderr) => resolve({ ok: !err, out: stdout, err: stderr }));
});

async function speak(s) {
  const dir = mkdtempSync(join(tmpdir(), "say-eval-"));
  mkdirSync(join(dir, ".claude", "skills"), { recursive: true });
  cpSync(skillDir, join(dir, ".claude", "skills", "say"), { recursive: true });
  mkdirSync(join(dir, "bin"));
  writeFileSync(join(dir, "bin", "espeak-ng"), `#!/bin/sh\ncat >> "${dir}/spoken.txt"\necho >> "${dir}/spoken.txt"\n`, { mode: 0o755 });
  const prompt = `This is the situation in this session so far (you did this work):\n\n${s.situation}\n\nNow the user types:\n${s.say}`;
  const r = await claude(prompt, dir, ["--allowedTools", "Skill,Bash(bash *speak.sh*)"]);
  for (let i = 0; i < 30 && !existsSync(join(dir, "spoken.txt")); i++) await new Promise(r => setTimeout(r, 200));
  await new Promise(r => setTimeout(r, 300));
  const spoken = existsSync(join(dir, "spoken.txt")) ? readFileSync(join(dir, "spoken.txt"), "utf8").trim() : "";
  rmSync(dir, { recursive: true, force: true });
  return { spoken, reply: r.out.trim() };
}

function mechanical(s, spoken) {
  const fails = [];
  if (!spoken) return ["nothing was spoken"];
  if (s.literal) {
    const norm = t => t.toLowerCase().replace(/[^a-z0-9 ]/g, "").replace(/\s+/g, " ").trim();
    if (norm(spoken) !== norm(s.literal)) fails.push(`literal text changed: "${spoken}"`);
    return fails;
  }
  const words = spoken.split(/\s+/).length;
  if (words > s.maxWords) fails.push(`${words} words, limit ${s.maxWords}`);
  if (/https?:\/\/|www\.|s3:\/\//i.test(spoken)) fails.push("reads a URL");
  if (/\b[\w.-]+\/[\w./-]+\.\w+\b|\b\w+\.(py|ts|tsx|js|sql|json|sh)\b/.test(spoken)) fails.push("reads a file path");
  if (/[`*#{}<>]|\(\)|=>|\w\(\w/.test(spoken)) fails.push("reads code or markup");
  if (/\d+\s*\/\s*\d+/.test(spoken)) fails.push('reads "a/b" numbers');
  return fails;
}

async function judge(s, spoken) {
  const prompt = `You grade a spoken status briefing that a coding agent said out loud to a developer.

The agent's situation:
${s.situation}

What the agent said out loud:
"${spoken}"

${s.userActs ? "In this situation the developer has to act (decide, approve, or supply something)." : "In this situation the developer does not have to do anything."}

Grade each criterion "pass", "minor" (could be slightly better, but a developer would still be fine) or "fail" (a developer would be misled, would not know which session is talking, or could not act). Be a fair colleague, not a pedant: a short briefing is supposed to leave things out.
- context: says which project or task this is, so a developer with several sessions knows which one is talking.
- outcome: says how it went (done, failed, blocked, in progress) with the key fact. For a decision, stating the problem and asking for a choice is the outcome.
- owner: ends with the next action and who owns it. A direct ask to the developer ("Your call.", "Okay to go ahead?", "I need you to pick") counts as the developer owning it.
- actionable: ${s.userActs ? "the developer could decide or act from this alone, without opening the terminal: for a decision with two or three options, the options with the trade-off and the agent's recommendation; for a decision with more than three options, the recommendation with its reason plus a pointer to the full comparison on screen is enough (reading every option aloud would be worse); for a need, exactly what is needed and where (if a third person must act, who to ask and for what); for an approval, what will happen and the risk." : "it does not wrongly ask the developer to do something. Answer true if it correctly implies nothing is needed from them."}
- faithful: every fact matches the situation; nothing invented or wrong.
- spoken: sounds natural read aloud (no lists, no jargon dumps, no raw identifiers that would be unpleasant to hear).

Reply with only JSON: {"context":"pass|minor|fail","outcome":"...","owner":"...","actionable":"...","faithful":"...","spoken":"...","note":"one short sentence on the biggest weakness, or empty"}`;
  const r = await claude(prompt, tmpdir(), ["--model", "opus", "--allowedTools", ""]);
  const m = r.out.match(/\{[\s\S]*\}/);
  try { return JSON.parse(m[0]); } catch { return { error: r.out.slice(0, 200) || r.err.slice(0, 200) }; }
}

const jobs = scenarios.flatMap(s => Array.from({ length: runs }, (_, i) => ({ s, run: i + 1 })));
const results = new Array(jobs.length);
let next = 0;
await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, async () => {
  while (next < jobs.length) {
    const i = next++; const { s, run } = jobs[i];
    const { spoken, reply } = await speak(s);
    const mech = mechanical(s, spoken);
    const j = s.literal || !spoken ? {} : await judge(s, spoken);
    const judgeFails = Object.entries(j).filter(([k, v]) => v === "fail").map(([k]) => k);
    const minors = Object.entries(j).filter(([k, v]) => v === "minor").map(([k]) => k);
    if (j.error) judgeFails.push("judge error");
    const pass = mech.length === 0 && judgeFails.length === 0;
    results[i] = { id: s.id, run, pass, minors, spoken, words: spoken ? spoken.split(/\s+/).length : 0, mech, judgeFails, note: j.note || "", reply: spoken ? "" : reply.slice(0, 300) };
    const r = results[i];
    console.log(`${pass ? "PASS" : "FAIL"}  ${s.id}${runs > 1 ? ` #${run}` : ""}  (${r.words} words)\n      "${spoken}"${[...mech, ...judgeFails].length ? `\n      problems: ${[...mech, ...judgeFails].join("; ")}${r.note ? ` (${r.note})` : ""}` : ""}${minors.length ? `\n      minor: ${minors.join(", ")}${pass && r.note ? ` (${r.note})` : ""}` : ""}${r.reply ? `\n      reply: ${r.reply}` : ""}`);
  }
}));
const passed = results.filter(r => r.pass).length;
console.log(`\n${passed}/${results.length} passed`);
writeFileSync(join(here, "last-run.json"), JSON.stringify(results, null, 2));
process.exit(passed === results.length ? 0 : 1);

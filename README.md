# turnstile

**A session hook cannot cost you the session.** That is the only promise, and everything
here exists to keep it.

A turnstile lets one thing through at a time, and when the power is off you walk straight
past it. That is the failure mode this tool is designed around: **when turnstile breaks,
your work continues** and it says out loud that nothing was checked.

## Why

Hooks are the strongest enforcement a project has and the easiest to get catastrophically
wrong, because a broken one fails in the one place you cannot work around it. Measured
across this estate on 2026-08-28:

| | |
|---|---|
| `SessionStart` hooks | 39KB · 34KB · 27KB · 17KB · 11KB · 9KB · 7KB |
| `PreToolUse` hooks | 9KB · 7KB · 5KB |

One `SessionStart` script grew until sessions stopped opening, against a **60-second
ceiling the editor hardcodes** — raising the hook's own timeout changed nothing, because
the hook was never what enforced it. A `PreToolUse` hook shipped to **seven repositories
exiting 0 for every call**, because `python` was missing from a hook's login `PATH`:
installed, green, never once blocking anything. Another was registered with a stray quote
in `settings.json` and had been checking nothing, silently, for an unknown length of time.

None of that is carelessness. It is what happens when the thing that enforces your rules
has no rules enforcing it.

## Install

**Vendor it.** Copy this repo's four scripts into the consumer at `tools/turnstile/`, or
add it as a submodule. There is nothing to build and no dependency to install; the wrapper
is POSIX `sh` on purpose, because it runs on the critical path and a sibling hook in this
estate shipped to seven repositories exiting 0 for every call when `python` was missing
from a hook's login `PATH`.

```sh
mkdir -p tools/turnstile
cp turnstile turnstile-run gate.template.sh mutation_check.sh tools/turnstile/
```

The scripts work at a repo root or vendored under `tools/turnstile/` — every path is
derived from `$0`, never assumed. Then register hooks **through the wrapper, never
directly**:

```json
{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [
  { "command": "sh tools/turnstile/turnstile-run .claude/hooks/my-gate.sh" }
] } ] } }
```

```sh
./turnstile decide          # should this even be a hook?
./turnstile new my-gate     # scaffold a survivable one
./turnstile check           # what is installed, and what is wrong with it
./turnstile test            # every hook's selftest
./turnstile off             # ← when it all goes wrong
```

## The five guarantees

Each exists because the unwrapped version failed somewhere real.

1. **A hook you did not declare a gate cannot block you.** Hooks are advisory by default;
   refusing requires the exact line `# turnstile: gate`. This is what makes a first hook
   safe to install: it can print, and it cannot cost you an afternoon.
2. **A slow hook cannot kill the session.** Every run has a budget (5s default,
   `# turnstile: budget N`). Over it, the hook is killed and the tool exits 0. macOS ships
   no `timeout(1)`, so the budget is implemented in the wrapper — a budget that silently
   isn't enforced on the machine you're using is the bug this tool is about.
3. **A killed hook is detected next time.** A breadcrumb is dropped before and removed
   after. A stale one means the last run was killed, so the next enters SAFE MODE: prints
   the diagnosis, skips the hook, stays latched until you clear it. Otherwise a hook that
   kills sessions kills *every* session.
4. **There is an off switch you can reach without a session** — `touch ~/.turnstile-off`.
   In `$HOME` on purpose: a switch inside the repo is unreachable when the broken thing is
   what opens the repo.
5. **It says when it did nothing.** Every skip prints which guarantee skipped it. Silence
   from a guard is indistinguishable from a guard that ran and passed, and this estate has
   shipped that twice.

## The decision tree, in one line

`turnstile decide` prints it in full. The rung that matters:

> **A test and a hook enforce the same rule. A broken test costs you a red line. A broken
> hook costs you your session. Prefer the mechanism whose failure is loud and cheap.**

Most things that feel like hooks are tests. Most of the rest are prose. Rung 5 — making the
wrong thing impossible to express — beats every gate.

## What it does not do

- **It does not make a bad hook good.** It bounds the damage.
- **It does not check what your hook checks.** That is your selftest's job, and
  `turnstile check` will tell you when you have not written one.
- **It does not stop `SessionStart` hooks.** It warns, budgets them, and gives you the
  latch. If you insist, at least you will know when one was skipped.

## Two things to do the day you adopt it

**Run `turnstile check` before changing anything.** It is a five-second inventory and it
finds registered-but-missing hooks, duplicate registrations, unwrapped hooks, hooks with no
selftest, and anything on the blocking startup path.

**Watch a selftest go red.** `turnstile test` runs them; `mutation_check.sh` breaks
each tool on purpose and requires its selftest to fail. A selftest you have never seen fail
is a claim you have never checked — and both of this repo's first two tools passed while
completely broken, which is why that harness exists.

## Self-application

Every guarantee above has an assertion in `turnstile-run --selftest`, and four mutations in
`mutation_check.sh` break the wrapper on purpose and require it to notice.

**It has already caught itself twice.** `turnstile check` reported that `turnstile-run` had
no `--selftest`, before it was committed. And the first version read declarations from the
first 40 lines only — this estate writes 40-plus-line incident headers, so the first real
gate it wrapped had its declaration at line 44 and was **silently downgraded to advisory**.
A fail-open produced by the safety wrapper. Both are recorded in the files where they
happened, not only here.

## Provenance

Extracted 2026-08-28 from `syncytium2/short-course`, where it was written in response to a
straightforward question: *are session hooks simply too complicated for a beginner to use
safely?* The measurement said the fear was correctly aimed and at the wrong noun — not
hooks, but `SessionStart` hooks — and this is what came out of answering it.

Licensed Apache-2.0, matching its sibling `syncytium2/murderboard`.

**Authorship.** The ideas, decisions and review are Tony DeFazio's; the code is Claude's
(Anthropic's Claude Code). Agent commits carry a `Co-Authored-By: Claude` trailer.

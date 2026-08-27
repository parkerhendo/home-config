#!/usr/bin/env bash
# scripts/pre-commit-gate.sh — a determinism guardrail for AI-written code.
# Installed by the Header skill (`/header` → determinism rails). Runs blocking
# quality gates before `git commit`. ONE script, two trigger surfaces:
#
#   • git-native    .githooks/pre-commit execs this (HEADER_GATE_FORCE=1).
#                   Gates humans AND every agent/harness; each clone enables it
#                   once with `git config core.hooksPath .githooks`.
#   • Claude Code   a PreToolUse(Bash) hook execs this with the tool JSON on
#                   stdin. Gates the agent in-loop and auto-propagates to
#                   teammates on clone (it lives in committed .claude/settings.json).
#
# Exit 0 = allow the commit. Exit 2 = block it.
#
# Why a guardrail and not a CLAUDE.md instruction: a non-deterministic agent
# forgets to run things. Prose asks; this enforces. Every BLOCKED message below
# is written as *agent remediation* (the exact next command) so a blocked agent
# self-corrects in-loop instead of you finding it in CI.
#
# Dependency: python3 (robust git-commit detection on the PreToolUse path). A
# coarse fallback runs if python3 is absent; the git-native path needs no python.
set -uo pipefail

# ── Should this invocation run the gates? ─────────────────────────────
# git-native hook → always (git only runs pre-commit on a commit). TTY/direct
# run → always. PreToolUse → only when the tool command is a real `git commit`
# (so the gates don't fire on `git status`, `ls`, etc.). Any parse failure errs
# toward running — better to false-fire than skip a real commit.
CMD=""
RUN_GATES=0
if [ "${HEADER_GATE_FORCE:-}" = "1" ]; then
  RUN_GATES=1
elif [ -t 0 ]; then
  RUN_GATES=1
else
  INPUT="$(cat)"
  if command -v python3 >/dev/null 2>&1; then
    CMD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)"
    # Token-walk: a real commit is a `git` token followed (only flag-like tokens
    # between) by a `commit` token. Matches `git -C /p commit`, `a && git commit`;
    # rejects `git add pre-commit`, `printf "...commit..."`, `git commit-graph`.
    IS_COMMIT="$(printf '%s' "$CMD" | python3 -c '
import shlex, sys
cmd = sys.stdin.read()
try:
    toks = shlex.split(cmd, posix=True)
except ValueError:
    print("yes"); sys.exit(0)
OPTS_WITH_ARG = ("-C","-c","--git-dir","--work-tree","--namespace")
i = 0
while i < len(toks):
    if toks[i] == "git":
        j = i + 1
        while j < len(toks):
            t = toks[j]
            if t in OPTS_WITH_ARG and j + 1 < len(toks): j += 2
            elif t.startswith("-"): j += 1
            else: break
        if j < len(toks) and toks[j] == "commit":
            print("yes"); sys.exit(0)
    i += 1
print("no")
' 2>/dev/null || echo yes)"
  else
    # No python3 — coarse extraction + match; errs toward running the gates.
    CMD="$(printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)"
    case "$CMD" in *git*commit*) IS_COMMIT=yes ;; *) IS_COMMIT=no ;; esac
  fi
  [ "$IS_COMMIT" = "yes" ] && RUN_GATES=1
fi
[ "$RUN_GATES" -eq 1 ] || exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

FAILED=0
fail() { echo "BLOCKED: $1" >&2; FAILED=1; }

#==COMPOUND==

#==RATCHET==

# ── Stack checks (staged files only; agent-actionable on failure) ─────
#==CHECKS==

if [ "$FAILED" -eq 1 ]; then
  exit 2
fi
exit 0

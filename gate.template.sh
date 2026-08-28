#!/usr/bin/env sh
# __NAME__.sh — refuse one specific thing, and say what to do instead.
#
# turnstile: advisory
# turnstile: budget 5
#
# ADVISORY UNTIL YOU CHANGE IT. Change the line above to `# turnstile: advisory` ->
# `# turnstile: gate` only when you have watched the selftest go red. Until then this
# can print and cannot block you, which is the point: your first hook must not be able
# to cost you an afternoon.
#
# WRITE THE INCIDENT HERE, NOT A DESCRIPTION. Every gate in this estate that survived
# opens with the date and the thing that went wrong. A gate whose header says what it
# does gets deleted by the next person; one that says what it cost does not.
#
#   WHY THIS EXISTS. <date>. <what happened, in two sentences, with the cost.>
#
# Register it WRAPPED:
#     "command": "sh tools/turnstile/turnstile-run .claude/hooks/__NAME__.sh"
#
# Exit 0 = allow. Exit 2 = block (only honoured once declared a gate).

set -u

# ---------------------------------------------------------------- what it catches
# Match on VERBS, not names. A command that merely MENTIONS the thing reads nothing
# and does nothing -- blocking `grep -rn forbidden docs/` teaches people to route
# around you, and a gate people route around is worse than no gate.
PATTERN='REPLACE_ME'          # the thing that must not happen
ESCAPE='__NAME__'_OK          # e.g. MYGATE_OK=1 to get past it deliberately

# ---------------------------------------------------------------------- selftest
# RUN THIS AND WATCH IT GO RED BEFORE YOU TRUST IT. A selftest you have never seen
# fail is a claim you have never checked. Add it to tools/mutation_check.sh so
# something else keeps checking that it can still fail.
if [ "${1:-}" = "--selftest" ]; then
    f=0
    t() { got=$(printf '%s' "$2" | sh "$0" >/dev/null 2>&1; echo $?)
          if [ "$got" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (want $3 got $got)"; f=1; fi; }

    t "the forbidden thing is refused" '{"tool_input":{"command":"'"$PATTERN"'"}}' 2
    t "merely naming it is not"        '{"tool_input":{"command":"grep -rn '"$PATTERN"' docs/"}}' 0
    t "an unrelated command is not our business" '{"tool_input":{"command":"ls -la"}}' 0
    t "the escape hatch opens it"      '{"tool_input":{"command":"'"$ESCAPE"'=1 '"$PATTERN"'"}}' 0
    # A hook must not depend on an interpreter that might be missing from a login PATH.
    got=$(printf '%s' '{"tool_input":{"command":"'"$PATTERN"'"}}' | env PATH=/usr/bin:/bin sh "$0" >/dev/null 2>&1; echo $?)
    [ "$got" = 2 ] && echo "  ok   still fires with a minimal PATH" || { echo "  FAIL needs something not on a minimal PATH"; f=1; }

    [ $f = 0 ] && { echo PASS; exit 0; } || { echo FAIL; exit 1; }
fi

# -------------------------------------------------------------------- the check
PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || exit 0

case "$PAYLOAD" in
    *"$ESCAPE=1"*) exit 0 ;;                       # deliberate, and said so
    *grep*"$PATTERN"*|*"$PATTERN"*grep*) exit 0 ;; # a mention, not an act
    *"$PATTERN"*) : ;;
    *) exit 0 ;;
esac

# --------------------------------------------------------------- the refusal
# ANSWER, DO NOT ONLY REFUSE. The session that trips this is usually lost, not
# defiant -- it reached for the wrong thing because it could not find the right one.
# A gate that says only "no" leaves it lost and it goes and does something else
# wrong. Name the correct move here, and read it live from wherever the answer
# actually lives so this text can never become the stale copy.
{
  echo ""
  echo "  BLOCKED — <what just got refused, in one line>."
  echo ""
  echo "  Why: <the cost, from the incident in the header>"
  echo ""
  echo "  What you probably want instead:"
  echo "      <the correct command>"
  echo ""
  echo "  If you genuinely mean it:"
  echo "      $ESCAPE=1 <your command>"
  echo ""
} >&2
exit 2

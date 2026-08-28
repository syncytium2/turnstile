#!/usr/bin/env sh
# mutation_check.sh — break each tool on purpose and require its selftest to go red.
#
#   tools/mutation_check.sh          run every mutation
#   tools/mutation_check.sh --list   show them without running
#
# WHY THIS EXISTS. On 2026-08-27 this repo grew three small tools, each with a `--selftest`,
# all three green. On 2026-08-28 two of them were mutated to prove the tests had teeth and
# they did not:
#
#   * `claim.sh --release` was disabled outright -- the awk output was never moved back over
#     the board -- and its selftest still said PASS. It had been checking that this FILE
#     CONTAINED THE STRING "FAILED to release", not that releasing worked.
#   * `session_identity.sh` was made to return the literal `XXX/XXX` as the session address
#     and its selftest still said PASS. It asserted the address had a slash and no spaces,
#     which `XXX/XXX` satisfies.
#
# Both were written the same night the repo filed three case reports about checks that
# cannot fire. A selftest is a claim about behaviour, and an unmutated selftest is an
# unchecked claim -- the thing this whole estate exists to be suspicious of.
#
# THIS SCRIPT MUST NOT LIE EITHER. Its first draft reported MISSED when its own mutation
# failed to apply, which would have read as "that test is weak" when in fact nothing had
# been tested. Every mutation here is VERIFIED TO HAVE CHANGED THE FILE before the selftest
# is trusted, and a mutation that does not apply is an ERROR, never a result.
#
# Exit 0 = every mutation was caught. Exit 1 = at least one was missed or could not apply.

set -u
cd "$(dirname "$0")" || exit 1

# file @@ find @@ replace @@ what it breaks
MUTATIONS=$(cat <<'TABLE'
turnstile-run@@if [ "$MODE" != gate ]@@if false@@advisory hooks could block
turnstile-run@@if [ -e "$KILL_SWITCH" ]; then@@if false; then@@kill switch ignored
turnstile-run@@if [ "$rc" -ge 128 ] || [ "$elapsed" -ge "$BUDGET" ]; then@@if false; then@@budget not enforced
turnstile-run@@note "SAFE MODE@@: "SAFE MODE@@safe-mode latch goes silent
turnstile@@[ -f "$SELF_DIR/gate.template.sh" ]@@[ -f "/dev/null" ]@@template check defanged
TABLE
)

[ "${1:-}" = "--list" ] && { printf '%s\n' "$MUTATIONS" | while IFS='@' read -r f _ a _ b _ l; do
    printf '  %-46s %s\n' "$f" "$l"; done; exit 0; }

caught=0; missed=0; errors=0
BAK=$(mktemp -d) || exit 1
: > "$BAK/ok"; : > "$BAK/miss"; : > "$BAK/err"
trap 'rm -rf "$BAK"' EXIT INT TERM

printf '%s\n' "$MUTATIONS" | while IFS='@' read -r FILE _ FROM _ TO _ LABEL; do
    [ -n "$FILE" ] || continue
    printf '  %-52s ' "$LABEL"

    if [ ! -f "$FILE" ]; then printf 'ERROR no such file: %s\n' "$FILE"; echo E >> "$BAK/err"; continue; fi

    cp "$FILE" "$BAK/orig" || { printf 'ERROR cannot back up\n'; echo E >> "$BAK/err"; continue; }

    # Fixed strings, not regex: these are shell fragments full of $ and quotes, and a
    # regex that silently matches nothing is how the first draft of this script produced
    # a confident false finding.
    MUT_FROM="$FROM" MUT_TO="$TO" awk '
        BEGIN { from = ENVIRON["MUT_FROM"]; to = ENVIRON["MUT_TO"] }
        {
          i = index($0, from)
          if (i > 0) { $0 = substr($0, 1, i-1) to substr($0, i + length(from)); n++ }
          print
        }
        END { exit (n > 0 ? 0 : 3) }
    ' "$FILE" > "$BAK/mutated" 2>/dev/null
    st=$?

    if [ "$st" != 0 ] || cmp -s "$FILE" "$BAK/mutated"; then
        printf 'ERROR mutation did not apply — the test was never exercised\n'
        echo E >> "$BAK/err"; continue
    fi

    cp "$BAK/mutated" "$FILE"
    out=$(sh "$FILE" --selftest 2>/dev/null | tail -1)
    cp "$BAK/orig" "$FILE"

    if [ "$out" = "FAIL" ]; then printf 'caught\n'; echo C >> "$BAK/ok"
    else printf 'MISSED — selftest said "%s" with the tool broken\n' "$out"; echo M >> "$BAK/miss"; fi
done

c=$(wc -l < "$BAK/ok"   2>/dev/null || echo 0)
m=$(wc -l < "$BAK/miss" 2>/dev/null || echo 0)
e=$(wc -l < "$BAK/err"  2>/dev/null || echo 0)
printf '\n  caught %s   missed %s   errors %s\n' "$c" "$m" "$e"

# An ERROR is not a pass. A mutation that could not be applied proves nothing, and
# treating it as a pass is the exact failure this file was written about.
if [ "$m" -eq 0 ] && [ "$e" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL"; exit 1

#!/bin/zsh
# End-to-end tests for devloop against a fake claude and a throwaway project.
HERE=${0:A:h}
DEVLOOP=${DEVLOOP_BIN:-$HERE/../devloop}
export DEVLOOP_CLAUDE=$HERE/fake_claude DEVLOOP_SLEEP_S=1 DEVLOOP_BACKOFF_S=0
pass=0 fail=0

setup() {
  T=$(mktemp -d)
  mkdir -p $T/proj/CODE
  git -C $T/proj/CODE init -q && git -C $T/proj/CODE -c user.name=t -c user.email=t@e commit -q --allow-empty -m init
  git -C $T/proj/CODE config user.name t; git -C $T/proj/CODE config user.email t@e
  print "# Handoff\n\n## Next action\n- item 1\n- item 2" > $T/proj/HANDOFF.md
  print '{"session": {"used_pct": 10}}' > $T/budget.json
  export DEVLOOP_BUDGET=$T/budget.json
}
expect() {  # name, wanted exit code, actual exit code, [log must contain]
  if [[ $3 == $2 ]] && { [[ -z $4 ]] || command grep -q -- "$4" $T/state/devloop.log; }; then
    (( pass++ )); print "ok   $1"
  else
    (( fail++ )); print "FAIL $1 (exit $3, wanted $2)"; tail -5 $T/state/devloop.log 2>/dev/null
  fi
}
run() { $DEVLOOP --project $T/proj --state $T/state "$@" >/dev/null 2>&1; }

setup; FAKE_MODE=work FAKE_ITEMS=2 run --check true --after true
expect "work to done, check and after pass" 0 $? "finished"
[[ $(git -C $T/proj/CODE rev-list --count HEAD) == 3 ]] && expect "one commit per iteration" 0 0 || expect "one commit per iteration" 0 1

setup; FAKE_MODE=idle run --check true
expect "no progress stops after 3" 2 $? "STOP: 3 iterations without progress"

setup; FAKE_MODE=limit run --check true --stall 2
expect "usage-limit exits back off and stall out" 2 $? "quick exit — backing off"

setup; FAKE_MODE=work FAKE_ITEMS=5 run --check true --max-iter 2
expect "max iterations stops" 3 $? "STOP: 2 iterations without the done marker"

setup; FAKE_MODE=work FAKE_ITEMS=1 run --check false
expect "check failing after done stops" 4 $? "STOP: check failed after done"

setup; FAKE_MODE=work FAKE_ITEMS=1 run --check true --after false
expect "after command failing stops" 5 $? "STOP: after command failed"

setup; print '{"session": {"used_pct": 99}}' > $T/budget.json
( sleep 2; print '{"session": {"used_pct": 3}}' > $T/budget.json ) &
FAKE_MODE=work FAKE_ITEMS=1 run --check true
expect "waits for the budget reset, then works" 0 $? "sleeping 1s for the reset"
wait

setup; rm $T/proj/HANDOFF.md; run --check true
expect "no HANDOFF.md refuses" 66 $?

setup; FAKE_MODE=work FAKE_ITEMS=1 $DEVLOOP --project $T/proj --state $T/state --check true >/dev/null 2>&1
[[ $(<$T/state/DEV_DONE) == $(git -C $T/proj/CODE rev-parse HEAD) ]]
expect "template paths reach the session (done file written where told)" 0 $?

print "\n$pass passed, $fail failed"
(( fail == 0 ))

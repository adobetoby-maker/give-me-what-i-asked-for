#!/bin/bash
# Stop hook
# Fires at the end of every Claude turn.
# If a visual gate is still armed when the turn ends:
#   → the model said something without clearing the gate
#   → write /tmp/skipped-gate so next prompt-gate is maximally aggressive

NOW=$(date +%s)
SKIPPED=false
REASON=""

if [ -f /tmp/visual-gate-pending ]; then
  TAKEN=$(cat /tmp/visual-gate-pending 2>/dev/null)
  if [[ -n "$TAKEN" ]] && (( NOW - TAKEN <= 600 )); then
    SKIPPED=true
    REASON="pending-screenshots"
  fi
fi

if [ -f /tmp/visual-server-needed ]; then
  ENTRY=$(cat /tmp/visual-server-needed 2>/dev/null)
  TS=$(echo "$ENTRY" | cut -d: -f1)
  if [[ -n "$TS" ]] && (( NOW - TS <= 600 )); then
    SKIPPED=true
    REASON="${REASON:+$REASON+}server-down"
  fi
fi

if [ "$SKIPPED" = "true" ]; then
  # Write/overwrite skipped-gate — prompt-gate.sh reads this next turn
  echo "$NOW:$REASON" > /tmp/skipped-gate
fi

exit 0

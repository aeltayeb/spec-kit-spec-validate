#!/usr/bin/env bats
# Integration test: review timeout scenarios
# Tests 24h SLA timeout, self-approval, and gate behavior after timeout

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
GATE_SCRIPT="$SCRIPT_DIR/check-gate.sh"
WRITE_SCRIPT="$SCRIPT_DIR/write-approval-state.sh"
READ_SCRIPT="$SCRIPT_DIR/read-approval-state.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export SPEC_VALIDATE_STATE_DIR="$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset SPEC_VALIDATE_STATE_DIR
}

@test "timed-out review with self-approval returns allowed-with-warning" {
  local state='{"feature":"timeout-test","spec_hash":"sha256:abc","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"timed-out","review_requested_at":"2026-04-15T10:00:00Z","approval_status":"allowed-with-warning","warnings":["Review timed out after 24h SLA"],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":true,"reason":"Reviewer unavailable, changes are low-risk"}}'
  bash "$WRITE_SCRIPT" "timeout-test" "$state"

  run bash "$GATE_SCRIPT" "timeout-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"allowed-with-warning"'
}

@test "timed-out review without self-approval reason returns blocked" {
  local state='{"feature":"no-reason","spec_hash":"sha256:abc","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"timed-out","review_requested_at":"2026-04-15T10:00:00Z","approval_status":"blocked","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'
  bash "$WRITE_SCRIPT" "no-reason" "$state"

  run bash "$GATE_SCRIPT" "no-reason"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"blocked"'
}

@test "gate returns allowed after timeout self-approval updates state" {
  # Simulate: review timed out, author self-approved
  local state='{"feature":"approved-timeout","spec_hash":"sha256:def","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"timed-out","approval_status":"allowed-with-warning","warnings":["Review timed out"],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":true,"reason":"Proceeded after 24h with no reviewer response"}}'
  bash "$WRITE_SCRIPT" "approved-timeout" "$state"

  run bash "$GATE_SCRIPT" "approved-timeout"
  [ "$status" -eq 0 ]
  # Should be allowed-with-warning, not blocked
  echo "$output" | grep -qv '"blocked"'
}

@test "pending review (SLA not expired) remains blocked" {
  local state='{"feature":"pending-review","spec_hash":"sha256:ghi","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"pending","review_requested_at":"2026-04-16T10:00:00Z","approval_status":"blocked","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'
  bash "$WRITE_SCRIPT" "pending-review" "$state"

  run bash "$GATE_SCRIPT" "pending-review"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"blocked"'
  echo "$output" | grep -q '"pending"'
}

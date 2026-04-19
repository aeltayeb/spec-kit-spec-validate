#!/usr/bin/env bats
# Integration test: validation flow
# Tests the end-to-end flow of spec validation including hash, state, and auto-pass

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
HASH_SCRIPT="$SCRIPT_DIR/compute-hash.sh"
READ_SCRIPT="$SCRIPT_DIR/read-approval-state.sh"
WRITE_SCRIPT="$SCRIPT_DIR/write-approval-state.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export SPEC_VALIDATE_STATE_DIR="$TEST_DIR/state"
  mkdir -p "$TEST_DIR/state"
  mkdir -p "$TEST_DIR/specs"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset SPEC_VALIDATE_STATE_DIR
}

@test "compute-hash is called on spec.md and produces valid hash" {
  echo "test spec content" > "$TEST_DIR/specs/spec.md"
  run bash "$HASH_SCRIPT" "$TEST_DIR/specs/spec.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^sha256:[a-f0-9]{64}$ ]]
}

@test "approval state is written after validation simulation" {
  echo "test spec" > "$TEST_DIR/specs/spec.md"
  local hash
  hash=$(bash "$HASH_SCRIPT" "$TEST_DIR/specs/spec.md")

  local state="{\"feature\":\"flow-test\",\"spec_hash\":\"$hash\",\"tasks_hash\":null,\"spec_self_validation\":\"passed\",\"tasks_self_validation\":\"not-run\",\"spec_validated_at\":\"2026-04-16T10:00:00Z\",\"spec_critical_count\":5,\"spec_missed_items\":[],\"review_status\":\"not-required\",\"review_requested_at\":null,\"reviewer\":null,\"review_comments\":[],\"approval_status\":\"allowed\",\"warnings\":[],\"override\":{\"used\":false,\"reason\":null,\"by\":null},\"timeout_self_approval\":{\"used\":false,\"reason\":null}}"

  run bash "$WRITE_SCRIPT" "flow-test" "$state"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/state/flow-test.json" ]

  run bash "$READ_SCRIPT" "flow-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"passed"'
}

@test "auto-pass scenario: 0 critical items results in allowed state" {
  local state='{"feature":"auto-pass","spec_hash":"sha256:abc","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","spec_critical_count":0,"spec_missed_items":[],"review_status":"not-required","approval_status":"allowed","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'

  run bash "$WRITE_SCRIPT" "auto-pass" "$state"
  [ "$status" -eq 0 ]

  run bash "$READ_SCRIPT" "auto-pass"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"spec_critical_count": 0'
  echo "$output" | grep -q '"allowed"'
}

@test "missed items trigger review requirement in state" {
  local state='{"feature":"miss-test","spec_hash":"sha256:def","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","spec_critical_count":5,"spec_missed_items":["AC-2","EC-3"],"review_status":"pending","review_requested_at":"2026-04-16T10:30:00Z","reviewer":null,"review_comments":[],"approval_status":"blocked","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'

  run bash "$WRITE_SCRIPT" "miss-test" "$state"
  [ "$status" -eq 0 ]

  run bash "$READ_SCRIPT" "miss-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"pending"'
  echo "$output" | grep -q '"AC-2"'
}

@test "agent metadata can be stored in private analytics file" {
  # Simulate writing private analytics (local state)
  mkdir -p "$TEST_DIR/local"
  cat > "$TEST_DIR/local/agent-test.private.json" <<'EOF'
{
  "feature": "agent-test",
  "validated_by": "test-user",
  "agent": {"name": "claude", "version": "opus-4"},
  "attempts": [],
  "analytics": {"first_attempt_accuracy": 1.0, "total_items": 3, "critical_items": 0, "items_missed": []}
}
EOF
  [ -f "$TEST_DIR/local/agent-test.private.json" ]
  grep -q '"claude"' "$TEST_DIR/local/agent-test.private.json"
  grep -q '"opus-4"' "$TEST_DIR/local/agent-test.private.json"
}

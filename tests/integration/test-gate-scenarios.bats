#!/usr/bin/env bats
# Integration test: gate scenarios
# Tests end-to-end gate behavior with various approval states

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
GATE_SCRIPT="$SCRIPT_DIR/check-gate.sh"
WRITE_SCRIPT="$SCRIPT_DIR/write-approval-state.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export SPEC_VALIDATE_STATE_DIR="$TEST_DIR"
  export SPEC_VALIDATE_SPEC_DIR="$TEST_DIR/specs"
  mkdir -p "$TEST_DIR/specs"
  echo "test spec content" > "$TEST_DIR/specs/spec.md"
  echo "test tasks content" > "$TEST_DIR/specs/tasks.md"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset SPEC_VALIDATE_STATE_DIR
  unset SPEC_VALIDATE_SPEC_DIR
}

@test "gate returns blocked when no state exists" {
  run bash "$GATE_SCRIPT" "no-state-feature"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"outcome"'
  echo "$output" | grep -q '"blocked"'
}

@test "gate returns allowed when validated and no review needed" {
  # Compute actual hash of test spec
  local spec_hash
  if command -v sha256sum >/dev/null 2>&1; then
    spec_hash="sha256:$(sha256sum "$TEST_DIR/specs/spec.md" | awk '{print $1}')"
  else
    spec_hash="sha256:$(shasum -a 256 "$TEST_DIR/specs/spec.md" | awk '{print $1}')"
  fi

  local state="{\"feature\":\"gate-test\",\"spec_hash\":\"$spec_hash\",\"tasks_hash\":null,\"spec_self_validation\":\"passed\",\"tasks_self_validation\":\"not-run\",\"review_status\":\"not-required\",\"approval_status\":\"allowed\",\"warnings\":[],\"override\":{\"used\":false,\"reason\":null,\"by\":null},\"timeout_self_approval\":{\"used\":false,\"reason\":null}}"
  bash "$WRITE_SCRIPT" "gate-test" "$state"

  run bash "$GATE_SCRIPT" "gate-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"allowed"'
}

@test "gate detects stale validation when hash mismatches" {
  local state='{"feature":"stale-test","spec_hash":"sha256:old_hash_value","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"not-required","approval_status":"allowed","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'
  bash "$WRITE_SCRIPT" "stale-test" "$state"

  run bash "$GATE_SCRIPT" "stale-test"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"blocked"\|"stale"'
}

@test "gate allows when stale but review is approved" {
  local state='{"feature":"stale-approved","spec_hash":"sha256:old_hash","tasks_hash":null,"spec_self_validation":"stale","tasks_self_validation":"not-run","review_status":"approved","approval_status":"allowed","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'
  bash "$WRITE_SCRIPT" "stale-approved" "$state"

  run bash "$GATE_SCRIPT" "stale-approved"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"allowed"'
}

@test "gate blocks when reviewer requested changes" {
  local state='{"feature":"changes-req","spec_hash":"sha256:some_hash","tasks_hash":null,"spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"changes-requested","approval_status":"blocked","warnings":[],"override":{"used":false,"reason":null,"by":null},"timeout_self_approval":{"used":false,"reason":null}}'
  bash "$WRITE_SCRIPT" "changes-req" "$state"

  run bash "$GATE_SCRIPT" "changes-req"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"blocked"'
}

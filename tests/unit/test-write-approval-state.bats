#!/usr/bin/env bats
# Unit test: write-approval-state script

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
SCRIPT="$SCRIPT_DIR/write-approval-state.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export SPEC_VALIDATE_STATE_DIR="$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset SPEC_VALIDATE_STATE_DIR
}

@test "writes valid JSON to state file" {
  local json='{"feature":"test","spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"not-required","approval_status":"allowed"}'
  run bash "$SCRIPT" "test" "$json"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/test.json" ]
  grep -q '"passed"' "$TEST_DIR/test.json"
}

@test "overwrites existing state file" {
  local json1='{"feature":"test","spec_self_validation":"not-run","tasks_self_validation":"not-run","review_status":"not-required","approval_status":"blocked"}'
  local json2='{"feature":"test","spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"not-required","approval_status":"allowed"}'
  bash "$SCRIPT" "test" "$json1"
  run bash "$SCRIPT" "test" "$json2"
  [ "$status" -eq 0 ]
  grep -q '"passed"' "$TEST_DIR/test.json"
  ! grep -q '"blocked"' "$TEST_DIR/test.json"
}

@test "creates parent directories if missing" {
  rm -rf "$TEST_DIR"
  local json='{"feature":"test","spec_self_validation":"passed","tasks_self_validation":"not-run","review_status":"not-required","approval_status":"allowed"}'
  run bash "$SCRIPT" "test" "$json"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/test.json" ]
}

@test "exits non-zero when called with no arguments" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "exits non-zero for missing JSON argument" {
  run bash "$SCRIPT" "test"
  [ "$status" -ne 0 ]
}

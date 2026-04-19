#!/usr/bin/env bats
# Unit test: read-approval-state script

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
SCRIPT="$SCRIPT_DIR/read-approval-state.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export SPEC_VALIDATE_STATE_DIR="$TEST_DIR"
  mkdir -p "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset SPEC_VALIDATE_STATE_DIR
}

@test "returns default state JSON when file is missing" {
  run bash "$SCRIPT" "nonexistent-feature"
  [ "$status" -eq 0 ]
  # Verify it contains required fields
  echo "$output" | grep -q '"feature"'
  echo "$output" | grep -q '"spec_self_validation"'
  echo "$output" | grep -q '"not-run"'
  echo "$output" | grep -q '"approval_status"'
  echo "$output" | grep -q '"blocked"'
}

@test "reads valid JSON from existing state file" {
  mkdir -p "$TEST_DIR"
  cat > "$TEST_DIR/test-feature.json" <<'EOF'
{
  "feature": "test-feature",
  "spec_hash": "sha256:abc123",
  "tasks_hash": null,
  "spec_self_validation": "passed",
  "tasks_self_validation": "not-run",
  "review_status": "not-required",
  "approval_status": "allowed",
  "warnings": [],
  "override": {"used": false, "reason": null, "by": null},
  "timeout_self_approval": {"used": false, "reason": null}
}
EOF
  run bash "$SCRIPT" "test-feature"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"passed"'
  echo "$output" | grep -q '"allowed"'
}

@test "exits non-zero for malformed JSON" {
  mkdir -p "$TEST_DIR"
  echo "this is not json {{{" > "$TEST_DIR/bad-feature.json"
  run bash "$SCRIPT" "bad-feature"
  [ "$status" -eq 1 ]
}

@test "exits non-zero when called with no arguments" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

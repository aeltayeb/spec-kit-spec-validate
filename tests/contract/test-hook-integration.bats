#!/usr/bin/env bats
# Contract test: compute-hash script hook integration
# Verifies the compute-hash script conforms to the expected interface

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
SCRIPT="$SCRIPT_DIR/compute-hash.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  echo "known content for hashing" > "$TEST_DIR/test-file.md"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "compute-hash accepts a file path and outputs sha256:<hash>" {
  run bash "$SCRIPT" "$TEST_DIR/test-file.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^sha256:[a-f0-9]{64}$ ]]
}

@test "compute-hash exits non-zero for missing file" {
  run bash "$SCRIPT" "$TEST_DIR/nonexistent-file.md"
  [ "$status" -ne 0 ]
}

@test "compute-hash exits non-zero for empty path argument" {
  run bash "$SCRIPT" ""
  [ "$status" -ne 0 ]
}

@test "compute-hash exits non-zero when called with no arguments" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "compute-hash produces consistent output for same content" {
  run bash "$SCRIPT" "$TEST_DIR/test-file.md"
  local first_hash="$output"
  run bash "$SCRIPT" "$TEST_DIR/test-file.md"
  [ "$output" = "$first_hash" ]
}

@test "compute-hash produces different output for different content" {
  echo "different content" > "$TEST_DIR/other-file.md"
  run bash "$SCRIPT" "$TEST_DIR/test-file.md"
  local hash1="$output"
  run bash "$SCRIPT" "$TEST_DIR/other-file.md"
  [ "$output" != "$hash1" ]
}

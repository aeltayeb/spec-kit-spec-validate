#!/usr/bin/env bats
# Unit test: compute-hash script

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
SCRIPT="$SCRIPT_DIR/compute-hash.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  # Create file with known content — hash is deterministic
  printf "hello world" > "$TEST_DIR/known.txt"
  # Known SHA-256 of "hello world" (no newline):
  # b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
  KNOWN_HASH="sha256:b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "hash of known content matches expected SHA-256" {
  run bash "$SCRIPT" "$TEST_DIR/known.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "$KNOWN_HASH" ]
}

@test "missing file returns non-zero exit code" {
  run bash "$SCRIPT" "$TEST_DIR/does-not-exist.txt"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error" ]] || [[ "$output" =~ "error" ]]
}

@test "empty file produces valid hash" {
  touch "$TEST_DIR/empty.txt"
  run bash "$SCRIPT" "$TEST_DIR/empty.txt"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^sha256:[a-f0-9]{64}$ ]]
}

@test "error message is helpful for missing file" {
  run bash "$SCRIPT" "/nonexistent/path/file.md"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]] || [[ "$output" =~ "does not exist" ]] || [[ "$output" =~ "No such file" ]]
}

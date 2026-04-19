#!/usr/bin/env bats
# Contract test: state schema validation
# Verifies default state matches Contract 1 schema

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/bash" && pwd)"
READ_SCRIPT="$SCRIPT_DIR/read-approval-state.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export SPEC_VALIDATE_STATE_DIR="$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset SPEC_VALIDATE_STATE_DIR
}

@test "default state contains all required fields" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"feature"'
  echo "$output" | grep -q '"spec_self_validation"'
  echo "$output" | grep -q '"tasks_self_validation"'
  echo "$output" | grep -q '"review_status"'
  echo "$output" | grep -q '"approval_status"'
}

@test "default spec_self_validation is not-run" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"spec_self_validation": "not-run"'
}

@test "default tasks_self_validation is not-run" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"tasks_self_validation": "not-run"'
}

@test "default approval_status is blocked" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"approval_status": "blocked"'
}

@test "default review_status is not-required" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"review_status": "not-required"'
}

@test "default override.used is false" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"used": false'
}

@test "default state has empty warnings array" {
  run bash "$READ_SCRIPT" "schema-test"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"warnings": \[\]'
}

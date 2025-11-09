#!/bin/bash

setUp() {
  VTOG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  export PATH="$VTOG_ROOT:$PATH"
}

# Tests for input

function test_when_input_doesnt_exists_then_exit_with_error() {
  actual_error="$(vtog.sh -i=nonexisting.mov -o=out.gif --ws=frames --fps=1 --quality=65-80 --maxthreads=32 2>&1)"
  expected="$(echo -e "\033[31mInput file=[nonexisting.mov] does not exists, nothing to do, exiting.\033[0m")"
  assertEquals "$expected" "$actual_error"
}

function test_when_input_is_empty_then_exit_with_error() {
  actual_error="$(vtog.sh -i=empty.mov -o=out.gif --ws=frames --fps=1 --quality=65-80 --maxthreads=32 2>&1)"
  actual_error="$(echo "$actual_error" | sed -n '$p')"
  expected="$(echo -e "\033[31mNo frames found. Nothing extracted from file input=[empty.mov], nothing to do, exiting.\033[0m")"
  assertEquals "$expected" "$actual_error"
}

# Tests for help

function test_when_no_args_passed_then_help_shout_be_printed() {
  help_content="$(vtog.sh)"
  expected="$(cat help.snapshot.txt)"
  assertEquals "$expected" "$help_content"
}

function test_when_help_arg_passed_then_help_shout_be_printed() {
  help_content="$(vtog.sh --help)"
  expected="$(cat help.snapshot.txt)"
  assertEquals "$expected" "$help_content"
}

# Tests for mandatory variables

function test_when_output_empty_then_exit_with_error() {
  actual_error="$(vtog.sh --input=./test.mov --output='' -o='' 2>&1)"
  actual_error="$(echo "$actual_error" | sed -n '$p')"
  expected="$(echo -e "\033[31mVariable=[output] cannot have empty value, did you override it's value?\033[0m")"
  assertEquals "$expected" "$actual_error"
}

function test_when_ws_empty_then_exit_with_error() {
  actual_error="$(vtog.sh --input=./test.mov --ws='' 2>&1)"
  actual_error="$(echo "$actual_error" | sed -n '$p')"
  expected="$(echo -e "\033[31mVariable=[ws] cannot have empty value, did you override it's value?\033[0m")"
  assertEquals "$expected" "$actual_error"
}

function test_when_fps_empty_then_exit_with_error() {
  actual_error="$(vtog.sh --input=./test.mov --fps='' 2>&1)"
  actual_error="$(echo "$actual_error" | sed -n '$p')"
  expected="$(echo -e "\033[31mVariable=[fps] cannot have empty value, did you override it's value?\033[0m")"
  assertEquals "$expected" "$actual_error"
}

function test_when_maxthreads_empty_then_exit_with_error() {
  actual_error="$(vtog.sh --input=./test.mov --maxthreads='' 2>&1)"
  actual_error="$(echo "$actual_error" | sed -n '$p')"
  expected="$(echo -e "\033[31mVariable=[maxthreads] cannot have empty value, did you override it's value?\033[0m")"
  assertEquals "$expected" "$actual_error"
}

# Tests for results in general

function test_when_input_processed_then_first_frame_should_exists_and_match_hash_original_variant() {
  vtog.sh --input=./test.mov --maxthreads='32' --autocleanup=false >/dev/null 2>&1
  first_frame_path="$(ls -1 frames/*.png | head -n 1)"
  magick $first_frame_path -strip $first_frame_path
  actual_hash="$(sha512sum "$first_frame_path" | awk '{ print $1 }')"
  expected="$(cat ./test_frame_1024x778.sha.txt)"
  assertEquals "$expected" "$actual_hash"
  rm -rf frames
}

function test_when_input_processed_then_first_frame_should_exists_and_match_hash_small_variant() {
  vtog.sh --input=./test.mov --width=640 --maxthreads='32' --autocleanup=false >/dev/null 2>&1
  first_frame_path="$(ls -1 frames/*.png | head -n 1)"
  magick $first_frame_path -strip $first_frame_path
  actual_hash="$(sha512sum "$first_frame_path" | awk '{ print $1 }')"
  expected="$(cat ./test_frame_640x490.sha.txt)"
  assertEquals "$expected" "$actual_hash"
  rm -rf frames
}

# Tests for sending signals to main script

function test_trap_should_work_SIGINT_sent() {
  LOG_FILE=$(mktemp)
  vtog.sh -i=./test.mov -o=out.gif --ws=frames --fps=1 --quality=65-80 --maxthreads=32 >$LOG_FILE 2>&1 &
  PID=$!
  ps >/dev/null 2>&1
  kill $PID
  wait "$PID"
  expected="$(echo -e "\033[93mCleaning up...\033[0m")"
  assertEquals "$expected" "$(tail -n 1 "$LOG_FILE")"
  rm $LOG_FILE
  rm -rf frames
}

. ../shunit2/shunit2

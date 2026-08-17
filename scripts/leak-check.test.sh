#!/bin/bash
# Tests for leak-check.sh. Run directly: ./scripts/leak-check.test.sh
#
# Covers the checks that run before anything is launched. The measurement itself
# needs a built app, a window server and about a minute, so it is not run here -
# what is tested is that a mistake in the arguments stops the script rather than
# producing a run that reports nothing and passes.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check="$script_dir/leak-check.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# An app bundle that is shaped right and cannot run, for the checks that happen
# after the bundle is accepted.
stub_app="$work/Stub.app"
mkdir -p "$stub_app/Contents/MacOS"
printf '#!/bin/sh\nexit 0\n' >"$stub_app/Contents/MacOS/Front Row"
chmod +x "$stub_app/Contents/MacOS/Front Row"

expect_failure() {
  local description="$1"
  shift
  local output
  output="$("$check" "$@" 2>&1)"
  if (($? == 0)); then
    echo "FAIL     $description: expected a non-zero exit"
    failures=$((failures + 1))
  elif [[ "$output" != *"leak-check:"* ]]; then
    echo "FAIL     $description: exited non-zero without saying why"
    echo "         got: $output"
    failures=$((failures + 1))
  else
    echo "ok       $description"
  fi
}

expect_help() {
  local output
  output="$("$check" "$1" 2>&1)"
  if (($? != 0)); then
    echo "FAIL     $1 exited non-zero"
    failures=$((failures + 1))
  elif [[ "$output" != *"leak-check.sh"* ]]; then
    echo "FAIL     $1 printed no usage"
    failures=$((failures + 1))
  else
    echo "ok       $1 prints usage"
  fi
}

expect_help -h
expect_help --help

expect_failure "rejects an unknown option" --wibble
expect_failure "rejects a zero cycle count" --cycles 0
expect_failure "rejects a non-numeric cycle count" --cycles many
expect_failure "rejects a missing cycle count" --cycles
expect_failure "rejects a negative cycle count" --cycles -3
expect_failure "rejects a non-numeric tolerance" --tolerance loose
expect_failure "rejects a missing app path" --app

expect_failure "rejects an app bundle that is not there" --app "$work/Nope.app"

# A directory named like a bundle but with nothing to run inside it would
# otherwise launch nothing and measure nothing.
mkdir -p "$work/Hollow.app/Contents/MacOS"
expect_failure "rejects a bundle with no executable" --app "$work/Hollow.app"

expect_failure "rejects a media file that is not there" \
  --app "$stub_app" "$work/absent.mp4"

echo
if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"

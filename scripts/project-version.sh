#!/bin/bash
# Reads and writes the version settings in project.pbxproj.
#
#   project-version.sh read-marketing "Front Row.xcodeproj/project.pbxproj"
#   project-version.sh read-build     "Front Row.xcodeproj/project.pbxproj"
#   project-version.sh write          "Front Row.xcodeproj/project.pbxproj" 2.11.0 206
#
# MARKETING_VERSION and CURRENT_PROJECT_VERSION both live at the project level,
# so each appears exactly twice — once per configuration. Anything else means
# the project no longer matches what this assumes, and writing would be a guess.
#
# agvtool is not used: its marketing-version commands fail on this project
# because the test target has no INFOPLIST_FILE, so agvtool falls back to
# reading GENERATE_INFOPLIST_FILE = YES as a file path.

set -euo pipefail

readonly EXPECTED_OCCURRENCES=2

die() {
  echo "project-version: $1" >&2
  exit 1
}

read_setting() {
  local pbxproj="$1" setting="$2"
  [[ -f "$pbxproj" ]] || die "project file not found: $pbxproj"

  local values
  values="$(sed -n "s/^[[:space:]]*$setting = \(.*\);$/\1/p" "$pbxproj" | sort -u)"
  [[ -n "$values" ]] || die "$setting not found in $pbxproj"
  [[ "$(wc -l <<<"$values")" -eq 1 ]] ||
    die "$setting has conflicting values in $pbxproj: $(tr '\n' ' ' <<<"$values")"

  echo "$values"
}

command="${1-}"
pbxproj="${2-}"

case "$command" in
  read-marketing)
    read_setting "$pbxproj" MARKETING_VERSION
    ;;

  read-build)
    read_setting "$pbxproj" CURRENT_PROJECT_VERSION
    ;;

  write)
    marketing="${3-}"
    build="${4-}"

    [[ -f "$pbxproj" ]] || die "project file not found: $pbxproj"
    [[ "$marketing" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
      die "marketing version must be X.Y.Z, got '$marketing'"
    [[ "$build" =~ ^[0-9]+$ ]] || die "build number must be a whole number, got '$build'"

    for setting in MARKETING_VERSION CURRENT_PROJECT_VERSION; do
      count="$(grep -c "^[[:space:]]*$setting = .*;$" "$pbxproj" || true)"
      (( count == EXPECTED_OCCURRENCES )) ||
        die "expected $EXPECTED_OCCURRENCES occurrences of $setting, found $count — the project layout changed"
    done

    # Write to a temp file and move into place so a failure cannot leave a
    # half-rewritten project.
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    sed -e "s/^\([[:space:]]*\)MARKETING_VERSION = .*;$/\1MARKETING_VERSION = $marketing;/" \
      -e "s/^\([[:space:]]*\)CURRENT_PROJECT_VERSION = .*;$/\1CURRENT_PROJECT_VERSION = $build;/" \
      "$pbxproj" >"$tmp"

    mv "$tmp" "$pbxproj"
    trap - EXIT

    echo "Set $pbxproj to $marketing ($build)"
    ;;

  "")
    die "a command is required (read-marketing, read-build, or write)"
    ;;

  *)
    die "unknown command '$command'"
    ;;
esac

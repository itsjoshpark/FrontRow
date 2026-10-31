#!/bin/bash
# Reads and writes the version settings in project.xcproj.
#
#   project-version.sh read-marketing "Front Row.xcodeproj/project.xcproj"
#   project-version.sh read-build     "Front Row.xcodeproj/project.xcproj"
#   project-version.sh write          "Front Row.xcodeproj/project.xcproj" 2.11.0 206
#
# project.xcproj is Xcode's JSON project format, in its canonical layout
# (xcprojformatter): project-level settings sit in the top-level
# "build-settings" object, one per line at four spaces of indentation.
# MARKETING_VERSION and CURRENT_PROJECT_VERSION both live there, shared by every
# configuration, so each appears exactly once, with no per-configuration
# ("KEY[config=...]") or per-target override. Anything else means the project
# no longer matches what this assumes, and writing would be a guess.

set -euo pipefail

die() {
  echo "project-version: $1" >&2
  exit 1
}

# Every mention of the setting as a key, at any level or with any condition.
count_keys() {
  grep -c "\"$2[\"[]" "$1" || true
}

# The setting as a plain project-level key: four spaces, then "KEY": "value",
project_line() {
  printf '^    "%s": "\\(.*\\)",$' "$1"
}

read_setting() {
  local project="$1" setting="$2"
  [[ -f "$project" ]] || die "project file not found: $project"

  local count
  count="$(count_keys "$project" "$setting")"
  (( count > 0 )) || die "$setting not found in $project"
  (( count == 1 )) ||
    die "$setting is set $count times in $project; expected one project-level value"

  local value
  value="$(sed -n "s/$(project_line "$setting")/\1/p" "$project")"
  [[ -n "$value" ]] || die "$setting in $project is not a project-level setting"

  echo "$value"
}

command="${1-}"
project="${2-}"

case "$command" in
  read-marketing)
    read_setting "$project" MARKETING_VERSION
    ;;

  read-build)
    read_setting "$project" CURRENT_PROJECT_VERSION
    ;;

  write)
    marketing="${3-}"
    build="${4-}"

    [[ -f "$project" ]] || die "project file not found: $project"
    [[ "$marketing" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
      die "marketing version must be X.Y.Z, got '$marketing'"
    [[ "$build" =~ ^[0-9]+$ ]] || die "build number must be a whole number, got '$build'"

    # Reading validates the layout: one project-level value for each setting.
    read_setting "$project" MARKETING_VERSION >/dev/null
    read_setting "$project" CURRENT_PROJECT_VERSION >/dev/null

    # Write to a temp file and move into place so a failure cannot leave a
    # half-rewritten project.
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    sed -e "s/$(project_line MARKETING_VERSION)/    \"MARKETING_VERSION\": \"$marketing\",/" \
      -e "s/$(project_line CURRENT_PROJECT_VERSION)/    \"CURRENT_PROJECT_VERSION\": \"$build\",/" \
      "$project" >"$tmp"

    mv "$tmp" "$project"
    trap - EXIT

    echo "Set $project to $marketing ($build)"
    ;;

  "")
    die "a command is required (read-marketing, read-build, or write)"
    ;;

  *)
    die "unknown command '$command'"
    ;;
esac

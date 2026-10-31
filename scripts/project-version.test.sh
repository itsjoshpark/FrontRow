#!/bin/bash
# Tests for project-version.sh. Run directly: ./scripts/project-version.test.sh

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$script_dir/project-version.sh"

failures=0
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

check() {
  if [[ "$2" == "pass" ]]; then
    echo "ok       $1"
  else
    echo "FAIL     $1"
    failures=$((failures + 1))
  fi
}

expect_equal() {
  local got="$1" want="$2" description="$3"
  if [[ "$got" == "$want" ]]; then
    check "$description" pass
  else
    check "$description (got '$got', want '$want')" fail
  fi
}

# Mirrors the real layout: both settings once, at project level, between
# per-configuration and per-target settings that must be left alone.
make_project() {
  cat >"$1" <<'XCPROJ'
{
  "default-configuration": "Release",
  "targets": [
    {
      "name": "App",
      "build-settings": {
        "PRODUCT_NAME": "$(TARGET_NAME)",
      },
    },
  ],
  "build-settings": {
    "COPY_PHASE_STRIP": "NO",
    "CURRENT_PROJECT_VERSION": "24",
    "DEAD_CODE_STRIPPING": "YES",
    "DEBUG_INFORMATION_FORMAT[config=Debug]": "dwarf",
    "MARKETING_VERSION": "2.10",
    "SDKROOT": "macosx",
  },
}
XCPROJ
}

project="$workdir/project.xcproj"
make_project "$project"

# --- read -------------------------------------------------------------------
expect_equal "$("$tool" read-marketing "$project")" "2.10" "reads the marketing version"
expect_equal "$("$tool" read-build "$project")" "24" "reads the build number"

# --- write ------------------------------------------------------------------
if "$tool" write "$project" 2.11.0 206 >/dev/null 2>&1; then
  check "exits zero on write" pass
else
  check "exits zero on write" fail
fi

expect_equal "$("$tool" read-marketing "$project")" "2.11.0" "writes the marketing version"
expect_equal "$("$tool" read-build "$project")" "206" "writes the build number"
expect_equal "$(grep -c '^    "MARKETING_VERSION": "2.11.0",$' "$project")" "1" "writes the marketing version in place"
expect_equal "$(grep -c '^    "CURRENT_PROJECT_VERSION": "206",$' "$project")" "1" "writes the build number in place"
make_project "$workdir/expected.xcproj"
expect_equal "$(diff "$workdir/expected.xcproj" "$project" | grep -c '^[<>]')" "4" "changes only the two version lines"

# --- guards -----------------------------------------------------------------
missing="$workdir/nope.xcproj"
if "$tool" read-marketing "$missing" >/dev/null 2>&1; then
  check "rejects a missing project file" fail
else
  check "rejects a missing project file" pass
fi

# A project whose settings are not where we expect must fail loudly rather than
# silently write nothing.
empty="$workdir/empty.xcproj"
printf '{\n}\n' >"$empty"
if "$tool" read-marketing "$empty" >/dev/null 2>&1; then
  check "rejects a project with no marketing version" fail
else
  check "rejects a project with no marketing version" pass
fi
if "$tool" write "$empty" 2.11.0 206 >/dev/null 2>&1; then
  check "refuses to write when settings are absent" fail
else
  check "refuses to write when settings are absent" pass
fi

# An override anywhere else means the project no longer matches the assumed
# layout: a per-configuration value, or a per-target one.
overridden="$workdir/overridden.xcproj"
for override in '"MARKETING_VERSION[config=Debug]": "2.9",' '"MARKETING_VERSION": "2.9",'; do
  make_project "$overridden"
  awk -v line="        $override" '{ print } /"PRODUCT_NAME"/ { print line }' "$overridden" >"$overridden.tmp"
  mv "$overridden.tmp" "$overridden"
  [[ "$(grep -c 'MARKETING_VERSION' "$overridden")" == "2" ]] ||
    { echo "FAIL     test fixture is wrong: overridden project should have 2 MARKETING_VERSION"; failures=$((failures + 1)); }
  if "$tool" write "$overridden" 2.11.0 206 >/dev/null 2>&1; then
    check "refuses to write with override $override" fail
  else
    check "refuses to write with override $override" pass
  fi
done

# A setting that is only set per target is not a project-level setting.
targetonly="$workdir/targetonly.xcproj"
make_project "$targetonly"
awk '!/^    "MARKETING_VERSION"/ { print } /"PRODUCT_NAME"/ { print "        \"MARKETING_VERSION\": \"2.9\"," }' "$targetonly" >"$targetonly.tmp"
mv "$targetonly.tmp" "$targetonly"
if "$tool" read-marketing "$targetonly" >/dev/null 2>&1; then
  check "rejects a marketing version set only on a target" fail
else
  check "rejects a marketing version set only on a target" pass
fi

# Reject values that would corrupt the project file or produce a bad version.
make_project "$project"
for bad in "" "2.11.0;" "2.11.0 extra" "not a version"; do
  if "$tool" write "$project" "$bad" 206 >/dev/null 2>&1; then
    check "rejects marketing version '$bad'" fail
  else
    check "rejects marketing version '$bad'" pass
  fi
done
for bad in "" "abc" "20.6" "-1"; do
  if "$tool" write "$project" 2.11.0 "$bad" >/dev/null 2>&1; then
    check "rejects build number '$bad'" fail
  else
    check "rejects build number '$bad'" pass
  fi
done

# Nothing above should have modified the file.
expect_equal "$("$tool" read-marketing "$project")" "2.10" "leaves the project untouched when validation fails"

# The real project, which is what a release reads. Both settings must stay
# unambiguous across every target for the release to work out the next version.
real="$script_dir/../Front Row.xcodeproj/project.xcproj"
for command in read-marketing read-build; do
  if "$tool" "$command" "$real" >/dev/null 2>&1; then
    check "$command answers for the real project" pass
  else
    check "$command answers for the real project" fail
  fi
done

echo
if (( failures > 0 )); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"

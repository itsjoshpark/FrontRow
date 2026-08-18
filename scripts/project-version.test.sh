#!/bin/bash
# Tests for project-version.sh. Run directly: ./scripts/project-version.test.sh

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$script_dir/project-version.sh"

# What project-version.sh itself expects: one value per build configuration.
readonly EXPECTED_OCCURRENCES=2

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

# Mirrors the real layout: both settings at project level, in two configurations.
make_pbxproj() {
  cat >"$1" <<'PBX'
// !$*UTF8*$!
{
	objects = {
		AAAA /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				COPY_PHASE_STRIP = NO;
				CURRENT_PROJECT_VERSION = 24;
				MARKETING_VERSION = 2.10;
				DEAD_CODE_STRIPPING = YES;
			};
			name = Debug;
		};
		BBBB /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				COPY_PHASE_STRIP = NO;
				CURRENT_PROJECT_VERSION = 24;
				MARKETING_VERSION = 2.10;
				DEAD_CODE_STRIPPING = YES;
			};
			name = Release;
		};
	};
}
PBX
}

pbx="$workdir/project.pbxproj"
make_pbxproj "$pbx"

# --- read -------------------------------------------------------------------
expect_equal "$("$tool" read-marketing "$pbx")" "2.10" "reads the marketing version"
expect_equal "$("$tool" read-build "$pbx")" "24" "reads the build number"

# --- write ------------------------------------------------------------------
if "$tool" write "$pbx" 2.11.0 206 >/dev/null 2>&1; then
  check "exits zero on write" pass
else
  check "exits zero on write" fail
fi

expect_equal "$("$tool" read-marketing "$pbx")" "2.11.0" "writes the marketing version"
expect_equal "$("$tool" read-build "$pbx")" "206" "writes the build number"
expect_equal "$(grep -c 'MARKETING_VERSION = 2.11.0;' "$pbx")" "2" "updates both configurations' marketing version"
expect_equal "$(grep -c 'CURRENT_PROJECT_VERSION = 206;' "$pbx")" "2" "updates both configurations' build number"
expect_equal "$(grep -c 'COPY_PHASE_STRIP' "$pbx")" "2" "leaves neighbouring settings alone"

# --- guards -----------------------------------------------------------------
missing="$workdir/nope.pbxproj"
if "$tool" read-marketing "$missing" >/dev/null 2>&1; then
  check "rejects a missing project file" fail
else
  check "rejects a missing project file" pass
fi

# A project whose settings are not where we expect must fail loudly rather than
# silently write nothing.
empty="$workdir/empty.pbxproj"
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

# One occurrence means the project no longer matches the assumed layout.
lopsided="$workdir/lopsided.pbxproj"
make_pbxproj "$lopsided"
# Delete only the first MARKETING_VERSION line. BSD sed has no 0,/re/ range.
awk '!done && /MARKETING_VERSION/ { done = 1; next } { print }' "$lopsided" >"$lopsided.tmp"
mv "$lopsided.tmp" "$lopsided"
[[ "$(grep -c 'MARKETING_VERSION' "$lopsided")" == "1" ]] ||
  { echo "FAIL     test fixture is wrong: lopsided project should have 1 MARKETING_VERSION"; failures=$((failures + 1)); }
if "$tool" write "$lopsided" 2.11.0 206 >/dev/null 2>&1; then
  check "refuses to write when occurrence count is unexpected" fail
else
  check "refuses to write when occurrence count is unexpected" pass
fi

# Reject values that would corrupt the project file or produce a bad version.
make_pbxproj "$pbx"
for bad in "" "2.11.0;" "2.11.0 extra" "not a version"; do
  if "$tool" write "$pbx" "$bad" 206 >/dev/null 2>&1; then
    check "rejects marketing version '$bad'" fail
  else
    check "rejects marketing version '$bad'" pass
  fi
done
for bad in "" "abc" "20.6" "-1"; do
  if "$tool" write "$pbx" 2.11.0 "$bad" >/dev/null 2>&1; then
    check "rejects build number '$bad'" fail
  else
    check "rejects build number '$bad'" pass
  fi
done

# Nothing above should have modified the file.
expect_equal "$("$tool" read-marketing "$pbx")" "2.10" "leaves the project untouched when validation fails"

# The real project, which is what a release reads. Xcode gives every new target
# its own MARKETING_VERSION and CURRENT_PROJECT_VERSION, and a second pair makes
# both settings ambiguous - the release then stops at the step that reads them.
real="$script_dir/../Front Row.xcodeproj/project.pbxproj"
for command in read-marketing read-build; do
  if "$tool" "$command" "$real" >/dev/null 2>&1; then
    check "$command answers for the real project" pass
  else
    check "$command answers for the real project" fail
  fi
done
for setting in MARKETING_VERSION CURRENT_PROJECT_VERSION; do
  expect_equal "$(grep -c "^[[:space:]]*$setting = .*;$" "$real")" "$EXPECTED_OCCURRENCES" \
    "the real project carries $setting once per configuration"
done

echo
if (( failures > 0 )); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"

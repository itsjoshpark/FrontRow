#!/bin/bash
# Tests for append-appcast-item.sh. Run directly: ./scripts/append-appcast-item.test.sh

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
append="$script_dir/append-appcast-item.sh"

failures=0
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

check() {
  local description="$1" condition="$2"
  if [[ "$condition" == "pass" ]]; then
    echo "ok       $description"
  else
    echo "FAIL     $description"
    failures=$((failures + 1))
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" description="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    check "$description" pass
  else
    check "$description" fail
  fi
}

make_appcast() {
  cat >"$1" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Front Row</title>
    <description>There's a new version available</description>
    <language>en</language>

    <item>
      <title>New Version Available</title>
      <sparkle:version>24</sparkle:version>
      <sparkle:shortVersionString>2.10 (24)</sparkle:shortVersionString>
      <description><![CDATA[
      <ul><li>Old news</li></ul>
      ]]>
      </description>
    </item>

  </channel>
</rss>
XML
}

run_append() {
  local appcast="$1" notes="$2"
  "$append" \
    --appcast "$appcast" \
    --version 2.11.0 \
    --build 206 \
    --url "https://example.com/FrontRow_v2.11.0.dmg" \
    --signature "SIGVALUE==" \
    --length 1234567 \
    --notes "$notes" \
    --pub-date "Fri, 07 Aug 2026 12:00:00 +0000" \
    --minimum-system-version 15.6
}

# --- happy path -------------------------------------------------------------
appcast="$workdir/appcast.xml"
notes="$workdir/notes.html"
make_appcast "$appcast"
printf '<ul>\n<li>Added: A thing</li>\n</ul>\n' >"$notes"

if run_append "$appcast" "$notes" >/dev/null 2>&1; then
  check "exits zero on valid input" pass
else
  check "exits zero on valid input" fail
fi

result="$(cat "$appcast")"
assert_contains "$result" "<sparkle:version>206</sparkle:version>" "writes the build number"
assert_contains "$result" "<sparkle:shortVersionString>2.11.0 (206)</sparkle:shortVersionString>" "keeps the 'X.Y.Z (build)' convention"
assert_contains "$result" 'sparkle:edSignature="SIGVALUE=="' "writes the signature"
assert_contains "$result" 'length="1234567"' "writes the length"
assert_contains "$result" "<li>Added: A thing</li>" "embeds the notes body"
assert_contains "$result" "<sparkle:minimumSystemVersion>15.6</sparkle:minimumSystemVersion>" "writes the minimum system version"
assert_contains "$result" "<li>Old news</li>" "preserves the existing entry's notes"

# The new item must come first so Sparkle sees the newest release at the top.
new_pos="$(grep -n "<sparkle:version>206" "$appcast" | cut -d: -f1)"
old_pos="$(grep -n "<sparkle:version>24<" "$appcast" | cut -d: -f1)"
if (( new_pos < old_pos )); then
  check "inserts the new item above older ones" pass
else
  check "inserts the new item above older ones" fail
fi

if [[ "$(grep -c "<item>" "$appcast")" == "2" ]]; then
  check "adds exactly one item" pass
else
  check "adds exactly one item" fail
fi

if head -1 "$appcast" | grep -q '<?xml version="1.0" standalone="yes"?>'; then
  check "leaves the XML declaration untouched" pass
else
  check "leaves the XML declaration untouched" fail
fi

if python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" "$appcast" 2>/dev/null; then
  check "produces well-formed XML" pass
else
  check "produces well-formed XML" fail
fi

# --- guards -----------------------------------------------------------------
appcast2="$workdir/appcast2.xml"
make_appcast "$appcast2"

if "$append" --appcast "$appcast2" --version 2.11.0 --build 206 \
  --url u --signature s --length 1 --notes "$workdir/missing.html" \
  --pub-date d --minimum-system-version 15.6 >/dev/null 2>&1; then
  check "rejects a missing notes file" fail
else
  check "rejects a missing notes file" pass
fi

# A build number that does not exceed the newest entry would strand existing users.
if "$append" --appcast "$appcast2" --version 2.11.0 --build 24 \
  --url u --signature s --length 1 --notes "$notes" \
  --pub-date d --minimum-system-version 15.6 >/dev/null 2>&1; then
  check "rejects a build number equal to the newest entry" fail
else
  check "rejects a build number equal to the newest entry" pass
fi

if "$append" --appcast "$appcast2" --version 2.11.0 --build 5 \
  --url u --signature s --length 1 --notes "$notes" \
  --pub-date d --minimum-system-version 15.6 >/dev/null 2>&1; then
  check "rejects a build number below the newest entry" fail
else
  check "rejects a build number below the newest entry" pass
fi

# Notes containing a CDATA terminator would break out of the section.
bad_notes="$workdir/bad.html"
printf '<ul><li>oops ]]> escaped</li></ul>\n' >"$bad_notes"
if "$append" --appcast "$appcast2" --version 2.11.0 --build 206 \
  --url u --signature s --length 1 --notes "$bad_notes" \
  --pub-date d --minimum-system-version 15.6 >/dev/null 2>&1; then
  check "rejects notes containing a CDATA terminator" fail
else
  check "rejects notes containing a CDATA terminator" pass
fi

# A fresh fixture per case, so a value that slips through cannot mutate the
# appcast and make later cases pass for the wrong reason.
reject() {
  local description="$1"; shift
  local target="$workdir/reject.xml"
  make_appcast "$target"
  if "$append" --appcast "$target" --notes "$notes" --pub-date d \
    --minimum-system-version 15.6 "$@" >/dev/null 2>&1; then
    check "$description" fail
  else
    check "$description" pass
  fi
}

reject "rejects a non-numeric length"      --version 2.11.0 --build 206 --url "https://e.com/a.dmg" --signature "S==" --length abc
reject "rejects a length with a quote"     --version 2.11.0 --build 206 --url "https://e.com/a.dmg" --signature "S==" --length '1" x="2'
reject "rejects an empty length"           --version 2.11.0 --build 206 --url "https://e.com/a.dmg" --signature "S==" --length ""
reject "rejects a malformed version"       --version "not.a.version" --build 206 --url "https://e.com/a.dmg" --signature "S==" --length 100
reject "rejects a version with markup"     --version '2.11.0</sparkle:shortVersionString>' --build 206 --url "https://e.com/a.dmg" --signature "S==" --length 100
reject "rejects a non-https url"           --version 2.11.0 --build 206 --url "javascript:alert(1)" --signature "S==" --length 100
reject "rejects a url with a quote"        --version 2.11.0 --build 206 --url 'https://e.com/a.dmg" onload="x' --signature "S==" --length 100
reject "rejects a non-base64 signature"    --version 2.11.0 --build 206 --url "https://e.com/a.dmg" --signature 'S" x="y' --length 100
reject "rejects a bad minimum system version" --version 2.11.0 --build 206 --url "https://e.com/a.dmg" --signature "S==" --length 100 --minimum-system-version "15.6<"
reject "rejects a pub date with markup"    --version 2.11.0 --build 206 --url "https://e.com/a.dmg" --signature "S==" --length 100 --pub-date 'Fri<script>'

# Two-part versions still work, for hand-running the recovery path on old entries.
appcast3="$workdir/appcast3.xml"
make_appcast "$appcast3"
if "$append" --appcast "$appcast3" --version 2.12 --build 300 \
  --url "https://example.com/a.dmg" --signature "SIG==" --length 100 \
  --notes "$notes" --pub-date d --minimum-system-version 15.6 >/dev/null 2>&1; then
  check "accepts a two-part version" pass
else
  check "accepts a two-part version" fail
fi

# Failed runs must not have modified the file.
if diff -q <(make_appcast /dev/stdout) "$appcast2" >/dev/null 2>&1; then
  check "leaves the appcast untouched when validation fails" pass
else
  check "leaves the appcast untouched when validation fails" fail
fi

echo
if (( failures > 0 )); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"

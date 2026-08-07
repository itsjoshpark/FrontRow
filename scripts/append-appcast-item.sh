#!/bin/bash
# Inserts a new <item> at the top of the Sparkle appcast, preserving the rest of
# the file byte for byte.
#
# Sparkle's own generate_appcast is not used here: it rewrites every entry whose
# archive it sees, which drops hand-written release notes and rebuilds
# shortVersionString from the bundle (losing the "2.10 (24)" convention). It also
# prunes old entries by default. This does the one thing needed instead, and
# leaves history alone.
#
# The signature and length come from Sparkle's sign_update.

set -euo pipefail

appcast="" version="" build="" url="" signature="" length="" notes=""
pub_date="" minimum_system_version=""

die() {
  echo "append-appcast-item: $1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appcast) appcast="${2-}"; shift 2 ;;
    --version) version="${2-}"; shift 2 ;;
    --build) build="${2-}"; shift 2 ;;
    --url) url="${2-}"; shift 2 ;;
    --signature) signature="${2-}"; shift 2 ;;
    --length) length="${2-}"; shift 2 ;;
    --notes) notes="${2-}"; shift 2 ;;
    --pub-date) pub_date="${2-}"; shift 2 ;;
    --minimum-system-version) minimum_system_version="${2-}"; shift 2 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

for required in appcast version build url signature length notes pub_date minimum_system_version; do
  [[ -n "${!required}" ]] || die "--${required//_/-} is required"
done

[[ -f "$appcast" ]] || die "appcast not found: $appcast"
[[ -f "$notes" ]] || die "notes file not found: $notes"
[[ "$build" =~ ^[0-9]+$ ]] || die "build must be a number, got '$build'"

# A CDATA terminator inside the notes would close the section early and corrupt
# the feed.
if grep -qF ']]>' "$notes"; then
  die "notes file contains ']]>', which would terminate the CDATA section: $notes"
fi

# Sparkle picks updates by CFBundleVersion. A build number that does not exceed
# the newest entry is never offered, so refuse rather than publish a dud.
newest="$(grep -o '<sparkle:version>[0-9]*</sparkle:version>' "$appcast" |
  grep -o '[0-9]*' | sort -n | tail -1)"
if [[ -n "$newest" ]] && (( build <= newest )); then
  die "build $build does not exceed the newest entry in the appcast ($newest)"
fi

notes_body="$(cat "$notes")"

item="$(
  cat <<XML

    <item>
      <title>New Version Available</title>
      <link>https://github.com/itsjoshpark/FrontRow</link>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version ($build)</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$minimum_system_version</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/itsjoshpark/FrontRow/releases</sparkle:fullReleaseNotesLink>
      <pubDate>$pub_date</pubDate>
      <enclosure
        url="$url"
        sparkle:edSignature="$signature"
        length="$length"
        type="application/octet-stream" />
      <description><![CDATA[
$notes_body
      ]]>
      </description>
    </item>
XML
)"

grep -q '</language>' "$appcast" || die "no <language> element to anchor insertion: $appcast"

# Write to a temp file and move into place, so a failure never leaves a
# half-written feed.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

ITEM="$item" awk '
  { print }
  !inserted && /<\/language>/ { print ENVIRON["ITEM"]; inserted = 1 }
' "$appcast" >"$tmp"

python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" "$tmp" ||
  die "the resulting appcast is not well-formed XML; leaving $appcast unchanged"

mv "$tmp" "$appcast"
trap - EXIT

echo "Added $version ($build) to $appcast"

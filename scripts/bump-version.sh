#!/bin/bash
# Prints the next marketing version, given the current one and a release type.
#
#   bump-version.sh v2.10 minor   ->  2.11.0
#
# Input may be two- or three-part, with or without a leading "v"; output is
# always normalized to X.Y.Z.

set -euo pipefail

current="${1-}"
release_type="${2-}"

die() {
  echo "bump-version: $1" >&2
  exit 1
}

case "$release_type" in
  major | minor | patch) ;;
  "") die "release type is required (major, minor, or patch)" ;;
  *) die "unknown release type '$release_type' (expected major, minor, or patch)" ;;
esac

version="${current#v}"
[[ -n "$version" ]] || die "version is required"

# Leading zeros are rejected: $(( )) reads 08 and 09 as invalid octal, and that
# error does not stop the script — it would print an unbumped version and exit 0.
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))?$ ]]; then
  die "cannot parse version '$current' (expected X.Y or X.Y.Z, no leading zeros)"
fi

IFS=. read -r major minor patch <<<"$version"
patch="${patch:-0}"

major=$((10#$major)) minor=$((10#$minor)) patch=$((10#$patch))

case "$release_type" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
esac

echo "$major.$minor.$patch"

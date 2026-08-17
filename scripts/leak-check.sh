#!/bin/bash
# Opens files in a running copy of Front Row and reports what it never gave back.
#
#   leak-check.sh                       -> build, generate fixtures, 5 cycles
#   leak-check.sh --cycles 20           -> longer run
#   leak-check.sh --app build/Front\ Row.app ~/Movies/a.mp4 ~/Movies/b.mp4
#
# Measures against a baseline taken once the app is up, so the system's own
# launch-time leaks - a few hundred of them, whatever the app does - are
# subtracted rather than kept in an allowlist that would need feeding forever.
# What is left is growth, plus anything whose allocation stack names the app's
# own binary.
#
# Open file descriptors are counted alongside, since the conversion path creates
# two pipes per run and a descriptor left open is the same bug with a different
# symptom.
#
# The app's preferences are exported before the run and restored after it, so the
# fixtures opened here do not displace the user's own recent documents.
#
# Needs ffmpeg to generate fixtures. Pass media files to skip that.

set -euo pipefail

cycles=5
app=""
keep=false
# Some launch-time allocations are reported on one sample and not the next, so a
# handful of movement either way is noise rather than a leak.
tolerance=10
files=()

bundle_id="dev.joshuapark.FrontRow"

die() {
  echo "leak-check: $1" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --cycles)
      cycles="${2-}"
      [[ "$cycles" =~ ^[1-9][0-9]*$ ]] || die "--cycles needs a positive number"
      shift 2
      ;;
    --tolerance)
      tolerance="${2-}"
      [[ "$tolerance" =~ ^[0-9]+$ ]] || die "--tolerance needs a number"
      shift 2
      ;;
    --app)
      app="${2-}"
      [[ -n "$app" ]] || die "--app needs a path"
      shift 2
      ;;
    --keep)
      keep=true
      shift
      ;;
    -h | --help)
      sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) die "unknown option '$1'" ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
app_pid=""
saved_preferences=""

# Kills the app before restoring preferences: a still-running copy would write
# its own list back over the one being restored on its way out.
cleanup() {
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "$app_pid" 2>/dev/null || break
      sleep 0.2
    done
  fi
  if [[ -n "$saved_preferences" && -f "$saved_preferences" ]]; then
    defaults import "$bundle_id" "$saved_preferences" 2>/dev/null || true
  fi
  if [[ "$keep" == true ]]; then
    echo "leak reports left in $work"
  else
    rm -rf "$work"
  fi
}
trap cleanup EXIT

# MARK: - The app

if [[ -z "$app" ]]; then
  echo "==> Building"
  xcodebuild build \
    -project "$repo_root/Front Row.xcodeproj" \
    -scheme "Front Row" \
    -destination "platform=macOS" \
    -derivedDataPath "$work/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    >"$work/build.log" 2>&1 ||
    die "build failed, see $work/build.log"
  app="$work/DerivedData/Build/Products/Debug/Front Row.app"
fi

[[ -d "$app" ]] || die "no app bundle at '$app'"
executable="$app/Contents/MacOS/Front Row"
[[ -x "$executable" ]] || die "no executable inside '$app'"

# MARK: - The files to open

if ((${#files[@]} == 0)); then
  command -v ffmpeg >/dev/null || die "no media files given and ffmpeg is not installed"
  echo "==> Generating fixtures"
  for spec in "320x180" "640x360"; do
    ffmpeg -nostdin -loglevel error -y \
      -f lavfi -i "testsrc=size=$spec:rate=10:duration=3" \
      -c:v libx264 -pix_fmt yuv420p \
      "$work/$spec.mp4" || die "ffmpeg could not write a fixture"
    files+=("$work/$spec.mp4")
  done
fi

for file in "${files[@]}"; do
  [[ -f "$file" ]] || die "no such file: $file"
done

# MARK: - Run

saved_preferences="$work/preferences-before.plist"
defaults export "$bundle_id" "$saved_preferences" ||
  die "could not export $bundle_id preferences to restore afterwards"

# Any copy already running would take the open requests instead of the one being
# measured, and its leaks are not the ones under test.
pkill -f "$executable" 2>/dev/null || true

echo "==> Launching with stack logging"
MallocStackLogging=1 MallocStackLoggingNoCompact=1 "$executable" \
  >"$work/app.log" 2>&1 &
app_pid=$!
# Stops bash announcing the kill in `cleanup` as job control noise on the way out.
disown "$app_pid" 2>/dev/null || true

# Long enough for the window to come up and the first-run work to settle, so the
# baseline is a launched app rather than a launching one.
sleep 8
kill -0 "$app_pid" 2>/dev/null || die "the app exited on launch, see $work/app.log"

count_leaks() {
  sed -n 's/^Process [0-9]*: \([0-9]*\) leaks for.*/\1/p' "$1" | tail -1
}

count_bytes() {
  sed -n 's/^Process [0-9]*: [0-9]* leaks for \([0-9]*\) total leaked bytes.*/\1/p' "$1" | tail -1
}

# Saves the full listing alongside the count, so growth can be read as "which
# descriptors" rather than only "how many".
count_descriptors() {
  lsof -p "$app_pid" 2>/dev/null >"$work/lsof-$1.txt" || true
  tail -n +2 "$work/lsof-$1.txt" | wc -l | tr -d ' '
}

run_cycle() {
  for file in "${files[@]}"; do
    open -a "$app" "$file" || die "could not open $file"
    sleep 2
  done
}

# The first file opened brings in a fixed set of one-time costs - font files,
# localization tables, asset catalogs, the video decoder's plug-in bundle - which
# on a baseline taken before it read as fifteen descriptors of growth that never
# grew again. So the baseline is taken after a warm-up, and what is measured is
# the second cycle onwards.
echo "==> Warming up"
run_cycle

# An `open` that started a second copy, or was ignored, would leave the measured
# process idle - and an idle app leaks nothing, which reads as a pass.
last_opened="$(basename "${files[$((${#files[@]} - 1))]}")"
lsof -p "$app_pid" 2>/dev/null | grep -qF "$last_opened" ||
  die "the app never opened the fixture - nothing was measured"

sleep 3
leaks "$app_pid" >"$work/leaks-baseline.txt" 2>&1 || true
baseline_leaks="$(count_leaks "$work/leaks-baseline.txt")"
baseline_bytes="$(count_bytes "$work/leaks-baseline.txt")"
baseline_descriptors="$(count_descriptors baseline)"
[[ -n "$baseline_leaks" ]] || die "leaks reported no total, see $work/leaks-baseline.txt"

echo "==> $cycles cycles over ${#files[@]} file(s)"
for ((cycle = 1; cycle <= cycles; cycle++)); do
  run_cycle
  printf '    cycle %d/%d\n' "$cycle" "$cycles"
done

# The last open is still settling, and an item released on the next run loop turn
# would otherwise be counted as leaked.
sleep 5

kill -0 "$app_pid" 2>/dev/null || die "the app exited during the run, see $work/app.log"

echo "==> Collecting"
leaks "$app_pid" >"$work/leaks-final.txt" 2>&1 || true
final_leaks="$(count_leaks "$work/leaks-final.txt")"
final_bytes="$(count_bytes "$work/leaks-final.txt")"
final_descriptors="$(count_descriptors final)"
[[ -n "$final_leaks" ]] || die "leaks reported no total, see $work/leaks-final.txt"

# MARK: - Verdict

printf '\n%-14s %10s %10s %10s\n' "" "baseline" "final" "growth"
printf '%-14s %10s %10s %10s\n' "leaks" \
  "$baseline_leaks" "$final_leaks" "$((final_leaks - baseline_leaks))"
printf '%-14s %10s %10s %10s\n' "leaked bytes" \
  "$baseline_bytes" "$final_bytes" "$((final_bytes - baseline_bytes))"
printf '%-14s %10s %10s %10s\n\n' "descriptors" \
  "$baseline_descriptors" "$final_descriptors" \
  "$((final_descriptors - baseline_descriptors))"

failed=false

if ((final_leaks - baseline_leaks > tolerance)); then
  echo "FAIL  $((final_leaks - baseline_leaks)) more leaks after $cycles cycles"
  failed=true
fi

if ((final_descriptors - baseline_descriptors > tolerance)); then
  echo "FAIL  $((final_descriptors - baseline_descriptors)) more open descriptors:"
  diff <(awk 'NR > 1 { print $5, $NF }' "$work/lsof-baseline.txt" | sort | uniq -c) \
    <(awk 'NR > 1 { print $5, $NF }' "$work/lsof-final.txt" | sort | uniq -c) |
    grep '^>' | head -20
  failed=true
fi

# Everything above "Binary Images" is the leak report itself; below it is the
# list of loaded binaries, where the app's own name appears whether it leaked or
# not.
stacks="$work/stacks.txt"
sed -n '/^leaks Report Version/,/^Binary Images:/p' "$work/leaks-final.txt" >"$stacks"

if ! grep -q '^STACK OF' "$stacks"; then
  echo "NOTE  no allocation stacks in the report - only the totals above are meaningful"
elif grep -qE "$bundle_id|Front Row\.debug\.dylib" "$stacks"; then
  echo "FAIL  a leak was allocated through the app's own binary:"
  grep -nE -B 4 "$bundle_id|Front Row\.debug\.dylib" "$stacks" | head -40
  failed=true
fi

if [[ "$failed" == true ]]; then
  keep=true
  exit 1
fi

echo "no growth in leaks or descriptors, and nothing leaked from Front Row itself"

#!/usr/bin/env bash
# ==============================================================================
# Test Suite: Redshift OS Wallpaper Recovery & Theme Preservation
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RECOVER_SCRIPT="$REPO_ROOT/dots/.local/share/redshift-os/recovery/recover-wallpaper.sh"

FAILED_TESTS=0
TOTAL_TESTS=0

pass() {
    printf '\e[32m[PASS]\e[0m %s\n' "$1"
}

fail() {
    printf '\e[31m[FAIL]\e[0m %s\n' "$1" >&2
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

run_test() {
    local desc="$1"
    shift
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    printf '\n--- Test %d: %s ---\n' "$TOTAL_TESTS" "$desc"
    if "$@"; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Setup isolated sandbox
TMP_ROOT="$(mktemp -d /tmp/redshift-recovery-test.XXXXXX)"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

mkdir -p "$XDG_CONFIG_HOME/illogical-impulse"
mkdir -p "$XDG_CONFIG_HOME/caelestia"
mkdir -p "$XDG_CONFIG_HOME/hypr/custom/scripts"
mkdir -p "$XDG_STATE_HOME/quickshell/ui-switch"
mkdir -p "$XDG_STATE_HOME/quickshell/user/generated/wallpaper"
mkdir -p "$XDG_STATE_HOME/caelestia/wallpaper"
mkdir -p "$TMP_ROOT/wallpapers"

# Create dummy sample assets
SAMPLE_VALID_PNG="$TMP_ROOT/wallpapers/valid_sample.png"
SAMPLE_CORRUPT_PNG="$TMP_ROOT/wallpapers/corrupt_sample.png"
SAMPLE_VIDEO_MP4="$TMP_ROOT/wallpapers/sample_video.mp4"
SAMPLE_DEFAULT_PNG="$TMP_ROOT/wallpapers/default_safe.png"

# Generate valid PNG
python3 - "$SAMPLE_VALID_PNG" <<'PY'
import sys
header = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc`\x00\x00\x00\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82'
with open(sys.argv[1], 'wb') as f:
    f.write(header)
PY
cp "$SAMPLE_VALID_PNG" "$SAMPLE_DEFAULT_PNG"

# Generate corrupt PNG (truncated header)
printf 'NOT_A_REAL_PNG_DATA_CORRUPT' > "$SAMPLE_CORRUPT_PNG"

# Generate dummy video file
printf 'dummy_video_content' > "$SAMPLE_VIDEO_MP4"

# Set default wallpaper candidate in XDG_CONFIG_HOME
mkdir -p "$XDG_CONFIG_HOME/quickshell/ii/assets/images"
cp "$SAMPLE_DEFAULT_PNG" "$XDG_CONFIG_HOME/quickshell/ii/assets/images/default_wallpaper.png"

# Setup dummy Material You palette files
echo "scheme-expressive" > "$XDG_STATE_HOME/quickshell/user/generated/applied_scheme_type.txt"
echo "scheme-expressive" > "$XDG_STATE_HOME/quickshell/user/generated/palette_type_preference.txt"
cat <<'EOF' > "$XDG_STATE_HOME/quickshell/user/generated/colors.json"
{
  "primary": "#d0bcff",
  "on_primary": "#381e72",
  "surface": "#141218",
  "on_surface": "#e6e0e9"
}
EOF

# Calculate initial theme hashes
INITIAL_APPLIED_HASH="$(sha256sum "$XDG_STATE_HOME/quickshell/user/generated/applied_scheme_type.txt" | cut -d' ' -f1)"
INITIAL_PREF_HASH="$(sha256sum "$XDG_STATE_HOME/quickshell/user/generated/palette_type_preference.txt" | cut -d' ' -f1)"
INITIAL_COLORS_HASH="$(sha256sum "$XDG_STATE_HOME/quickshell/user/generated/colors.json" | cut -d' ' -f1)"

# ------------------------------------------------------------------------------
# Test 1: Frontend Detection
# ------------------------------------------------------------------------------
test_frontend_detection() {
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    local detected
    detected="$(bash -c "source '$RECOVER_SCRIPT' && detect_frontend")"
    [[ "$detected" == "end4" ]] || return 1

    echo "caelestia" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    detected="$(bash -c "source '$RECOVER_SCRIPT' && detect_frontend")"
    [[ "$detected" == "caelestia" ]] || return 1

    rm -f "$XDG_STATE_HOME/quickshell/ui-switch/current"
    detected="$(bash -c "source '$RECOVER_SCRIPT' && detect_frontend")"
    [[ "$detected" == "end4" ]] || return 1
}
run_test "Frontend detection via ui-switch state and fallback" test_frontend_detection

# ------------------------------------------------------------------------------
# Test 2: Animation / Type Classification
# ------------------------------------------------------------------------------
test_classification() {
    bash -c "source '$RECOVER_SCRIPT' && is_animated 'test.mp4'" || return 1
    bash -c "source '$RECOVER_SCRIPT' && is_animated 'test.WEBM'" || return 1
    bash -c "source '$RECOVER_SCRIPT' && is_animated 'test.gif'" || return 1
    bash -c "source '$RECOVER_SCRIPT' && ! is_animated 'test.png'" || return 1
    bash -c "source '$RECOVER_SCRIPT' && ! is_animated 'test.jpg'" || return 1
    bash -c "source '$RECOVER_SCRIPT' && ! is_animated 'test.webp'" || return 1
}
run_test "Wallpaper classification (static vs animated)" test_classification

# ------------------------------------------------------------------------------
# Test 3: end-4 Static Image with Valid Wallpaper
# ------------------------------------------------------------------------------
test_end4_static_valid() {
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_VALID_PNG"
  }
}
EOF
    "$RECOVER_SCRIPT"

    local current_wall
    current_wall="$(jq -r '.background.wallpaperPath' "$XDG_CONFIG_HOME/illogical-impulse/config.json")"
    [[ "$current_wall" == "$SAMPLE_VALID_PNG" ]] || return 1
    [[ "$(cat "$XDG_STATE_HOME/quickshell/user/generated/wallpaper/path.txt")" == "$SAMPLE_VALID_PNG" ]] || return 1
}
run_test "end-4 static image recovery with valid wallpaper preserves path" test_end4_static_valid

# ------------------------------------------------------------------------------
# Test 4: end-4 Static Image with Corrupted Wallpaper (Fallback Trigger)
# ------------------------------------------------------------------------------
test_end4_static_corrupt() {
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_CORRUPT_PNG"
  }
}
EOF
    "$RECOVER_SCRIPT"

    local current_wall
    current_wall="$(jq -r '.background.wallpaperPath' "$XDG_CONFIG_HOME/illogical-impulse/config.json")"
    [[ "$current_wall" != "$SAMPLE_CORRUPT_PNG" ]] || return 1
    [[ -f "$current_wall" ]] || return 1
    [[ "$(cat "$XDG_STATE_HOME/quickshell/user/generated/wallpaper/path.txt")" == "$current_wall" ]] || return 1
}
run_test "end-4 static image recovery with corrupted wallpaper replaces with safe default" test_end4_static_corrupt

# ------------------------------------------------------------------------------
# Test 5: end-4 Video Wallpaper Recovery
# ------------------------------------------------------------------------------
test_end4_video_recovery() {
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_VIDEO_MP4"
  }
}
EOF
    # Remove restore script to test regeneration
    rm -f "$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh"

    "$RECOVER_SCRIPT"

    [[ -x "$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh" ]] || return 1
    grep -q "mpvpaper" "$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh" || return 1
}
run_test "end-4 video wallpaper generates executable restore script" test_end4_video_recovery

# ------------------------------------------------------------------------------
# Test 6: Caelestia Static Wallpaper Recovery & Sync
# ------------------------------------------------------------------------------
test_caelestia_static() {
    echo "caelestia" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/caelestia/shell.json"
{
  "background": {
    "wallpaperEnabled": false
  }
}
EOF
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_VALID_PNG"
  }
}
EOF
    printf '%s\n' "$SAMPLE_VALID_PNG" > "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"

    "$RECOVER_SCRIPT"

    # Verify wallpaperEnabled was switched back to true
    local enabled
    enabled="$(jq -r '.background.wallpaperEnabled' "$XDG_CONFIG_HOME/caelestia/shell.json")"
    [[ "$enabled" == "true" ]] || return 1

    # Verify scheme.json was generated/synchronized
    [[ -f "$XDG_STATE_HOME/caelestia/scheme.json" ]] || return 1
    grep -q '"flavour": "end4"' "$XDG_STATE_HOME/caelestia/scheme.json" || return 1
}
run_test "Caelestia static recovery sets wallpaperEnabled=true and syncs scheme.json" test_caelestia_static

# ------------------------------------------------------------------------------
# Test 7: Caelestia Video Wallpaper Recovery
# ------------------------------------------------------------------------------
test_caelestia_video() {
    echo "caelestia" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/caelestia/shell.json"
{
  "background": {
    "wallpaperEnabled": true
  }
}
EOF
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_VIDEO_MP4"
  }
}
EOF
    printf '%s\n' "$SAMPLE_VIDEO_MP4" > "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"

    "$RECOVER_SCRIPT"

    # Verify wallpaperEnabled is set to false for video mode
    local enabled
    enabled="$(jq -r '.background.wallpaperEnabled' "$XDG_CONFIG_HOME/caelestia/shell.json")"
    [[ "$enabled" == "false" ]] || return 1
}
run_test "Caelestia video recovery sets wallpaperEnabled=false" test_caelestia_video

# ------------------------------------------------------------------------------
# Test 8: Diagnostic / Check-Only Mode (--check)
# ------------------------------------------------------------------------------
test_check_mode() {
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_CORRUPT_PNG"
  }
}
EOF
    # In check mode with a corrupt image, it should exit with code 1 without altering config
    if "$RECOVER_SCRIPT" --check; then
        return 1
    fi

    local current_wall
    current_wall="$(jq -r '.background.wallpaperPath' "$XDG_CONFIG_HOME/illogical-impulse/config.json")"
    [[ "$current_wall" == "$SAMPLE_CORRUPT_PNG" ]] || return 1
}
run_test "--check diagnostic mode detects failure without modifying files" test_check_mode

# ------------------------------------------------------------------------------
# Test 9: Forced Frontend Flag (--frontend)
# ------------------------------------------------------------------------------
test_forced_frontend() {
    # ui-switch says end4, but we force caelestia
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/caelestia/shell.json"
{
  "background": {
    "wallpaperEnabled": false
  }
}
EOF
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$SAMPLE_VALID_PNG"
  }
}
EOF
    printf '%s\n' "$SAMPLE_VALID_PNG" > "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"
    "$RECOVER_SCRIPT" --frontend caelestia

    local enabled
    enabled="$(jq -r '.background.wallpaperEnabled' "$XDG_CONFIG_HOME/caelestia/shell.json")"
    [[ "$enabled" == "true" ]] || return 1
}
run_test "--frontend flag overrides ui-switch state" test_forced_frontend

# ------------------------------------------------------------------------------
# Test 10: Missing Video File Triggers Safe Static Fallback
# ------------------------------------------------------------------------------
test_missing_video_fallback() {
    echo "end4" > "$XDG_STATE_HOME/quickshell/ui-switch/current"
    cat <<EOF > "$XDG_CONFIG_HOME/illogical-impulse/config.json"
{
  "background": {
    "wallpaperPath": "$TMP_ROOT/wallpapers/nonexistent_video.mp4"
  }
}
EOF
    "$RECOVER_SCRIPT"

    local current_wall
    current_wall="$(jq -r '.background.wallpaperPath' "$XDG_CONFIG_HOME/illogical-impulse/config.json")"
    [[ "$current_wall" != "$TMP_ROOT/wallpapers/nonexistent_video.mp4" ]] || return 1
    [[ -f "$current_wall" ]] || return 1
}
run_test "Missing video file falls back safely to default static wallpaper" test_missing_video_fallback

# ------------------------------------------------------------------------------
# Test 11: Strict Theme Preservation Integrity
# ------------------------------------------------------------------------------
test_theme_preservation() {
    local post_applied_hash
    local post_pref_hash
    local post_colors_hash

    post_applied_hash="$(sha256sum "$XDG_STATE_HOME/quickshell/user/generated/applied_scheme_type.txt" | cut -d' ' -f1)"
    post_pref_hash="$(sha256sum "$XDG_STATE_HOME/quickshell/user/generated/palette_type_preference.txt" | cut -d' ' -f1)"
    post_colors_hash="$(sha256sum "$XDG_STATE_HOME/quickshell/user/generated/colors.json" | cut -d' ' -f1)"

    [[ "$INITIAL_APPLIED_HASH" == "$post_applied_hash" ]] || {
        echo "applied_scheme_type.txt was modified!" >&2
        return 1
    }
    [[ "$INITIAL_PREF_HASH" == "$post_pref_hash" ]] || {
        echo "palette_type_preference.txt was modified!" >&2
        return 1
    }
    [[ "$INITIAL_COLORS_HASH" == "$post_colors_hash" ]] || {
        echo "colors.json was modified!" >&2
        return 1
    }
}
run_test "STRICT PRESERVATION: Material You scheme, preference and colors are 100% intact" test_theme_preservation

printf '\n===================================================\n'
if [[ $FAILED_TESTS -eq 0 ]]; then
    printf '\e[32mALL %d TESTS PASSED SUCCESSFULLY!\e[0m\n' "$TOTAL_TESTS"
    exit 0
else
    printf '\e[31m%d OF %d TESTS FAILED.\e[0m\n' "$FAILED_TESTS" "$TOTAL_TESTS"
    exit 1
fi

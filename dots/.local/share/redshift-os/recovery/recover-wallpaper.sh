#!/usr/bin/env bash
# ==============================================================================
# Redshift OS - Wallpaper Recovery & Theme Preservation (Level 2 UI Recovery)
# Path: dots/.local/share/redshift-os/recovery/recover-wallpaper.sh
#
# Responsibilities:
#   1. Detect active frontend (end4 or caelestia) from ui-switch state or runtime.
#   2. Identify if configured wallpaper is static (image) or animated (video/gif).
#   3. For video wallpaper:
#      - end-4: verify if mpvpaper is active on current monitor; if missing, execute
#               __restore_video_wallpaper.sh cleanly without duplicates.
#      - Caelestia: verify if video-wallpaper-sync.sh or mpvpaper is active; if failed,
#                   trigger video-wallpaper-sync.sh once or reattach watch process.
#   4. For static wallpaper:
#      - end-4: ensure wallpaper file pointed in config.json / path.txt exists and is
#               readable. If corrupted/missing, apply safe default without changing theme.
#      - Caelestia: certify end4-theme-bridge.sh has synchronized scheme.json and that
#                   .background.wallpaperEnabled is true in caelestia/shell.json.
#   5. STRICT PRESERVATION:
#      - NEVER invoke Matugen or switchwall.sh during recovery.
#      - NEVER change Material You variants or preferences.
#      - NEVER toggle light/dark mode.
#      - NEVER pick random wallpapers.
#      - Prevent duplicate or rogue mpvpaper processes.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Base Environment & Directory Layout
# ------------------------------------------------------------------------------
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Configurations
II_CONFIG="$XDG_CONFIG_HOME/illogical-impulse/config.json"
CAEL_CONFIG="$XDG_CONFIG_HOME/caelestia/shell.json"

# State & Cache Paths
UI_SWITCH_STATE_DIR="$XDG_STATE_HOME/quickshell/ui-switch"
UI_SWITCH_CURRENT="$UI_SWITCH_STATE_DIR/current"
VIDEO_PID_FILE="$UI_SWITCH_STATE_DIR/video-bridge.pid"

END4_WALL_FILE="$XDG_STATE_HOME/quickshell/user/generated/wallpaper/path.txt"
END4_COLORS_FILE="$XDG_STATE_HOME/quickshell/user/generated/colors.json"
END4_APPLIED_SCHEME="$XDG_STATE_HOME/quickshell/user/generated/applied_scheme_type.txt"
END4_PREF_SCHEME="$XDG_STATE_HOME/quickshell/user/generated/palette_type_preference.txt"

CAEL_STATE_DIR="$XDG_STATE_HOME/caelestia"
CAEL_WALL_FILE="$CAEL_STATE_DIR/wallpaper/path.txt"
CAEL_SCHEME_FILE="$CAEL_STATE_DIR/scheme.json"

# Helper Scripts
RESTORE_VIDEO_SCRIPT="$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh"
CAEL_BRIDGE_SCRIPT="$XDG_CONFIG_HOME/quickshell/caelestia-hybrid/scripts/end4-theme-bridge.sh"
CAEL_VIDEO_SYNC_SCRIPT="$XDG_CONFIG_HOME/quickshell/caelestia-hybrid/scripts/video-wallpaper-sync.sh"

# ------------------------------------------------------------------------------
# Logging Utilities
# ------------------------------------------------------------------------------
log_info() {
    printf '[%s] [recover-wallpaper] %s\n' "$(date '+%H:%M:%S')" "$*"
}

log_warn() {
    printf '[%s] [recover-wallpaper] [AVISO] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

log_error() {
    printf '[%s] [recover-wallpaper] [ERRO] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

# ------------------------------------------------------------------------------
# Helper: Detect Safe Default Wallpaper
# ------------------------------------------------------------------------------
find_safe_default_wallpaper() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

    local candidates=(
        "$XDG_CONFIG_HOME/quickshell/ii/assets/images/default_wallpaper.png"
        "$XDG_CONFIG_HOME/quickshell/caelestia-hybrid/assets/wallpaper.webp"
        "$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png"
        "$HOME/.config/quickshell/caelestia-hybrid/assets/wallpaper.webp"
        "$script_dir/../../../../dots/.config/quickshell/ii/assets/images/default_wallpaper.png"
        "$script_dir/../../../../dots/.config/quickshell/caelestia-hybrid/assets/wallpaper.webp"
        "/usr/share/backgrounds/redshift/default_wallpaper.png"
    )

    for cand in "${candidates[@]}"; do
        if [[ -f "$cand" && -r "$cand" && -s "$cand" ]]; then
            printf '%s\n' "$(realpath -q "$cand" || echo "$cand")"
            return 0
        fi
    done

    # Fallback to any readable image or create a minimal 1x1 image if in synthetic test env
    local fallback_dir="${XDG_DATA_HOME}/redshift-os/recovery"
    local fallback_img="$fallback_dir/default_fallback.png"
    if [[ -f "$fallback_img" && -s "$fallback_img" ]]; then
        printf '%s\n' "$fallback_img"
        return 0
    fi

    mkdir -p "$fallback_dir" 2>/dev/null || true
    if command -v magick >/dev/null 2>&1; then
        magick -size 1920x1080 xc:"#141318" "$fallback_img" 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$fallback_img" <<'PY'
import sys
# Create a valid 1x1 png file
header = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc`\x00\x00\x00\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82'
try:
    with open(sys.argv[1], 'wb') as f:
        f.write(header)
except Exception:
    pass
PY
    fi

    if [[ -f "$fallback_img" && -s "$fallback_img" ]]; then
        printf '%s\n' "$fallback_img"
        return 0
    fi

    echo ""
    return 1
}

# ------------------------------------------------------------------------------
# Helper: Detect Active Frontend
# ------------------------------------------------------------------------------
detect_frontend() {
    # 1. Consult ui-switch state file
    if [[ -f "$UI_SWITCH_CURRENT" ]]; then
        local current_val
        current_val="$(head -n 1 "$UI_SWITCH_CURRENT" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' || true)"
        if [[ "$current_val" == *"cael"* ]]; then
            printf 'caelestia\n'
            return 0
        elif [[ "$current_val" == *"end4"* || "$current_val" == *"ii"* ]]; then
            printf 'end4\n'
            return 0
        fi
    fi

    # 2. Check running quickshell instances
    if pgrep -f "quickshell.*caelestia-hybrid" >/dev/null 2>&1; then
        printf 'caelestia\n'
        return 0
    elif pgrep -f "quickshell.*ii" >/dev/null 2>&1; then
        printf 'end4\n'
        return 0
    fi

    # 3. Default fallback for Redshift OS
    printf 'end4\n'
    return 0
}

# ------------------------------------------------------------------------------
# Helper: Get Configured Wallpaper Path
# ------------------------------------------------------------------------------
get_configured_wallpaper() {
    local frontend="$1"
    local wall=""

    if [[ "$frontend" == "caelestia" ]]; then
        if [[ -f "$CAEL_WALL_FILE" ]]; then
            wall="$(head -n 1 "$CAEL_WALL_FILE" 2>/dev/null | tr -d '\r\n' || true)"
        fi
        if [[ -z "$wall" && -f "$II_CONFIG" ]]; then
            wall="$(jq -r '.background.wallpaperPath // empty' "$II_CONFIG" 2>/dev/null || true)"
        fi
        if [[ -z "$wall" && -f "$END4_WALL_FILE" ]]; then
            wall="$(head -n 1 "$END4_WALL_FILE" 2>/dev/null | tr -d '\r\n' || true)"
        fi
    else
        # end-4
        if [[ -f "$II_CONFIG" ]]; then
            wall="$(jq -r '.background.wallpaperPath // empty' "$II_CONFIG" 2>/dev/null || true)"
        fi
        if [[ -z "$wall" && -f "$END4_WALL_FILE" ]]; then
            wall="$(head -n 1 "$END4_WALL_FILE" 2>/dev/null | tr -d '\r\n' || true)"
        fi
        if [[ -z "$wall" && -f "$CAEL_WALL_FILE" ]]; then
            wall="$(head -n 1 "$CAEL_WALL_FILE" 2>/dev/null | tr -d '\r\n' || true)"
        fi
    fi

    # Normalize path (remove file:// prefix)
    wall="${wall#file://}"
    printf '%s\n' "$wall"
}

# ------------------------------------------------------------------------------
# Helper: Check Animated (video/gif)
# ------------------------------------------------------------------------------
is_animated() {
    local path="$1"
    case "${path,,}" in
        *.mp4|*.webm|*.mkv|*.mov|*.m4v|*.avi|*.gif)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Helper: Validate Static Image Integrity
# ------------------------------------------------------------------------------
validate_static_image() {
    local path="$1"

    if [[ -z "$path" ]]; then
        return 1
    fi

    if [[ ! -f "$path" || ! -r "$path" || ! -s "$path" ]]; then
        return 1
    fi

    # Check using identify / magick if available
    if command -v identify >/dev/null 2>&1; then
        if identify -ping "$path" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi

    if command -v magick >/dev/null 2>&1; then
        if magick identify -ping "$path" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi

    # Check file mime type
    if command -v file >/dev/null 2>&1; then
        local mime
        mime="$(file -b --mime-type "$path" 2>/dev/null || true)"
        if [[ "$mime" == image/* ]]; then
            return 0
        fi
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Helper: Apply Safe Default Wallpaper Without Touching Theme / Matugen
# ------------------------------------------------------------------------------
apply_safe_default() {
    local safe_wall="$1"
    local frontend="$2"

    log_warn "Wallpaper inválido ou inacessível. Aplicando default seguro com preservação total de tema: $safe_wall"

    # Update config.json without running switchwall.sh or matugen
    if [[ -f "$II_CONFIG" ]]; then
        python3 - "$II_CONFIG" "$safe_wall" <<'PY'
import sys, json
from pathlib import Path

config_path = Path(sys.argv[1])
safe_wall = sys.argv[2]

try:
    data = json.loads(config_path.read_text()) if config_path.exists() else {}
except Exception:
    data = {}

bg = data.setdefault("background", {})
bg["wallpaperPath"] = safe_wall
if "thumbnailPath" in bg:
    bg["thumbnailPath"] = safe_wall

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")
PY
    fi

    # Update end4 wallpaper path.txt
    mkdir -p "$(dirname "$END4_WALL_FILE")"
    printf '%s\n' "$safe_wall" > "$END4_WALL_FILE"

    # If caelestia, update caelestia wallpaper path.txt
    if [[ "$frontend" == "caelestia" ]]; then
        mkdir -p "$(dirname "$CAEL_WALL_FILE")"
        printf '%s\n' "$safe_wall" > "$CAEL_WALL_FILE"
    fi
}

# ------------------------------------------------------------------------------
# Helper: Caelestia shell.json .background.wallpaperEnabled Manager
# ------------------------------------------------------------------------------
set_caelestia_wallpaper_enabled() {
    local enabled="$1"

    python3 - "$enabled" "$CAEL_CONFIG" <<'PY'
import json, sys
from pathlib import Path

enabled = sys.argv[1].lower() == "true"
config_path = Path(sys.argv[2])

if config_path.exists() and config_path.read_text().strip():
    try:
        data = json.loads(config_path.read_text())
    except Exception:
        data = {}
else:
    data = {}

bg = data.setdefault("background", {})
if bg.get("wallpaperEnabled") != enabled:
    bg["wallpaperEnabled"] = enabled
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")
PY
}

# ------------------------------------------------------------------------------
# Helper: Sanitize Restore Video Script
# ------------------------------------------------------------------------------
sanitize_end4_restore_video_script() {
    if [[ -f "$RESTORE_VIDEO_SCRIPT" ]]; then
        if grep -q "mpvpaper" "$RESTORE_VIDEO_SCRIPT" 2>/dev/null; then
            mkdir -p "$(dirname "$RESTORE_VIDEO_SCRIPT")"
            cat << 'EOF' > "$RESTORE_VIDEO_SCRIPT.tmp"
#!/bin/bash
# The content of this script will be generated by switchwall.sh - Don't modify it by yourself.
EOF
            mv "$RESTORE_VIDEO_SCRIPT.tmp" "$RESTORE_VIDEO_SCRIPT"
            chmod +x "$RESTORE_VIDEO_SCRIPT"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Helper: Caelestia Theme Bridge Fallback
# ------------------------------------------------------------------------------
sync_caelestia_theme_fallback() {
    local mode="dark"
    if command -v gsettings >/dev/null 2>&1; then
        local g_scheme
        g_scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
        if [[ "$g_scheme" == *light* ]]; then
            mode="light"
        fi
    fi

    local applied_type="scheme-tonal-spot"
    if [[ -f "$END4_APPLIED_SCHEME" ]]; then
        applied_type="$(tr -d '\r\n' < "$END4_APPLIED_SCHEME" || echo "scheme-tonal-spot")"
    fi

    local type_pref="auto"
    if [[ -f "$END4_PREF_SCHEME" ]]; then
        type_pref="$(tr -d '\r\n' < "$END4_PREF_SCHEME" || echo "auto")"
    fi

    MODE="$mode" \
    VARIANT="$applied_type" \
    VARIANT_PREFERENCE="$type_pref" \
    END4_COLORS="$END4_COLORS_FILE" \
    CAEL_SCHEME="$CAEL_SCHEME_FILE" \
    python3 <<'PY'
import json, os, re
from pathlib import Path

source = Path(os.environ["END4_COLORS"])
target = Path(os.environ["CAEL_SCHEME"])
mode = os.environ.get("MODE", "dark")
variant = os.environ.get("VARIANT", "tonalspot").replace("scheme-", "").replace("-", "")
variant_preference = os.environ.get("VARIANT_PREFERENCE", "auto").replace("scheme-", "").replace("-", "")

colours = {}
if source.is_file():
    try:
        data = json.loads(source.read_text())
        for name, value in data.items():
            if isinstance(value, str) and value.startswith("#"):
                camel = re.sub(r"_([a-z])", lambda m: m.group(1).upper(), name)
                colours[camel] = value.lstrip("#")
    except Exception:
        pass

scheme = {
    "name": "end4-recovered",
    "flavour": "end4",
    "mode": mode,
    "variant": variant,
    "variantPreference": variant_preference,
    "colours": colours
}

target.parent.mkdir(parents=True, exist_ok=True)
tmp = target.with_suffix(".json.tmp")
tmp.write_text(json.dumps(scheme, indent=2, ensure_ascii=False) + "\n")
tmp.replace(target)
PY
}

# ------------------------------------------------------------------------------
# Core Recovery: end-4 Static Wallpaper
# ------------------------------------------------------------------------------
recover_end4_static() {
    local wall="$1"
    local check_only="${2:-false}"

    log_info "Verificando integridade do wallpaper estático para end-4: $wall"

    if ! validate_static_image "$wall"; then
        log_warn "Wallpaper estático corrompido ou ausente: '$wall'"
        if [[ "$check_only" == "true" ]]; then
            return 1
        fi
        local safe_wall
        safe_wall="$(find_safe_default_wallpaper)"
        if [[ -z "$safe_wall" ]]; then
            log_error "Nenhum default seguro encontrado para substituição!"
            return 1
        fi
        apply_safe_default "$safe_wall" "end4"
        wall="$safe_wall"
    fi

    if [[ "$check_only" == "true" ]]; then
        return 0
    fi

    # Garantir consistência entre config.json e path.txt
    if [[ -f "$END4_WALL_FILE" ]]; then
        local current_in_txt
        current_in_txt="$(head -n 1 "$END4_WALL_FILE" 2>/dev/null | tr -d '\r\n' || true)"
        if [[ "$current_in_txt" != "$wall" ]]; then
            printf '%s\n' "$wall" > "$END4_WALL_FILE"
        fi
    else
        mkdir -p "$(dirname "$END4_WALL_FILE")"
        printf '%s\n' "$wall" > "$END4_WALL_FILE"
    fi

    # Em modo estático, garantir que mpvpaper não esteja executando por trás
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        log_info "Terminando processo concorrente mpvpaper em modo estático..."
        pkill -x mpvpaper 2>/dev/null || true
    fi

    # Limpar __restore_video_wallpaper.sh para não reativar vídeo em reinício
    sanitize_end4_restore_video_script

    log_info "Wallpaper estático para end-4 verificado e saudável: $wall"
    return 0
}

# ------------------------------------------------------------------------------
# Core Recovery: end-4 Video Wallpaper
# ------------------------------------------------------------------------------
recover_end4_video() {
    local video_path="$1"
    local check_only="${2:-false}"

    log_info "Verificando wallpaper em vídeo para end-4: $video_path"

    # Verificar se o arquivo de vídeo existe e é acessível
    if [[ ! -f "$video_path" || ! -r "$video_path" || ! -s "$video_path" ]]; then
        log_warn "Arquivo de vídeo não encontrado ou vazio: '$video_path'. Fallback para imagem segura."
        if [[ "$check_only" == "true" ]]; then
            return 1
        fi
        local safe_wall
        safe_wall="$(find_safe_default_wallpaper)"
        apply_safe_default "$safe_wall" "end4"
        pkill -x mpvpaper 2>/dev/null || true
        sanitize_end4_restore_video_script
        return 0
    fi

    # Verificar se mpvpaper está em execução para o monitor ativo
    local active_monitor=""
    if command -v hyprctl >/dev/null 2>&1; then
        active_monitor="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)"
    fi

    local mpv_active=false
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        if [[ -n "$active_monitor" ]]; then
            if pgrep -a mpvpaper 2>/dev/null | grep -qw "$active_monitor"; then
                mpv_active=true
            fi
        else
            mpv_active=true
        fi
    fi

    if [[ "$mpv_active" == "true" ]]; then
        log_info "mpvpaper já está em execução para o monitor ativo (${active_monitor:-default})."
        return 0
    fi

    log_warn "mpvpaper ausente para o monitor ativo (${active_monitor:-default}). Restaurando vídeo..."
    if [[ "$check_only" == "true" ]]; then
        return 1
    fi

    # Assegurar que __restore_video_wallpaper.sh existe e possui chamada válida
    local need_regen_restore=false
    if [[ ! -f "$RESTORE_VIDEO_SCRIPT" ]] || ! grep -q "mpvpaper" "$RESTORE_VIDEO_SCRIPT" 2>/dev/null; then
        need_regen_restore=true
    fi

    if [[ "$need_regen_restore" == "true" ]]; then
        mkdir -p "$(dirname "$RESTORE_VIDEO_SCRIPT")"
        local video_opts="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"
        cat << EOF > "$RESTORE_VIDEO_SCRIPT.tmp"
#!/bin/bash
# Generated by Redshift UI Recovery
# Time: $(date)

pkill -x mpvpaper 2>/dev/null || true

if command -v hyprctl >/dev/null 2>&1; then
    monitors=\$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | .name' 2>/dev/null)
fi
if [[ -z "\${monitors:-}" ]]; then
    monitors="ALL"
fi

for monitor in \$monitors; do
    mpvpaper -o "$video_opts" "\$monitor" "$video_path" &
    sleep 0.1
done
EOF
        mv "$RESTORE_VIDEO_SCRIPT.tmp" "$RESTORE_VIDEO_SCRIPT"
        chmod +x "$RESTORE_VIDEO_SCRIPT"
    else
        chmod +x "$RESTORE_VIDEO_SCRIPT"
    fi

    # Evitar múltiplos processos concorrentes antes de disparar
    pkill -x mpvpaper 2>/dev/null || true
    sleep 0.1

    # Executar script de restauração
    "$RESTORE_VIDEO_SCRIPT" &
    log_info "Script de restauração de vídeo executado com sucesso."
    return 0
}

# ------------------------------------------------------------------------------
# Core Recovery: Caelestia Static Wallpaper
# ------------------------------------------------------------------------------
recover_caelestia_static() {
    local wall="$1"
    local check_only="${2:-false}"

    log_info "Verificando wallpaper estático para Caelestia Hybrid: $wall"

    if ! validate_static_image "$wall"; then
        log_warn "Wallpaper estático Caelestia corrompido ou ausente: '$wall'"
        if [[ "$check_only" == "true" ]]; then
            return 1
        fi
        local safe_wall
        safe_wall="$(find_safe_default_wallpaper)"
        if [[ -z "$safe_wall" ]]; then
            log_error "Nenhum default seguro encontrado!"
            return 1
        fi
        apply_safe_default "$safe_wall" "caelestia"
        wall="$safe_wall"
    fi

    if [[ "$check_only" == "true" ]]; then
        return 0
    fi

    # Certificar que .background.wallpaperEnabled está true em shell.json
    set_caelestia_wallpaper_enabled true

    # Parar mpvpaper se estiver rodando inadvertidamente
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        log_info "Terminando processo concorrente mpvpaper no Caelestia em modo estático..."
        pkill -x mpvpaper 2>/dev/null || true
    fi

    # Parar video-wallpaper-sync se ainda ativo
    if [[ -f "$VIDEO_PID_FILE" ]]; then
        local vpid
        vpid="$(head -n 1 "$VIDEO_PID_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ -n "$vpid" ]] && kill -0 "$vpid" 2>/dev/null; then
            kill "$vpid" 2>/dev/null || true
        fi
        rm -f "$VIDEO_PID_FILE"
    fi

    # Certificar que end4-theme-bridge.sh sincronizou a paleta sem tocar em matugen
    if [[ -x "$CAEL_BRIDGE_SCRIPT" ]]; then
        log_info "Executando sincronização do end4-theme-bridge.sh (sem argumentos)..."
        "$CAEL_BRIDGE_SCRIPT" >/dev/null 2>&1 || log_warn "end4-theme-bridge.sh retornou aviso/erro."
    else
        sync_caelestia_theme_fallback
    fi

    # Garantir CAEL_WALL_FILE atualizado
    mkdir -p "$(dirname "$CAEL_WALL_FILE")"
    printf '%s\n' "$wall" > "$CAEL_WALL_FILE"

    log_info "Wallpaper estático e tema do Caelestia sincronizados e saudáveis."
    return 0
}

# ------------------------------------------------------------------------------
# Core Recovery: Caelestia Video Wallpaper
# ------------------------------------------------------------------------------
recover_caelestia_video() {
    local video_path="$1"
    local check_only="${2:-false}"

    log_info "Verificando wallpaper em vídeo para Caelestia Hybrid: $video_path"

    # Verificar se o arquivo de vídeo existe e é acessível
    if [[ ! -f "$video_path" || ! -r "$video_path" || ! -s "$video_path" ]]; then
        log_warn "Vídeo Caelestia não encontrado ou vazio: '$video_path'. Fallback para imagem segura."
        if [[ "$check_only" == "true" ]]; then
            return 1
        fi
        local safe_wall
        safe_wall="$(find_safe_default_wallpaper)"
        apply_safe_default "$safe_wall" "caelestia"
        set_caelestia_wallpaper_enabled true
        pkill -x mpvpaper 2>/dev/null || true
        return 0
    fi

    # Verificar se video-wallpaper-sync.sh ou mpvpaper está ativo
    local sync_active=false
    if [[ -f "$VIDEO_PID_FILE" ]]; then
        local vpid
        vpid="$(head -n 1 "$VIDEO_PID_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ -n "$vpid" ]] && kill -0 "$vpid" 2>/dev/null; then
            sync_active=true
        fi
    fi
    if ! $sync_active && pgrep -f "video-wallpaper-sync.sh.*watch" >/dev/null 2>&1; then
        sync_active=true
    fi

    local mpv_active=false
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        mpv_active=true
    fi

    if $sync_active && $mpv_active; then
        log_info "Sincronizador Caelestia (video-wallpaper-sync.sh) e mpvpaper estão ativos."
        return 0
    fi

    log_warn "Caelestia vídeo inconsistente (sync_active=$sync_active, mpv_active=$mpv_active). Recuperando..."
    if [[ "$check_only" == "true" ]]; then
        return 1
    fi

    # Assegurar que .background.wallpaperEnabled está false para o vídeo transparecer
    set_caelestia_wallpaper_enabled false

    if [[ -x "$CAEL_VIDEO_SYNC_SCRIPT" ]]; then
        log_info "Acionando video-wallpaper-sync.sh once..."
        "$CAEL_VIDEO_SYNC_SCRIPT" once >/dev/null 2>&1 || true

        # Se o modo watch não estiver rodando e Caelestia estiver em execução, reatar o processo watch
        if ! $sync_active; then
            log_info "Reatando processo video-wallpaper-sync.sh watch em segundo plano..."
            nohup "$CAEL_VIDEO_SYNC_SCRIPT" watch >/dev/null 2>&1 &
        fi
    else
        log_info "Subindo mpvpaper diretamente para Caelestia..."
        pkill -x mpvpaper 2>/dev/null || true
        sleep 0.1
        mpvpaper -p -o "no-audio --loop-file=inf --panscan=1 --hwdec=auto-safe" ALL "$video_path" >/dev/null 2>&1 &
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Usage / Help
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Recuperação de wallpaper e preservação estrita de temas (Nível 2 UI Recovery).

Opções:
  -f, --frontend <end4|caelestia>  Forçar o frontend alvo (ignora autodetecção).
  -c, --check                     Apenas verificar o estado sem aplicar correções (diagnóstico).
  -v, --verbose                   Exibir logs detalhados de execução.
  -h, --help                      Exibir esta mensagem de ajuda.

Comportamento de Preservação:
  - Não executa matugen nem altera os tokens de cores Material You.
  - Não altera applied_scheme_type.txt nem palette_type_preference.txt.
  - Não alterna modo claro/escuro.
  - Não seleciona imagens aleatórias.
EOF
}

# ------------------------------------------------------------------------------
# Main Entry Point
# ------------------------------------------------------------------------------
recover_wallpaper() {
    local forced_frontend=""
    local check_only=false
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --frontend|-f)
                forced_frontend="$2"
                shift 2
                ;;
            --check|-c)
                check_only=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                show_help
                return 0
                ;;
            *)
                log_error "Argumento desconhecido: $1"
                show_help
                return 1
                ;;
        esac
    done

    # 1. Detectar Frontend Ativo
    local frontend
    if [[ -n "$forced_frontend" ]]; then
        frontend="${forced_frontend,,}"
    else
        frontend="$(detect_frontend)"
    fi
    log_info "Frontend alvo: $frontend"

    # 2. Obter wallpaper configurado
    local wall
    wall="$(get_configured_wallpaper "$frontend")"

    if [[ -z "$wall" ]]; then
        log_warn "Nenhum wallpaper encontrado nas configurações. Buscando default seguro..."
        wall="$(find_safe_default_wallpaper)"
        if [[ -z "$wall" ]]; then
            log_error "Falha crítica: impossível localizar wallpaper configurado ou padrão seguro."
            return 1
        fi
        if [[ "$check_only" != "true" ]]; then
            apply_safe_default "$wall" "$frontend"
        fi
    fi

    # 3. Identificar se é animado (vídeo/gif) ou estático (imagem)
    if is_animated "$wall"; then
        log_info "Classificação do wallpaper: Animado (vídeo/gif)"
        if [[ "$frontend" == "caelestia" ]]; then
            recover_caelestia_video "$wall" "$check_only"
        else
            recover_end4_video "$wall" "$check_only"
        fi
    else
        log_info "Classificação do wallpaper: Estático (imagem)"
        if [[ "$frontend" == "caelestia" ]]; then
            recover_caelestia_static "$wall" "$check_only"
        else
            recover_end4_static "$wall" "$check_only"
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    recover_wallpaper "$@"
fi

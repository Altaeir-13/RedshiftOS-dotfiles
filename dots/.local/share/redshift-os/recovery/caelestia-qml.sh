#!/usr/bin/env bash
# Sourced by the frontend launcher, recovery and diagnostics.

redshift_qml_roots() {
    local tool qt_qml
    local -a import_paths=() legacy_paths=()
    printf '%s\n' "${CAELESTIA_QML_PATH:-}"
    [[ "${CAELESTIA_QML_ONLY:-false}" != true ]] || return 0
    IFS=: read -r -a import_paths <<< "${QML_IMPORT_PATH:-}"
    IFS=: read -r -a legacy_paths <<< "${QML2_IMPORT_PATH:-}"
    for tool in qtpaths6 /usr/lib/qt6/bin/qtpaths6 qtpaths; do
        command -v "$tool" >/dev/null || continue
        if qt_qml="$(timeout 5 "$tool" --query QT_INSTALL_QML)" && [[ -n "$qt_qml" ]]; then
            break
        fi
        qt_qml=
    done
    printf '%s\n' "${import_paths[@]}" "${legacy_paths[@]}" "${qt_qml:-}" \
        /usr/lib/qt6/qml /usr/local/lib/qt6/qml \
        "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/qml" "$HOME/.local/lib/qt6/qml"
}

redshift_caelestia_layout() {
    local root="$1" module directory plugin
    for module in Caelestia Caelestia.Blobs Caelestia.Components Caelestia.Config \
        Caelestia.I18n Caelestia.Images Caelestia.Models Caelestia.Services Caelestia.Settings; do
        directory="$root/${module//./\/}"
        if [[ ! -r "$directory/qmldir" ]]; then
            printf 'Módulo %s incompleto: %s/qmldir ausente.\n' "$module" "$directory" >&2
            return 1
        fi
        if ! plugin="$(awk -v module="$module" '
            $1 == "module" && $2 == module { found=1 }
            $1 == "plugin" { plugin=$2 }
            $1 == "optional" && $2 == "plugin" { plugin=$3 }
            END { if (found && plugin != "") print plugin; else exit 1 }
        ' "$directory/qmldir")"; then
            printf 'Declaração do módulo ou plugin %s ausente em %s/qmldir.\n' "$module" "$directory" >&2
            return 1
        fi
        if [[ ! -r "$directory/lib$plugin.so" ]]; then
            printf 'Biblioteca nativa de %s ausente em %s (%s).\n' "$module" "$directory" "$plugin" >&2
            return 1
        fi
    done
}

redshift_resolve_caelestia_qml() {
    local root problem
    local -a problems=()
    while IFS= read -r root; do
        [[ "$root" == /* && -d "$root/Caelestia" ]] || continue
        if problem="$(redshift_caelestia_layout "$root" 2>&1)"; then
            printf '%s\n' "$root"
            return 0
        fi
        problems+=("$problem")
    done < <(redshift_qml_roots | awk 'NF && !seen[$0]++')
    printf '%s\n' 'Instalação incompleta ou ausente do módulo QML Caelestia.' "${problems[@]}" >&2
    return 1
}

redshift_caelestia_link_check() {
    local root="$1" library output failed=0
    local -a libraries
    mapfile -d '' -t libraries < <(find "$root/Caelestia" -type f -name '*.so*' -print0)
    if (( ${#libraries[@]} == 0 )); then
        printf 'Nenhuma biblioteca nativa encontrada em %s/Caelestia.\n' "$root" >&2
        return 1
    fi
    for library in "${libraries[@]}"; do
        if ! output="$(LC_ALL=C timeout 10 ldd -r "$library" 2>&1)" ||
            [[ "$output" =~ (not\ found|undefined\ symbol) ]]; then
            printf 'Falha de ABI ou de verificação em %s\n%s\n' "$library" "$output" >&2
            failed=1
        fi
    done
    return "$failed"
}

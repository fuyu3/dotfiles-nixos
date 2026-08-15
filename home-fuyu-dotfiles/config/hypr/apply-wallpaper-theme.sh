#!/usr/bin/env bash

set -euo pipefail

wallpaper_path="${1:-}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
wallust_config_dir="$config_home/wallust"

if [[ -z "$wallpaper_path" ]]; then
    echo "usage: $0 /path/to/wallpaper" >&2
    exit 64
fi

if ! command -v wallust >/dev/null 2>&1; then
    echo "wallust is not installed" >&2
    exit 127
fi

if [[ "$wallpaper_path" != /* ]]; then
    wallpaper_path="$(realpath -m "$wallpaper_path")"
fi

if [[ ! -f "$wallpaper_path" ]]; then
    echo "wallpaper not found: $wallpaper_path" >&2
    exit 66
fi

mkdir -p "$HOME/.cache"
echo "$wallpaper_path" > "$HOME/.cache/current_wallpaper"

if command -v awww >/dev/null 2>&1; then
    if ! awww query >/dev/null 2>&1; then
        if command -v awww-daemon >/dev/null 2>&1; then
            awww-daemon --quiet >/dev/null 2>&1 &
            sleep 0.2
        fi
    fi

    awww img \
        --resize crop \
        --filter Lanczos3 \
        --transition-type fade \
        --transition-duration 0.6 \
        --transition-fps 30 \
        "$wallpaper_path" >/dev/null 2>&1 || true
fi

wallust run \
    --overwrite-cache \
    --quiet \
    --config-dir "$wallust_config_dir" \
    "$wallpaper_path"

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
fi

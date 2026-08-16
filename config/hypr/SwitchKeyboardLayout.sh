#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Cycle through the layouts configured in Hyprland's Lua input configuration.

layout_file="$HOME/.cache/kb_layout"
settings_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf.d/input.lua"

# Refined ignore list with patterns or specific device names
ignore_patterns=(
  "--(avrcp)" 
  "Bluetooth Speaker" 
  "Other Device 
  Name"
  )
# Read the Lua string: kb_layout = "us,br",.
if [[ ! -f "$settings_file" ]]; then
  echo "Hyprland Lua configuration not found: $settings_file" >&2
  exit 1
fi

kb_layout_line=$(sed -nE 's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$settings_file" | head -n1)
if [[ -z "$kb_layout_line" ]]; then
  echo "Could not read kb_layout from: $settings_file" >&2
  exit 1
fi

IFS=',' read -r -a layout_mapping <<< "$kb_layout_line"
layout_count=${#layout_mapping[@]}
if (( layout_count == 0 )); then
  echo "No keyboard layouts configured in: $settings_file" >&2
  exit 1
fi

# Create the state file from the first Lua-configured layout on first use.
if [[ ! -f "$layout_file" ]]; then
  current_layout="${layout_mapping[0]}"
  mkdir -p "$(dirname "$layout_file")"
  printf '%s\n' "$current_layout" > "$layout_file"
else
  current_layout=$(<"$layout_file")
fi

echo "Current layout: $current_layout"

echo "Number of layouts: $layout_count"

# Find current layout index and calculate next layout
current_index=0
for ((i = 0; i < layout_count; i++)); do
  if [ "$current_layout" == "${layout_mapping[i]}" ]; then
    current_index=$i
    break
  fi
done

next_index=$(( (current_index + 1) % layout_count ))
new_layout="${layout_mapping[next_index]}"
echo "Next layout: $new_layout"

# Function to get keyboard names
get_keyboard_names() {
    hyprctl devices -j | jq -r '.keyboards[].name'
}

# Function to check if a device matches any ignore pattern
is_ignored() {
    local device_name=$1
    for pattern in "${ignore_patterns[@]}"; do
        if [[ "$device_name" == *"$pattern"* ]]; then
            return 0 # Device matches ignore pattern
        fi
    done
    return 1 # Device does not match any ignore pattern
}

# Function to change keyboard layout
change_layout() {
    local error_found=false

    while read -r name; do
        if is_ignored "$name"; then
            echo "Skipping ignored device: $name"
            continue
        fi
        
        echo "Switching layout for $name to $new_layout..."
	      hyprctl switchxkblayout "$name" "$next_index"
        if [ $? -ne 0 ]; then
            echo "Error while switching layout for $name." >&2
            error_found=true
        fi
    done <<< "$(get_keyboard_names)"

    $error_found && return 1
    return 0
}

# Execute layout change and notify
if ! change_layout; then
    notify-send -u low -t 2000 'kb_layout' " Error:" " Layout change failed"
    echo "Layout change failed." >&2
    exit 1
else
    notify-send -u low -t 2000 " kb_layout: $new_layout"
    echo "Layout change notification sent."
fi

echo "$new_layout" > "$layout_file"

#!/usr/bin/env bash

DEBUG=false
SPECIAL_WS="special:scratchpad"
ADDR_FILE="/tmp/dropdown_spotify_addr"

WIDTH_PERCENT=75
HEIGHT_PERCENT=60
Y_PERCENT=5

lua_quote() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf '"%s"' "$value"
}

dispatch_lua() {
  hyprctl dispatch "$1"
}

window_selector() {
  lua_quote "address:$1"
}

dispatch_exec_with_rules() {
  local command="$1"
  local width="$2"
  local height="$3"
  local workspace="$4"

  dispatch_lua "hl.dsp.exec_cmd($(lua_quote "$command"), { float = true, size = { $width, $height }, workspace = $(lua_quote "$workspace") })"
}

dispatch_pin_window() {
  dispatch_lua "hl.dsp.window.pin({ window = $(window_selector "$1") })"
}

dispatch_float_window() {
  dispatch_lua "hl.dsp.window.float({ action = \"on\", window = $(window_selector "$1") })"
}

dispatch_focus_window() {
  dispatch_lua "hl.dsp.focus({ window = $(window_selector "$1") })"
}

dispatch_move_window_to_workspace_silent() {
  dispatch_lua "hl.dsp.window.move({ workspace = $(lua_quote "$1"), follow = false, window = $(window_selector "$2") })"
}

dispatch_move_window_exact() {
  dispatch_lua "hl.dsp.window.move({ x = $1, y = $2, window = $(window_selector "$3") })"
}

dispatch_resize_window_exact() {
  dispatch_lua "hl.dsp.window.resize({ x = $1, y = $2, window = $(window_selector "$3") })"
}

if [ "$1" = "-d" ]; then
  DEBUG=true
  shift
fi

SPOTIFY_CMD="${1:-spotify-launcher}"

debug_echo() {
  if [ "$DEBUG" = true ]; then
    echo "$@"
  fi
}

clear_spotify_address() {
  : >"$ADDR_FILE"
}

is_spotify_window() {
  local addr="$1"
  hyprctl clients -j | jq -e --arg ADDR "$addr" '
    any(.[]; .address == $ADDR and (
      (.class // "" | test("spotify"; "i")) or
      (.initialClass // "" | test("spotify"; "i"))
    ))
  ' >/dev/null 2>&1
}

get_spotify_address() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    local stored_addr
    stored_addr=$(cut -d' ' -f1 "$ADDR_FILE")

    if is_spotify_window "$stored_addr"; then
      echo "$stored_addr"
      return 0
    fi

    clear_spotify_address
  fi

  hyprctl clients -j | jq -r '
    map(select(
      (.class // "" | test("spotify"; "i")) or
      (.initialClass // "" | test("spotify"; "i"))
    ))
    | sort_by(.focusHistoryID)
    | .[0].address // empty
  '
}

get_spotify_monitor() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f2- "$ADDR_FILE"
  fi
}

spotify_in_special() {
  local addr="$1"
  hyprctl clients -j | jq -e --arg ADDR "$addr" --arg WS "$SPECIAL_WS" \
    'any(.[]; .address == $ADDR and .workspace.name == $WS)' >/dev/null 2>&1
}

spotify_is_pinned() {
  local addr="$1"
  hyprctl clients -j | jq -e --arg ADDR "$addr" \
    'any(.[]; .address == $ADDR and .pinned == true)' >/dev/null 2>&1
}

pin_spotify() {
  local addr="$1"
  if ! spotify_is_pinned "$addr"; then
    dispatch_pin_window "$addr" >/dev/null 2>&1
  fi
}

unpin_spotify() {
  local addr="$1"
  if spotify_is_pinned "$addr"; then
    dispatch_pin_window "$addr" >/dev/null 2>&1
  fi
}

get_monitor_info() {
  local monitor_data
  monitor_data=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"')
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}

calculate_dropdown_position() {
  local monitor_info
  monitor_info=$(get_monitor_info)

  if [ $? -ne 0 ] || [ -z "$monitor_info" ]; then
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  fi

  local mon_x mon_y mon_width mon_height mon_scale mon_name
  mon_x=$(echo "$monitor_info" | cut -d' ' -f1)
  mon_y=$(echo "$monitor_info" | cut -d' ' -f2)
  mon_width=$(echo "$monitor_info" | cut -d' ' -f3)
  mon_height=$(echo "$monitor_info" | cut -d' ' -f4)
  mon_scale=$(echo "$monitor_info" | cut -d' ' -f5)
  mon_name=$(echo "$monitor_info" | cut -d' ' -f6)

  debug_echo "Monitor info: x=$mon_x, y=$mon_y, width=$mon_width, height=$mon_height, scale=$mon_scale"

  if [ -z "$mon_scale" ] || [ "$mon_scale" = "null" ] || [ "$mon_scale" = "0" ]; then
    debug_echo "Invalid scale value, using 1.0 as fallback"
    mon_scale="1.0"
  fi

  local logical_width logical_height
  if command -v bc >/dev/null 2>&1; then
    logical_width=$(echo "scale=0; $mon_width / $mon_scale" | bc | cut -d'.' -f1)
    logical_height=$(echo "scale=0; $mon_height / $mon_scale" | bc | cut -d'.' -f1)
  else
    local scale_int=$(echo "$mon_scale" | sed 's/\.//' | sed 's/^0*//')
    if [ -z "$scale_int" ]; then scale_int=100; fi

    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  if ! [[ "$logical_width" =~ ^-?[0-9]+$ ]]; then logical_width=$mon_width; fi
  if ! [[ "$logical_height" =~ ^-?[0-9]+$ ]]; then logical_height=$mon_height; fi

  debug_echo "Physical resolution: ${mon_width}x${mon_height}"
  debug_echo "Logical resolution: ${logical_width}x${logical_height} (physical ÷ scale)"

  local width height x_offset y_offset final_x final_y
  width=$((logical_width * WIDTH_PERCENT / 100))
  height=$((logical_height * HEIGHT_PERCENT / 100))
  x_offset=$(((logical_width - width) / 2))
  y_offset=$((logical_height * Y_PERCENT / 100))
  final_x=$((mon_x + x_offset))
  final_y=$((mon_y + y_offset))

  debug_echo "Window size: ${width}x${height} (logical pixels)"
  debug_echo "Final position: x=$final_x, y=$final_y (logical coordinates)"
  debug_echo "Hyprland will scale these to physical coordinates automatically"

  echo "$final_x $final_y $width $height $mon_name"
}

position_spotify() {
  local addr="$1"
  local pos_info target_x target_y width height monitor_name

  if ! is_spotify_window "$addr"; then
    clear_spotify_address
    return 1
  fi

  pos_info=$(calculate_dropdown_position)
  target_x=$(echo "$pos_info" | cut -d' ' -f1)
  target_y=$(echo "$pos_info" | cut -d' ' -f2)
  width=$(echo "$pos_info" | cut -d' ' -f3)
  height=$(echo "$pos_info" | cut -d' ' -f4)
  monitor_name=$(echo "$pos_info" | cut -d' ' -f5)

  dispatch_resize_window_exact "$width" "$height" "$addr" >/dev/null 2>&1
  dispatch_move_window_exact "$target_x" "$target_y" "$addr" >/dev/null 2>&1
  echo "$addr $monitor_name" >"$ADDR_FILE"
}

show_spotify() {
  local addr="$1"
  local current_ws

  if ! is_spotify_window "$addr"; then
    clear_spotify_address
    return 1
  fi

  current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

  dispatch_move_window_to_workspace_silent "$current_ws" "$addr" >/dev/null 2>&1
  pin_spotify "$addr"
  dispatch_float_window "$addr" >/dev/null 2>&1
  position_spotify "$addr"
  dispatch_focus_window "$addr" >/dev/null 2>&1
}

hide_spotify() {
  local addr="$1"

  if ! is_spotify_window "$addr"; then
    clear_spotify_address
    return 1
  fi

  unpin_spotify "$addr"
  dispatch_move_window_to_workspace_silent "$SPECIAL_WS" "$addr" >/dev/null 2>&1
}

spawn_spotify() {
  debug_echo "Creating new dropdown Spotify with command: $SPOTIFY_CMD"

  local pos_info width height addr windows_before windows_after count_before count_after
  pos_info=$(calculate_dropdown_position)
  if [ $? -ne 0 ]; then
    debug_echo "Warning: Using fallback positioning"
  fi

  width=$(echo "$pos_info" | cut -d' ' -f3)
  height=$(echo "$pos_info" | cut -d' ' -f4)

  windows_before=$(hyprctl clients -j)
  count_before=$(echo "$windows_before" | jq 'length')

  dispatch_exec_with_rules "$SPOTIFY_CMD" "$width" "$height" "$SPECIAL_WS silent" >/dev/null 2>&1

  for _ in $(seq 1 80); do
    sleep 0.1
    windows_after=$(hyprctl clients -j)
    count_after=$(echo "$windows_after" | jq 'length')

    if [ "$count_after" -gt "$count_before" ]; then
      addr=$(comm -13 \
        <(echo "$windows_before" | jq -r '.[].address' | sort) \
        <(echo "$windows_after" | jq -r '.[].address' | sort) |
        while read -r candidate; do
          if is_spotify_window "$candidate"; then
            echo "$candidate"
            break
          fi
        done)
    fi

    if [ -z "$addr" ]; then
      addr=$(get_spotify_address)
    fi

    if [ -n "$addr" ] && is_spotify_window "$addr"; then
      debug_echo "Spotify created with address: $addr"
      echo "$addr" >"$ADDR_FILE"
      show_spotify "$addr"
      return 0
    fi
  done

  clear_spotify_address
  debug_echo "Failed to get Spotify address"
  return 1
}

SPOTIFY_ADDR=$(get_spotify_address)

if [ -z "$SPOTIFY_ADDR" ]; then
  spawn_spotify
else
  debug_echo "Found existing Spotify: $SPOTIFY_ADDR"
  focused_monitor=$(get_monitor_info | awk '{print $6}')
  dropdown_monitor=$(get_spotify_monitor)

  if [ "$focused_monitor" != "$dropdown_monitor" ]; then
    debug_echo "Monitor focus changed: moving dropdown to $focused_monitor"
    position_spotify "$SPOTIFY_ADDR"
  fi

  if spotify_in_special "$SPOTIFY_ADDR"; then
    show_spotify "$SPOTIFY_ADDR"
  else
    hide_spotify "$SPOTIFY_ADDR"
  fi
fi
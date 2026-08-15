#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
#
# Made and brought to by Kiran George
# /* -- ✨ https://github.com/SherLock707 ✨ -- */  ##
# Dropdown Terminal
# Usage: ./Dropdown.sh [-d] <terminal_command>
# Example: ./Dropdown.sh foot
#          ./Dropdown.sh -d foot (with debug output)
#          ./Dropdown.sh "kitty -e zsh"
#          ./Dropdown.sh "alacritty --working-directory /home/user"

DEBUG=false
SPECIAL_WS="special:scratchpad"
ADDR_FILE="/tmp/dropdown_terminal_addr"
DROPDOWN_CLASS="kitty-dropterm"

# Dropdown size and position configuration (percentages)
WIDTH_PERCENT=75  # Width as percentage of screen width
HEIGHT_PERCENT=60 # Height as percentage of screen height
Y_PERCENT=5      # Y position as percentage from top (X is auto-centered)

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

# Parse arguments
if [ "$1" = "-d" ]; then
  DEBUG=true
  shift
fi

TERMINAL_CMD="$1"

# Debug echo function
debug_echo() {
  if [ "$DEBUG" = true ]; then
    echo "$@"
  fi
}

# Validate input
if [ -z "$TERMINAL_CMD" ]; then
  echo "Missing terminal command. Usage: $0 [-d] <terminal_command>"
  echo "Examples:"
  echo "  $0 foot"
  echo "  $0 -d foot (with debug output)"
  echo "  $0 'kitty -e zsh'"
  echo "  $0 'alacritty --working-directory /home/user'"
  echo ""
  echo "Edit the script to modify size and position:"
  echo "  WIDTH_PERCENT  - Width as percentage of screen (default: 50)"
  echo "  HEIGHT_PERCENT - Height as percentage of screen (default: 50)"
  echo "  Y_PERCENT      - Y position from top as percentage (default: 5)"
  echo "  Note: X position is automatically centered"
  exit 1
fi

case "$TERMINAL_CMD" in
kitty)
  TERMINAL_CMD="kitty --class $DROPDOWN_CLASS"
  ;;
kitty\ *)
  if [[ "$TERMINAL_CMD" != *"--class"* ]] && [[ "$TERMINAL_CMD" != *"--app-id"* ]]; then
    TERMINAL_CMD="kitty --class $DROPDOWN_CLASS ${TERMINAL_CMD#kitty }"
  fi
  ;;
esac

# Function to get monitor info including scale and name of focused monitor
get_monitor_info() {
  local monitor_data=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"')
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}

# Function to calculate dropdown position with proper scaling and centering
calculate_dropdown_position() {
  local monitor_info=$(get_monitor_info)

  if [ $? -ne 0 ] || [ -z "$monitor_info" ]; then
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  fi

  local mon_x=$(echo $monitor_info | cut -d' ' -f1)
  local mon_y=$(echo $monitor_info | cut -d' ' -f2)
  local mon_width=$(echo $monitor_info | cut -d' ' -f3)
  local mon_height=$(echo $monitor_info | cut -d' ' -f4)
  local mon_scale=$(echo $monitor_info | cut -d' ' -f5)
  local mon_name=$(echo $monitor_info | cut -d' ' -f6)

  debug_echo "Monitor info: x=$mon_x, y=$mon_y, width=$mon_width, height=$mon_height, scale=$mon_scale"

  # Validate scale value and provide fallback
  if [ -z "$mon_scale" ] || [ "$mon_scale" = "null" ] || [ "$mon_scale" = "0" ]; then
    debug_echo "Invalid scale value, using 1.0 as fallback"
    mon_scale="1.0"
  fi

  # Calculate logical dimensions by dividing physical dimensions by scale
  local logical_width logical_height
  if command -v bc >/dev/null 2>&1; then
    # Use bc for precise floating point calculation
    logical_width=$(echo "scale=0; $mon_width / $mon_scale" | bc | cut -d'.' -f1)
    logical_height=$(echo "scale=0; $mon_height / $mon_scale" | bc | cut -d'.' -f1)
  else
    # Fallback to integer math (multiply by 100 for precision, then divide)
    local scale_int=$(echo "$mon_scale" | sed 's/\.//' | sed 's/^0*//')
    if [ -z "$scale_int" ]; then scale_int=100; fi

    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  # Ensure we have valid integer values
  if ! [[ "$logical_width" =~ ^-?[0-9]+$ ]]; then logical_width=$mon_width; fi
  if ! [[ "$logical_height" =~ ^-?[0-9]+$ ]]; then logical_height=$mon_height; fi

  debug_echo "Physical resolution: ${mon_width}x${mon_height}"
  debug_echo "Logical resolution: ${logical_width}x${logical_height} (physical ÷ scale)"

  # Calculate window dimensions based on LOGICAL space percentages
  local width=$((logical_width * WIDTH_PERCENT / 100))
  local height=$((logical_height * HEIGHT_PERCENT / 100))

  # Calculate Y position from top based on percentage of LOGICAL height
  local y_offset=$((logical_height * Y_PERCENT / 100))

  # Calculate centered X position in LOGICAL space
  local x_offset=$(((logical_width - width) / 2))

  # Apply monitor offset to get final positions in logical coordinates
  local final_x=$((mon_x + x_offset))
  local final_y=$((mon_y + y_offset))

  debug_echo "Window size: ${width}x${height} (logical pixels)"
  debug_echo "Final position: x=$final_x, y=$final_y (logical coordinates)"
  debug_echo "Hyprland will scale these to physical coordinates automatically"

  echo "$final_x $final_y $width $height $mon_name"
}

# Get the current workspace
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

# Function to get stored terminal address
get_terminal_address() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f1 "$ADDR_FILE"
  fi
}

# Function to get stored monitor name
get_terminal_monitor() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f2- "$ADDR_FILE"
  fi
}

clear_terminal_address() {
  : >"$ADDR_FILE"
}

is_dropdown_terminal_window() {
  local addr="$1"
  hyprctl clients -j | jq -e --arg ADDR "$addr" --arg CLASS "$DROPDOWN_CLASS" '
    any(.[]; .address == $ADDR and (
      (.class // "") == $CLASS or
      (.initialClass // "") == $CLASS
    ))
  ' >/dev/null 2>&1
}

# Function to check if terminal exists
terminal_exists() {
  local addr=$(get_terminal_address)
  if [ -n "$addr" ]; then
    if is_dropdown_terminal_window "$addr"; then
      return 0
    fi

    clear_terminal_address
    return 1
  else
    return 1
  fi
}

# Function to check if terminal is in special workspace
terminal_in_special() {
  local addr=$(get_terminal_address)
  if [ -n "$addr" ]; then
    hyprctl clients -j | jq -e --arg ADDR "$addr" --arg WS "$SPECIAL_WS" --arg CLASS "$DROPDOWN_CLASS" '
      any(.[]; .address == $ADDR and .workspace.name == $WS and (
        (.class // "") == $CLASS or
        (.initialClass // "") == $CLASS
      ))
    ' >/dev/null 2>&1
  else
    return 1
  fi
}

terminal_is_pinned() {
  local addr=$(get_terminal_address)
  if [ -n "$addr" ]; then
    hyprctl clients -j | jq -e --arg ADDR "$addr" --arg CLASS "$DROPDOWN_CLASS" '
      any(.[]; .address == $ADDR and .pinned == true and (
        (.class // "") == $CLASS or
        (.initialClass // "") == $CLASS
      ))
    ' >/dev/null 2>&1
  else
    return 1
  fi
}

pin_terminal() {
  local addr="$1"
  if ! terminal_is_pinned; then
    dispatch_pin_window "$addr" >/dev/null 2>&1
  fi
}

unpin_terminal() {
  local addr="$1"
  if terminal_is_pinned; then
    dispatch_pin_window "$addr" >/dev/null 2>&1
  fi
}

# Function to spawn terminal and capture its address
spawn_terminal() {
  debug_echo "Creating new dropdown terminal with command: $TERMINAL_CMD"

  # Calculate dropdown position for later use
  local pos_info=$(calculate_dropdown_position)
  if [ $? -ne 0 ]; then
    debug_echo "Warning: Using fallback positioning"
  fi

  local target_x=$(echo $pos_info | cut -d' ' -f1)
  local target_y=$(echo $pos_info | cut -d' ' -f2)
  local width=$(echo $pos_info | cut -d' ' -f3)
  local height=$(echo $pos_info | cut -d' ' -f4)
  local monitor_name=$(echo $pos_info | cut -d' ' -f5)

  debug_echo "Target position: ${target_x},${target_y}, size: ${width}x${height}"

  # Get window count before spawning
  local windows_before=$(hyprctl clients -j)
  local count_before=$(echo "$windows_before" | jq 'length')

  # Launch terminal directly in special workspace to avoid visible spawn
  dispatch_exec_with_rules "$TERMINAL_CMD" "$width" "$height" "special:scratchpad silent"

  # Wait for window to appear
  sleep 0.1

  # Get windows after spawning
  local windows_after=$(hyprctl clients -j)
  local count_after=$(echo "$windows_after" | jq 'length')

  local new_addr=""

  if [ "$count_after" -gt "$count_before" ]; then
    # Find the new window by comparing before/after lists
    new_addr=$(comm -13 \
      <(echo "$windows_before" | jq -r '.[].address' | sort) \
      <(echo "$windows_after" | jq -r '.[].address' | sort) |
      while read -r candidate; do
        if is_dropdown_terminal_window "$candidate"; then
          echo "$candidate"
          break
        fi
      done)
  fi

  if [ -z "$new_addr" ] || [ "$new_addr" = "null" ]; then
    new_addr=$(hyprctl clients -j | jq -r --arg CLASS "$DROPDOWN_CLASS" '
      map(select((.class // "") == $CLASS or (.initialClass // "") == $CLASS))
      | sort_by(.focusHistoryID)
      | .[0].address // empty
    ')
  fi

  if [ -n "$new_addr" ] && [ "$new_addr" != "null" ] && is_dropdown_terminal_window "$new_addr"; then
    # Store the address and monitor name
    echo "$new_addr $monitor_name" >"$ADDR_FILE"
    debug_echo "Terminal created with address: $new_addr in special workspace on monitor $monitor_name"

    # Small delay to ensure it's properly in special workspace
    sleep 0.2

    # Bring it back like the Spotify dropdown and let Hyprland handle fade.
    dispatch_move_window_to_workspace_silent "$CURRENT_WS" "$new_addr"
    pin_terminal "$new_addr"
    dispatch_float_window "$new_addr" >/dev/null 2>&1
    dispatch_resize_window_exact "$width" "$height" "$new_addr"
    dispatch_move_window_exact "$target_x" "$target_y" "$new_addr"

    return 0
  fi

  clear_terminal_address
  debug_echo "Failed to get terminal address"
  return 1
}

# Main logic
if terminal_exists; then
  TERMINAL_ADDR=$(get_terminal_address)
  debug_echo "Found existing terminal: $TERMINAL_ADDR"
  focused_monitor=$(get_monitor_info | awk '{print $6}')
  dropdown_monitor=$(get_terminal_monitor)
  if [ "$focused_monitor" != "$dropdown_monitor" ]; then
    debug_echo "Monitor focus changed: moving dropdown to $focused_monitor"
    # Calculate new position for focused monitor
    pos_info=$(calculate_dropdown_position)
    target_x=$(echo $pos_info | cut -d' ' -f1)
    target_y=$(echo $pos_info | cut -d' ' -f2)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)
    monitor_name=$(echo $pos_info | cut -d' ' -f5)
    # Move and resize window
    dispatch_move_window_exact "$target_x" "$target_y" "$TERMINAL_ADDR"
    dispatch_resize_window_exact "$width" "$height" "$TERMINAL_ADDR"
    # Update ADDR_FILE
    echo "$TERMINAL_ADDR $monitor_name" >"$ADDR_FILE"
  fi

  if terminal_in_special; then
    debug_echo "Bringing terminal from scratchpad with Hyprland fade animation"

    # Calculate target position
    pos_info=$(calculate_dropdown_position)
    target_x=$(echo $pos_info | cut -d' ' -f1)
    target_y=$(echo $pos_info | cut -d' ' -f2)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)

    # Use movetoworkspacesilent to avoid affecting workspace history
    dispatch_move_window_to_workspace_silent "$CURRENT_WS" "$TERMINAL_ADDR"
    pin_terminal "$TERMINAL_ADDR"
    dispatch_float_window "$TERMINAL_ADDR" >/dev/null 2>&1

    # Set size and position; Hyprland handles the visual transition.
    dispatch_resize_window_exact "$width" "$height" "$TERMINAL_ADDR"
    dispatch_move_window_exact "$target_x" "$target_y" "$TERMINAL_ADDR"

    dispatch_focus_window "$TERMINAL_ADDR"
  else
    debug_echo "Hiding terminal to scratchpad with Hyprland fade animation"
    unpin_terminal "$TERMINAL_ADDR"
    dispatch_move_window_to_workspace_silent "$SPECIAL_WS" "$TERMINAL_ADDR"
  fi
else
  debug_echo "No existing terminal found, creating new one"
  if spawn_terminal; then
    TERMINAL_ADDR=$(get_terminal_address)
    if [ -n "$TERMINAL_ADDR" ]; then
      dispatch_focus_window "$TERMINAL_ADDR"
    fi
  fi
fi

-- Hyprland Lua config.

local function current_dir()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    return source:sub(2):match("(.+)/[^/]+$")
  end

  return (os.getenv("HOME") or "") .. "/.config/hypr"
end

HYPR = {
  home = os.getenv("HOME") or "",
  dir = current_dir(),
}

local function source(name)
  dofile(HYPR.dir .. "/conf.d/" .. name .. ".lua")
end

source("lib")
source("monitors")
source("programs")
source("autostart")
source("env")

-- NVIDIA-only settings.
-- Uncomment this line when using the proprietary NVIDIA driver.
source("nvidia")

source("appearance")
source("input")
source("keybindings")
source("window-rules")
source("permissions")

source("infinite-canvas")
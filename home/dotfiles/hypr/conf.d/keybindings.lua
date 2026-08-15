local c = HYPR
local mainMod = c.mainMod

hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("nm-connection-editor"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("gnome-system-monitor"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(c.terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(c.fileManager))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(c.menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "toggle split (dwindle)" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("gnome-calculator"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lockScreen open"))
hl.bind("ALT_L + SHIFT_L", hl.dsp.exec_cmd(c.script_cmd("SwitchKeyboardLayout.sh")), { locked = true, non_consuming = true })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(c.script_cmd("dropterm.sh", "kitty")))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(c.script_cmd("dropspotify.sh")))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(c.script_cmd("Restart.sh")))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("gnome-characters"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboardViewer toggle"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call wallpaperPicker toggle"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call workspacesWidget toggle"))
hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd(c.script_cmd("toggle-floating.sh")))

hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + CTRL + tab", hl.dsp.group.next())
hl.bind("ALT + tab", hl.dsp.window.cycle_next({ next = true }))
hl.bind("ALT + tab", hl.dsp.window.alter_zorder({ mode = "top" }))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 set 5%-"), { locked = true, repeating = true })

hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + ALT + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.swap({ direction = "d" }))

hl.bind(mainMod .. " + tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + U", hl.dsp.workspace.toggle_special(""))

for i = 1, 10 do
  local keycode = 9 + i
  local workspace = i
  hl.bind(mainMod .. " + code:" .. keycode, hl.dsp.focus({ workspace = workspace }))
  hl.bind(mainMod .. " + SHIFT + code:" .. keycode, hl.dsp.window.move({ workspace = workspace }))
  hl.bind(mainMod .. " + CTRL + code:" .. keycode, hl.dsp.window.move({ workspace = workspace, follow = false }))
end

hl.bind(mainMod .. " + SHIFT + bracketleft", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mainMod .. " + CTRL + bracketleft", hl.dsp.window.move({ workspace = "-1", follow = false }))
hl.bind(mainMod .. " + CTRL + bracketright", hl.dsp.window.move({ workspace = "+1", follow = false }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
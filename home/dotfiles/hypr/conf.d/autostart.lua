hl.on("hyprland.start", function()
  local commands = {
    "blueman-applet",
    "nm-applet --indicator",
    "nm-applet &",
    "wl-clip-persist -p",
    "wl-paste --type text --watch cliphist store",
    "wl-paste --type image --watch cliphist store",
    "wl-clip-persist --clipboard regular",
    "/usr/lib/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh",
    "systemctl --user enable --now hyprpolkitagent.service",
    "awww-daemon --quiet",
    "quickshell",
    "hypridle",
    os.getenv("HOME") .. "/.config/hypr/canvasd.py",
  }

  for _, command in ipairs(commands) do
    hl.exec_cmd(command)
  end
end)

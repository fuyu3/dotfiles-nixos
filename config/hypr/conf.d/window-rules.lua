local c = HYPR
local wr = c.window_rule
local lr = c.layer_rule

local tag_rules = {
  { { class = "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$" }, "browser" },
  { { class = "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$" }, "browser" },
  { { class = "^(chrome-.+-Default)$" }, "browser" },
  { { class = "^([Cc]hromium)$" }, "browser" },
  { { class = "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$" }, "browser" },
  { { class = "^(Brave-browser(-beta|-dev|-unstable)?)$" }, "browser" },
  { { class = "^([Tt]horium-browser|[Cc]achy-browser)$" }, "browser" },
  { { class = "^(zen-alpha|zen)$" }, "browser" },
  { { class = "^(swaync-control-center|swaync-notification-window|swaync-client|class)$" }, "notif" },
  { { class = "^(nwg-displays|nwg-look)$" }, "settings" },
  { { class = "^(Alacritty|kitty|kitty-dropterm)$" }, "terminal" },
  { { class = "^([Tt]hunderbird|org.gnome.Evolution)$" }, "email" },
  { { class = "^(eu.betterbird.Betterbird)$" }, "email" },
  { { class = "^(codium|codium-url-handler|VSCodium)$" }, "projects" },
  { { class = "^(VSCode|code|code-url-handler)$" }, "projects" },
  { { class = "^(jetbrains-.+)$" }, "projects" },
  { { class = "^(com.obsproject.Studio)$" }, "screenshare" },
  { { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" }, "im" },
  { { class = "^([Ff]erdium)$" }, "im" },
  { { class = "^([Ww]hatsapp-for-linux)$" }, "im" },
  { { class = "^(ZapZap|com.rtosta.zapzap)$" }, "im" },
  { { class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$" }, "im" },
  { { class = "^(teams-for-linux)$" }, "im" },
  { { class = "^(im.riot.Riot|Element)$" }, "im" },
  { { class = "^(gamescope)$" }, "games" },
  { { class = "^(steam_app_\\d+)$" }, "games" },
  { { class = "^([Ss]team)$" }, "gamestore" },
  { { title = "^([Ll]utris)$" }, "gamestore" },
  { { class = "^(com.heroicgameslauncher.hgl)$" }, "gamestore" },
  { { class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$" }, "file-manager" },
  { { class = "^(app.drey.Warp)$" }, "file-manager" },
  { { class = "^([Ww]aytrogen)$" }, "wallpaper" },
  { { class = "^([Aa]udacious)$" }, "multimedia" },
  { { class = "^([Mm]pv|vlc)$" }, "multimedia_video" },
  { { title = "^(ROG Control)$" }, "settings" },
  { { class = "^(wihotspot(-gui)?)$" }, "settings" },
  { { class = "^([Bb]aobab|org.gnome.[Bb]aobab)$" }, "settings" },
  { { class = "^(gnome-disks|wihotspot(-gui)?)$" }, "settings" },
  { { title = "(Kvantum Manager)" }, "settings" },
  { { class = "^(file-roller|org.gnome.FileRoller)$" }, "settings" },
  { { class = "^(nm-applet)$" }, "settings" },
  { { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" }, "settings" },
  { { class = "^(qt5ct|qt6ct|[Yy]ad)$" }, "settings" },
  { { class = "(xdg-desktop-portal-gtk)" }, "settings" },
  { { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, "settings" },
  { { class = "^([Rr]ofi)$" }, "settings" },
  { { class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$" }, "viewer" },
  { { class = "^(evince)$" }, "viewer" },
  { { class = "^(eog|org.gnome.Loupe)$" }, "viewer" },
}

for _, rule in ipairs(tag_rules) do
  wr(rule[1], { tag = "+" .. rule[2] })
end

wr({ tag = "multimedia_video" }, { no_blur = true, opacity = "1.0" })

wr({ class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" }, { center = true, float = true })
wr({ title = "^(ROG Control)$" }, { center = true })
wr({ tag = "settings" }, { center = true, float = true, opacity = "0.8 0.7", size = "(monitor_w*0.7) (monitor_h*0.7)" })
wr({ title = "^(Keybindings)$" }, { center = true })
wr({ class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" }, { center = true })
wr({ class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" }, { center = true, size = "(monitor_w*0.6) (monitor_h*0.7)" })
wr({ class = "^([Ff]erdium)$" }, { center = true, float = true, size = "(monitor_w*0.6) (monitor_h*0.7)" })
wr({ title = "^(Picture-in-Picture)$" }, { move = "72% 7%", float = true, opacity = "0.95 0.75", pin = true, keep_aspect_ratio = true })
wr({ class = "^(org.gnome.Calculator)$" }, { center = true, float = true, size = "(monitor_w*0.3) (monitor_h*0.7)" })
wr({ class = "^(blueman-manager)$" }, { center = true, float = true, size = "(monitor_w*0.4) (monitor_h*0.4)" })
wr({ class = "^(nm-connection-editor)$" }, { center = true, float = true, size = "(monitor_w*0.4) (monitor_h*0.4)" })
wr({ class = "^(LM Studio)$" }, { center = true, float = true })
wr({ class = "^(org.gnome.SystemMonitor)$" }, { center = true, size = "(monitor_w*0.5) (monitor_h*0.7)" })
wr({ fullscreen = true }, { idle_inhibit = "fullscreen" })

wr({ tag = "wallpaper" }, { float = true, opacity = "0.9 0.7", size = "(monitor_w*0.7) (monitor_h*0.7)" })
wr({ tag = "viewer" }, { float = true, opacity = "0.82 0.75" })
wr({ class = "([Zz]oom|onedriver|onedriver-launcher)" }, { float = true })
wr({ class = "^(mpv|com.github.rafostar.Clapper)$" }, { float = true })
wr({ class = "^([Qq]alculate-gtk)$" }, { float = true })
wr({ class = "^([Ss]potify)$" }, { float = true })
wr({ class = "^([Kk]itty-dropterm)$" }, { float = true, size = "(monitor_w*0.75) (monitor_h*0.6)" })
wr({ class = "^(org.gnome.Characters)$" }, { float = true })

wr({ title = "^(Authentication Required)$" }, { float = true, center = true })
wr({ class = "(codium|codium-url-handler|VSCodium)", title = "negative:(.*codium.*|.*VSCodium.*)" }, { float = true })
wr({ class = "^(com.heroicgameslauncher.hgl)$", title = "negative:(Heroic Games Launcher)" }, { float = true })
wr({ class = "^([Ss]team)$", title = "negative:^([Ss]team)$" }, { float = true })
wr({ title = "^(Add Folder to Workspace)$" }, { float = true, size = "(monitor_w*0.7) (monitor_h*0.6)", center = true })
wr({ title = "^(Save As)$" }, { float = true, size = "(monitor_w*0.7) (monitor_h*0.6)", center = true })
wr({ initial_title = "(Open Files)" }, { float = true, size = "(monitor_w*0.7) (monitor_h*0.6)" })
wr({ title = "^(SDDM Background)$" }, { float = true, center = true, size = "(monitor_w*0.16) (monitor_h*0.12)" })
wr({ class = "^(yad)$", title = "^(YAD)$" }, { float = true, center = true, size = "(monitor_w*0.2) (monitor_h*0.2)" })

wr({ tag = "browser" }, { opacity = "0.9 0.7" })
wr({ tag = "projects" }, { opacity = "0.9 0.8" })
wr({ tag = "im" }, { opacity = "0.94 0.86" })
wr({ tag = "multimedia" }, { opacity = "0.94 0.86" })
wr({ tag = "file-manager" }, { opacity = "0.9 0.8" })
wr({ tag = "terminal" }, { opacity = "0.9 0.7" })
wr({ class = "^(gedit|org.gnome.TextEditor|mousepad)$" }, { opacity = "0.8 0.7" })
wr({ class = "^(deluge)$" }, { opacity = "0.9 0.8" })
wr({ class = "^(seahorse)$" }, { opacity = "0.9 0.8" })

wr({ tag = "games" }, { no_blur = true, fullscreen = false })
wr({ class = "^(jetbrains-*)" }, { no_initial_focus = true })
wr({ title = "^(wind.*)$" }, { no_initial_focus = true })

hl.window_rule({
  name = "xwayland-video-bridge-fixes",
  match = { class = "xwaylandvideobridge" },
  no_initial_focus = true,
  no_focus = true,
  no_anim = true,
  no_blur = true,
  max_size = "1 1",
  opacity = "0.0",
})

lr("swaync-control-center", { blur = true })
lr("swaync-control-center", { ignore_alpha = 0 })
lr("swaync-control-center", { animation = "slidevert top 50%" })
lr("swaync-notification-window", { blur = true })
lr("swaync-notification-window", { ignore_alpha = 0 })
lr("waybar", { blur = true })
lr("waybar", { ignore_alpha = 0.5 })
lr("waybar", { blur_popups = true })
lr("quickshell", { blur = true })
lr("quickshell", { ignore_alpha = 0.3 })
lr("quickshell", { blur_popups = true })
lr("gtk-layer-shell", { blur = true })
lr("gtk-layer-shell", { ignore_alpha = 0 })
lr("gtk-layer-shell", { blur_popups = true })
lr("gtk-layer-shell", { animation = "popin 90%" })
lr("logout_dialog", { blur = true })
lr("logout_dialog", { ignore_alpha = 0.3 })

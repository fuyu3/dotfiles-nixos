-- vxwm.lua — Canvas mode para Hyprland 0.55+ (Lua config)
-- Adicione no seu config com: require("vxwm")
--
-- Requer: canvasd.py rodando como daemon
--   Inicie com: python3 ~/.config/hypr/canvasd.py &
--   Ou coloque no autostart do hyprland.lua:
--     hl.on("hyprland.start", function()
--         hl.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/hypr/canvasd.py")
--     end)
--
-- Binds:
--   mainMod + SHIFT + LMB hold  → pan (arrasta o canvas)
--   mainMod + LMB drag          → mover janela individualmente
--   mainMod + RMB drag          → redimensionar janela
--   mainMod + SHIFT + C         → toggle floating em todas as janelas do workspace
--   mainMod + Tab               → ciclar janelas (com autoraise)
--   mainMod + scroll            → scroll entre workspaces

local mainMod  = "SUPER"
local canvasctl = os.getenv("HOME") .. "/.config/hypr/canvasd.py"

-- ── Opções de comportamento ──────────────────────────────────────────────────

hl.config({
    general = {
        resize_on_border = true,
    },
    misc = {
        focus_on_activate   = true,
        mouse_move_enables_dpms = false,
    },
    input = {
        follow_mouse = 1,
    },
    binds = {
        drag_threshold = 5,
    },
})

-- ── Window rules ─────────────────────────────────────────────────────────────

-- Todas as janelas flutuantes (canvas mode)
-- hl.window_rule({
--     name  = "canvas-float",
--     match = { class = ".*" },
--     float = true,
-- })

-- Janelas novas abrem centradas
hl.window_rule({
    name   = "canvas-center",
    match  = { class = ".*" },
    center = true,
})

-- Suprime maximize (no canvas não faz sentido)
hl.window_rule({
    name           = "canvas-no-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix XWayland drag artifacts
hl.window_rule({
    match      = { class = "^$", title = "^$", xwayland = true,
                   float = true, fullscreen = false, pin = false },
    no_focus   = true,
})

-- ── Autoraise — janela focada sobe ao topo ──────────────────────────────────

hl.on("window.active", function(w)
    if w ~= nil then
        hl.dispatch(hl.dsp.window.bring_to_top())
    end
end)

-- ── Binds de mouse ───────────────────────────────────────────────────────────

-- mainMod + SHIFT + LMB press → inicia pan do canvas (daemon move todas as janelas)
hl.bind(mainMod .. " + SHIFT + mouse:272", function()
    os.execute("python3 " .. canvasctl .. " pan-start &")
end, { mouse = true })

-- mainMod + SHIFT + LMB release → para o pan
hl.bind(mainMod .. " + SHIFT + mouse:272", function()
    os.execute("python3 " .. canvasctl .. " pan-stop &")
end, { mouse = true, release = true })

-- ── Binds de teclado ─────────────────────────────────────────────────────────

-- Toggle canvas: converte todas as janelas do workspace para/de floating
hl.bind(mainMod .. " + SHIFT + C", function()
    local windows = hl.get_windows()
    if windows == nil then return end

    -- Verifica se há alguma janela tiled no workspace ativo
    local ws_active = nil
    for _, w in ipairs(windows) do
        if w.focus then
            ws_active = w.workspace
            break
        end
    end

    local has_tiled = false
    for _, w in ipairs(windows) do
        if w.workspace == ws_active and not w.floating then
            has_tiled = true
            break
        end
    end

    -- Se tem tiled → float todas; se todas já são float → tile todas
    local action = has_tiled and "enable" or "disable"
    for _, w in ipairs(windows) do
        if w.workspace == ws_active then
            hl.dispatch(hl.dsp.window.float({ action = action, window = w }))
        end
    end
end)



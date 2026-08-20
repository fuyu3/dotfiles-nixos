hl.config({
  input = {
    touchpad = {
      disable_while_typing = false
    },
    kb_layout = "us",
    kb_variant = "intl",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    repeat_rate = 50,
    repeat_delay = 300,
    sensitivity = 0,
    numlock_by_default = true,
    left_handed = false,
    follow_mouse = 1,
    float_switch_override_focus = false,
    tablet = {
      output = "HDMI-A-1",
      region_size = "1920 1080",
      transform = 1,
    },
  },
})

hl.device({ name = "mouse", sensitivity = -0.5 })

local c = HYPR

c.colors = {
  wallust_active_border_primary = "rgb(BE5E5F)",
  wallust_active_border_secondary = "rgb(E7E9E9)",
  wallust_inactive_border = "rgb(A4A5A5)",
  wallust_shadow = "rgb(3E3E3E)",
}

function c.load_wallust_colors()
  local path = c.dir .. "/wallust-colors.conf"
  local file = io.open(path, "r")
  if file == nil then
    return
  end

  for line in file:lines() do
    local key, value = line:match("^%s*%$([%w_]+)%s*=%s*(%S+)")
    if key ~= nil and value ~= nil then
      c.colors[key] = value
    end
  end

  file:close()
end

function c.window_rule(match, effects)
  effects.match = match
  hl.window_rule(effects)
end

function c.layer_rule(namespace, effects)
  effects.match = { namespace = namespace }
  hl.layer_rule(effects)
end

function c.shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function c.script_cmd(name, args)
  local command = c.shell_quote(c.dir .. "/" .. name)
  if args ~= nil and args ~= "" then
    command = command .. " " .. args
  end

  return command
end

c.load_wallust_colors()

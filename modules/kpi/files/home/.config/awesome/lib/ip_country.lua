-- create text widget. update it with command result every 5 minutes:
-- xh ifconfig.co/json | jq .country_iso

local wibox = require("wibox")
local awful = require("awful")
local watch = require("awful.widget.watch")

local ip_country_widget = wibox.widget.textbox()
ip_country_widget.text = "??"
ip_country_widget.font = default_font


function set_country(country_code)
   if country_code == 'BY' then
      iso_code = '🇧🇾'
   else
      iso_code = '🌍' .. country_code
   end
   ip_country_widget:set_text('|' .. iso_code .. '|')
end

function refresh_country()
   -- wait for nordvpn to connect
   -- sleep 5 seconds
   ip_country_widget:set_text('??')
   awful.spawn.easy_async('bash -c "sleep 3 && xh GET ifconfig.co/json | jq -r .country_iso"', function(stdout, stderr, exitreason, exitcode)
      if exitcode == 0 then
         set_country(string.sub(stdout, 1, 2))
      else
         ip_country_widget:set_text("ERROR1 " .. exitcode .. " " .. stderr)
      end
   end)
end

function init_widget()
  awful.widget.watch('bash -c "xh GET ifconfig.co/json | jq -r .country_iso"', 300, function(widget, stdout, stderr, exitreason, exitcode)
     if exitcode == 0 then
        set_country(string.sub(stdout, 1, 2))
     else
        widget:set_text("ERROR2 " .. exitcode .. " " .. stderr)
     end
  end, ip_country_widget)
  -- on click
  ip_country_widget:connect_signal("button::press", function(_, _, _, button)
     if button == 1 then
        awful.spawn.with_shell('bash -c "nordvpn status | ag Connecte && nordvpn disconnect || nordvpn connect lt"')
        -- refresh state async
        refresh_country()
     end
  end)
  return ip_country_widget
end

return setmetatable(ip_country_widget, { __call = function(_, ...) return init_widget(...) end })

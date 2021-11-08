function change(op)
   os.execute('xbacklight -'..op..' 10')
end

function inc_brightness()
   change('inc')
end

function dec_brightness()
   change('dec')
end


function change_vol(op)
   os.execute('pactl set-sink-volume 0 '..op..'5%')
end

function inc_volume()
   change_vol('+')
end

function dec_volume()
   change_vol('-')
end

function toggle_volume()
   os.execute('pactl set-sink-mute 0 toggle')
end

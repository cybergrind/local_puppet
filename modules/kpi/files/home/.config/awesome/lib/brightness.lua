function change(op)
   os.execute('xbacklight -'..op..' 10')
end

function inc_brightness()
   change('inc')
end

function dec_brightness()
   change('dec')
end


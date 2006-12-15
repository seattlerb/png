#!/usr/local/bin/ruby -w

require 'png'

canvas = PNG::Canvas.new 1024, 1024, PNG::Color::Black

#canvas.each do |x, y|
#  case x
#  when y then
#    canvas.point(x, y, Color::Black)
#  when 50 then
#    canvas.point(x, y, Color::Background)
#  end
#  canvas.point(x, y, Color::Green) if y = 200
#end

canvas.line  50,  50, 100,  50, PNG::Color::Blue
canvas.line  50,  50,  50, 100, PNG::Color::Blue
canvas.line 100,  50, 150, 100, PNG::Color::Blue
canvas.line 100,  50, 125, 100, PNG::Color::Green # currently wrong
canvas.line 100,  50, 200,  75, PNG::Color::Green # currently wrong
canvas.line   0, 200, 200,   0, PNG::Color::Black

png = PNG.new canvas
png.save 'blah.png'
`open blah.png`


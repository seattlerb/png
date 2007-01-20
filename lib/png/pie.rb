#!/usr/local/bin/ruby -w

require 'png'

##
# Makes a pie chart you can pass to PNG.new:
#
#   png = PNG.new pie_chart(250, 0.30)
#   png.save "pie.png"
#   system 'open pie.png'

def PNG.pie_chart(diameter, pct_green)
  diameter += 1 if diameter % 2 == 0
  radius = (diameter / 2.0).to_i
  pct_in_deg = 360.0 * pct_green

  canvas = PNG::Canvas.new(diameter, diameter, PNG::Color::Background)
  red = PNG::Color::Red
  grn = PNG::Color::Green
  rad_to_deg = 180.0 / Math::PI

  (-radius..radius).each do |x|
    (-radius..radius).each do |y|
      magnitude = Math.sqrt(x*x + y*y)
      if magnitude <= radius then
        angle = (Math.atan2(y, x) + Math::PI) * rad_to_deg
        rx, ry = x+radius, y+radius
        color = (angle <= pct_in_deg ? grn : red)

        canvas[ rx, -ry ] = color # x and y seem to be swapped?
      end
    end
  end

  PNG.new canvas
end


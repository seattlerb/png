= png

== About

png is an almost-pure-ruby PNG library.  It lets you write a PNG without any C
libraries.  It might be a bit "slow", especially if you don't have a C
compiler.

== Installing png

Just install the gem:

  $ sudo gem install png

== Using png

  require 'png'
  
  canvas = PNG::Canvas.new 200, 200
  
  # Set a point to a color
  canvas[100, 100] = PNG::Color::Black
  
  # draw an anti-aliased line
  canvas.line 50, 50, 100, 50, PNG::Color::Blue
  
  png = PNG.new canvas
  png.save 'blah.png'


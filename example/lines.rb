#!/usr/local/bin/ruby -w

require "png"
require "png/font"

canvas = PNG::Canvas.new 201, 201, PNG::Color::White

canvas.line  50,  50, 100,  50, PNG::Color::Blue
canvas.line  50,  50,  50, 100, PNG::Color::Blue
canvas.line 100,  50, 150, 100, PNG::Color::Blue
canvas.line 100,  50, 125, 100, PNG::Color::Green
canvas.line 100,  50, 200,  75, PNG::Color::Green
canvas.line   0, 200, 200,   0, PNG::Color::Black
canvas.line   0, 200, 150,   0, PNG::Color::Red

canvas.annotate "Hello World", 10, 10

png = PNG.new canvas
png.save "blah.png"
`open blah.png`

require "png/reader"

##
# Implements a simple bitmap font by extracting letters from a PNG.

class PNG::Font
  LETTERS = (("A".."Z").to_a +
             ("a".."z").to_a +
             ("0".."9").to_a + [" "] * 16 +
             '({[<!@#$%^&*?_+-=;,"/~>]})'.split(//))

  attr_reader :height, :width, :canvas

  def self.default
    @@default ||= new(File.join(File.dirname(__FILE__), "default_font.png"))
  end

  def initialize png_file
    @canvas = PNG.load_file png_file
    @height, @width = canvas.height / 4, canvas.width / 26
    @cache = {}
  end

  def coordinates c
    i = LETTERS.index c

    raise ArgumentError, "Can't find #{c.inspect}" unless i

    x = (i % 26) * width
    y = (3 - (i / 26)) * height # start from the top (3rd row)

    return x, y, x+width-1, y+height-1
  end

  def [] c
    c = c.chr unless String === c
    x0, y0, x1, y1 = coordinates c

    @cache[c] ||= @canvas.extract(x0, y0, x1, y1)
  end
end

class PNG::Canvas
  ##
  # Write a string at [x, y] with font, optionally specifying a font,
  # an alignment of :left, :center, or :right and the style to draw
  # the annotation (see #composite).
  #
  #   require 'png/font'

  def annotate string, x, y,
               font = PNG::Font.default, align = :left, style = :overwrite
    case align
    when :left then
      # do nothing
    when :center then
      x -= string.length * font.width / 2
    when :right then
      x -= string.length * font.width
    else
      raise ArgumentError, "Unknown align: #{align.inspect}"
    end

    x_offset, width = 0, font.width

    string.split(//).each do |char|
      self.composite font[char], x + x_offset, y
      x_offset += width
    end
  end
end

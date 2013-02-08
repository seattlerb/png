# encoding: BINARY

require 'rubygems'
require 'zlib'
require 'inline'

unless "".respond_to? :getbyte then
  class String
    alias :getbyte :[]
  end
end

class String # :nodoc: # ZenTest SKIP
  inline do |builder|
    builder.c <<-EOM
      unsigned long png_crc() {
        static unsigned long crc[256];
        static char crc_table_computed = 0;
        unsigned long c = 0xffffffff;
        size_t   len    = RSTRING_LEN(self);
        char * s        = StringValuePtr(self);
        unsigned i;

        if (! crc_table_computed) {
          unsigned long c;
          int n, k;

          for (n = 0; n < 256; n++) {
            c = (unsigned long) n;
            for (k = 0; k < 8; k++) {
              c = (c & 1) ? 0xedb88320L ^ (c >> 1) : c >> 1;
            }
            crc[n] = c;
          }
          crc_table_computed = 1;
        }

        for (i = 0; i < len; i++) {
          c = crc[(c ^ s[i]) & 0xff] ^ (c >> 8);
        }

        return c ^ 0xffffffff;
      }
    EOM
  end
rescue CompilationError => e
  warn "COMPLIATION ERROR: #{e}"

  unless defined? @@crc then
    @@crc = Array.new(256)
    256.times do |n|
      c = n
      8.times do
        c = (c & 1 == 1) ? 0xedb88320 ^ (c >> 1) : c >> 1
      end
      @@crc[n] = c
    end
  end

  ##
  # Calculates a CRC using the algorithm in the PNG specification.

  def png_crc()
    c = 0xffffffff
    each_byte do |b|
      c = @@crc[(c^b) & 0xff] ^ (c >> 8)
    end
    return c ^ 0xffffffff
  end
end

##
# An almost-pure-ruby Portable Network Graphics (PNG) writer.
#
# http://www.libpng.org/pub/png/spec/1.2/
#
# PNG supports:
# + 8 bit truecolor PNGs
#
# PNG does not support:
# + any other color depth
# + extra data chunks
# + filters
#
# = Example
#
#   require 'png'
#
#   canvas = PNG::Canvas.new 200, 200
#   canvas[100, 100] = PNG::Color::Black
#   canvas.line 50, 50, 100, 50, PNG::Color::Blue
#   png = PNG.new canvas
#   png.save 'blah.png'
#
# = TODO:
#
# + Get everything orinted entirely on [x,y,h,w] with x,y origin being
#   bottom left.

class PNG
  VERSION = '1.2.0'
  SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

  # Color Types:
  GRAY    = 0 # DEPTH = 1,2,4,8,16
  RGB     = 2 # DEPTH = 8,16
  INDEXED = 3 # DEPTH = 1,2,4,8
  GRAYA   = 4 # DEPTH = 8,16
  RGBA    = 6 # DEPTH = 8,16

  # Filter Types:
  NONE    = 0
  SUB     = 1
  UP      = 2
  AVG     = 3
  PAETH   = 4

  begin
    inline do |builder|
      if RUBY_VERSION < "1.8.6" then
        builder.prefix <<-EOM
          #define RARRAY_PTR(s) (RARRAY(s)->ptr)
          #define RARRAY_LEN(s) (RARRAY(s)->len)
        EOM
      end

      builder.c <<-EOM
        VALUE png_join() {
          size_t i, j;
          VALUE  data     = rb_iv_get(self, "@data");
          size_t data_len = RARRAY_LEN(data);
          size_t row_len  = RARRAY_LEN(RARRAY_PTR(data)[0]);
          size_t size     = data_len * (1 + (row_len * 4));
          char * result   = malloc(size);

          unsigned long idx = 0;
          for (i = 0; i < data_len; i++) {
            VALUE row = RARRAY_PTR(data)[i];
            result[idx++] = 0;
            for (j = 0; j < row_len; j++) {
              VALUE color = RARRAY_PTR(row)[j];
              VALUE values = rb_iv_get(color, "@values");
              char * value = StringValuePtr(values);
              result[idx++] = value[0];
              result[idx++] = value[1];
              result[idx++] = value[2];
              result[idx++] = value[3];
            }
          }
          return rb_str_new(result, size);
        }
      EOM
    end
  rescue CompilationError
    def png_join
      @data.map { |row| "\0" + row.map { |p| p.values }.join }.join
    end
  end

  ##
  # Creates a PNG chunk of type +type+ that contains +data+.

  def self.chunk(type, data="")
    [data.size, type, data, (type + data).png_crc].pack("Na*a*N")
  end

  ##
  # Creates a new PNG object using +canvas+

  def initialize(canvas)
    @height = canvas.height
    @width = canvas.width
    @bits = 8
    @data = canvas.data
  end

  ##
  # Writes the PNG to +path+.

  def save(path)
    File.open path, 'wb' do |f|
      f.write to_blob
    end
  end

  ##
  # Raw PNG data

  def to_blob
    blob = []

    header = [@width, @height, @bits, RGBA, NONE, NONE, NONE]

    blob << SIGNATURE
    blob << PNG.chunk('IHDR', header.pack("N2C5"))
    blob << PNG.chunk('IDAT', Zlib::Deflate.deflate(self.png_join))
    blob << PNG.chunk('IEND', '')
    blob.join
  end

  ##
  # A 32 bit RGBA color. Can be created from RGB or RGBA via #new,
  # numeric value or hex string via #from, or HSV via #from_hsv.

  class Color

    MAX=255

    attr_reader :values

    ##
    # Create a new color from a string or integer value. Can take an
    # optional name as well.

    def self.from str, name = nil
      str = "%08x" % str if Integer === str
      colors = str.scan(/[\da-f][\da-f]/i).map { |n| n.hex }
      colors << name
      self.new(*colors)
    end

    ##
    # Creates a new color with values +red+, +green+, +blue+, and +alpha+.

    def initialize red, green, blue, alpha = MAX, name = nil
      @values = "%c%c%c%c" % [red, green, blue, alpha]
      @name = name
    end

    ##
    # Transparent white

    Background = Color.from 0x00000000, "Transparent"
    Black      = Color.from 0x000000FF, "Black"
    Blue       = Color.from 0x0000FFFF, "Blue"
    Brown      = Color.from 0x996633FF, "Brown"
    Bubblegum  = Color.from 0xFF66FFFF, "Bubblegum"
    Cyan       = Color.from 0x00FFFFFF, "Cyan"
    Gray       = Color.from 0x7F7F7FFF, "Gray"
    Green      = Color.from 0x00FF00FF, "Green"
    Magenta    = Color.from 0xFF00FFFF, "Magenta"
    Orange     = Color.from 0xFF7F00FF, "Orange"
    Purple     = Color.from 0x7F007FFF, "Purple"
    Red        = Color.from 0xFF0000FF, "Red"
    White      = Color.from 0xFFFFFFFF, "White"
    Yellow     = Color.from 0xFFFF00FF, "Yellow"

    def == other # :nodoc:
      self.class === other and other.values == values
    end

    alias :eql? :==

    ##
    # "Bitwise or" as applied to colors. Background color is
    # considered false.

    def | o
      self == Background ? o : self
    end

    def hash # :nodoc:
      self.values.hash
    end

    ##
    # Return an array of RGB

    def rgb # TODO: rgba?
      return r, g, b
    end

    ##
    # Red component

    def r; @values.getbyte 0; end

    ##
    # Green component

    def g; @values.getbyte 1; end

    ##
    # Blue component

    def b; @values.getbyte 2; end

    ##
    # Alpha transparency component

    def a; @values.getbyte 3; end

    ##
    # Blends +color+ into this color returning a new blended color.

    def blend color
      return Color.new(((r + color.r) / 2), ((g + color.g) / 2),
                       ((b + color.b) / 2), ((a + color.a) / 2))
    end

    ##
    # Returns a new color with an alpha value adjusted by +i+.

    def intensity i
      return Color.new(r,g,b,(a*i) >> 8)
    end

    def inspect # :nodoc:
      if @name then
        "#<%s %s>" % [self.class, @name]
      else
        "#<%s %02x %02x %02x %02x>" % [self.class, r, g, b, a]
      end
    end

    ##
    # An ASCII representation of this color, almost suitable for making ASCII
    # art!

    def to_ascii
      return '  ' if a == 0x00

      brightness = (((r + g + b) / 3) * a) / 0xFF

      %w(.. ,, ++ 00)[brightness / 64]
    end

    def to_s # :nodoc:
      if @name then
        @name
      else
        super
      end
    end

    ##
    # Creates a new RGB color from HSV equivalent values.

    def self.from_hsv h, s, v
      r = g = b = v # gray
      unless s == 0.0 then
        h += 255 if h < 0
        h  = h / 255.0 * 6.0
        s  = s / 255.0
        v  = v / 255.0
        i  = h.floor
        f  = h - i
        p = v * (1 - (s))
        q = v * (1 - (s * (f)))
        w = v * (1 - (s * (1-f)))
        r, g, b = case i
                  when 0,6 then
                    [ v, w, p ]
                  when 1 then
                    [ q, v, p ]
                  when 2 then
                    [ p, v, w ]
                  when 3 then
                    [ p, q, v ]
                  when 4 then
                    [ w, p, v ]
                  when 5 then
                    [ v, p, q ]
                  else
                    raise [h, s, v, i, f, p, q, w].inspect
                  end
      end
      self.new((r * 255).round, (g * 255).round, (b * 255).round)
    end

    ##
    # Returns HSV equivalent of the current color.

    def to_hsv # errors = 54230 out of 255^3 are off by about 1 on r, g, or b
      rgb = self.rgb
      r, g, b = rgb
      h, s, v = 0, 0, rgb.max

      return h, s, v if v == 0

      range = v - rgb.min
      s = 255 * range / v

      return h, s, v if s == 0

      h = case v
          when r then
            0x00 + 43 * (g - b) / range # 43 = 1/4 of 360 scaled to 255
          when g then
            0x55 + 43 * (b - r) / range
          else
            0xAA + 43 * (r - g) / range
          end

      return h.round, s.round, v.round
    end
  end # Color

  ##
  # A canvas used for drawing images. Origin is 0, 0 in the bottom
  # left corner.

  class Canvas

    ##
    # Height of the canvas

    attr_reader :height

    ##
    # Width of the canvas

    attr_reader :width

    ##
    # Raw data

    attr_reader :data

    def initialize width, height, background = Color::Background
      @width = width
      @height = height
      @data = Array.new(@height) { |x| Array.new(@width, background) }
    end

    ##
    # Retrieves the color of the pixel at (+x+, +y+).

    def [] x, y
      raise "bad x value #{x} >= #{@width}" if x >= @width
      raise "bad y value #{y} >= #{@height}" if y >= @height
      @data[@height-y-1][x]
    end

    ##
    # Sets the color of the pixel at (+x+, +y+) to +color+.

    def []= x, y, color
      raise "bad x value #{x} >= #{@width}" if x >= @width
      raise "bad y value #{y} >= #{@height}"  if y >= @height
      raise "bad color #{color.inspect}" unless color.kind_of? PNG::Color
      @data[@height-y-1][x] = color
    end

    ##
    # Composites another canvas onto self at the given (bottom left) coordinates.

    def composite canvas, x, y, style = :overwrite
      canvas.each do |x1, y1, color|
        case style
        when :overwrite then
          self[x+x1, y+y1] = color
        when :add, :underlay then
          self[x+x1, y+y1] = self[x+x1, y+y1] | color
        when :overlay then
          self[x+x1, y+y1] = color | self[x+x1, y+y1]
        when :blend then
          self.point x+x1, y+y1, color
        else
          raise "unknown style for composite: #{style.inspect}"
        end
      end
    end

    ##
    # Iterates over the canvas yielding x, y, and color.

    def each
      data.reverse.each_with_index do |row, y|
        row.each_with_index do |color, x|
          yield x, y, color
        end
      end
    end

    ##
    # Create a new canvas copying a region of the current canvas

    def extract x0, y0, x1, y1
      canvas = Canvas.new(x1-x0+1, y1-y0+1)

      (x0..x1).each_with_index do |x2, x3|
        (y0..y1).each_with_index do |y2, y3|
          canvas[x3, y3] = self[x2, y2]
        end
      end

      canvas
    end

    def inspect # :nodoc:
      '#<%s %dx%d>' % [self.class, @width, @height]
    end

    ##
    # Blends +color+ onto the color at point (+x+, +y+).

    def point(x, y, color)
      self[x,y] = self[x,y].blend(color)
    end

    ##
    # Draws a line using Xiaolin Wu's antialiasing technique.
    #
    # http://en.wikipedia.org/wiki/Xiaolin_Wu's_line_algorithm

    def line(x0, y0, x1, y1, color)
      y0, y1, x0, x1 = y1, y0, x1, x0 if y0 > y1
      dx = x1 - x0
      sx = dx < 0 ? -1 : 1
      dx *= sx
      dy = y1 - y0

      # 'easy' cases
      if dy == 0 then
        Range.new(*[x0,x1].sort).each do |x|
          point(x, y0, color)
        end
        return
      end

      if dx == 0 then
        (y0..y1).each do |y|
          point(x0, y, color)
        end
        return
      end

      if dx == dy then
        x0.step(x1, sx) do |x|
          point(x, y0, color)
          y0 += 1
        end
        return
      end

      # main loop
      point(x0, y0, color)
      e_acc = 0
      if dy > dx then # vertical displacement
        e = (dx << 16) / dy
        (y0...y1-1).each do |i|
          e_acc_temp, e_acc = e_acc, (e_acc + e) & 0xFFFF
          x0 = x0 + sx if (e_acc <= e_acc_temp)
          w = 0xFF-(e_acc >> 8)
          point(x0, y0, color.intensity(w))
          y0 = y0 + 1
          point(x0 + sx, y0, color.intensity(0xFF-w))
        end
        point(x1, y1, color)
        return
      end

      # horizontal displacement
      e = (dy << 16) / dx
      (dx - 1).downto(0) do |i|
        e_acc_temp, e_acc = e_acc, (e_acc + e) & 0xFFFF
        y0 += 1 if (e_acc <= e_acc_temp)
        w = 0xFF-(e_acc >> 8)
        point(x0, y0, color.intensity(w))
        x0 += sx
        point(x0, y0 + 1, color.intensity(0xFF-w))
      end
      point(x1, y1, color)
    end

    ##
    # Returns an ASCII representation of this image

    def to_s
      image = []
      scale = (@width / 39) + 1

      @data.each_with_index do |row, x|
        next if x % scale != 0
        row.each_with_index do |color, y|
          next if y % scale != 0
          image << color.to_ascii
        end
        image << "\n"
      end

      return image.join
    end
  end # Canvas
end

require 'zlib'
require 'enumerator'

class Array # :nodoc:

  require 'inline'

  inline do |builder|
    builder.include '"intern.h"'

    builder.c <<-EOC
      static void
      fast_flatten() {
        VALUE flat, row, pixel;
        long total_length, height, width, cur = 0, x = 0, y = 0;

        height = RARRAY(self)->len;
        width = RARRAY(RARRAY(self)->ptr[0])->len;
        total_length = height * (width - 1) * 4 + height; /* data + filter */

        flat = rb_ary_new2(total_length);

        for (x = 0; x < height; x++) {
          row = RARRAY(self)->ptr[x];

          pixel = RARRAY(row)->ptr[0]; /* row filter */
          MEMCPY(RARRAY(flat)->ptr + cur, &pixel, VALUE, 1);
          cur++;

          for (y = 1; y < width; y++) { /* row data */
            pixel = RARRAY(row)->ptr[y];
            MEMCPY(RARRAY(flat)->ptr + cur, RARRAY(pixel)->ptr, VALUE, 4);
            cur += 4;
          }
        }
        RARRAY(flat)->len = total_length;
        return flat;
      }
    EOC

    builder.c <<-EOC
      static void
      fast_pack() {
        VALUE res;
        long i;
        char c;

        res = rb_str_buf_new(RARRAY(self)->len);

        for (i = 0; i < RARRAY(self)->len; i++) {
          c = FIX2LONG(RARRAY(self)->ptr[i]);
          rb_str_buf_cat(res, &c, sizeof(char));
        }

        return res;
      }
    EOC
  end

rescue StandardError, LoadError
  
  def fast_pack
    pack 'C*'
  end

  def fast_flatten
    flatten
  end

end

class String # :nodoc:

  ##
  # Calculates a CRC using the algorithm in the PNG specification.

  def png_crc
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
# = Note
#
# PNG will drop back to a pure-ruby implementation if the
# RubyInline-accelerated methods in Array fail to compile.

class PNG

  SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

  ##
  # Creates a PNG chunk of type +type+ that contains +data+.

  def self.chunk(type, data="")
    [data.size, type, data, (type + data).png_crc].pack("Na*a*N")
  end

  def self.load(png)
    png = png.dup
    signature = png.slice! 0, 8
    raise ArgumentError, 'invalid PNG signature' unless signature == SIGNATURE

    type, data = read_chunk png

    raise ArgumentError, 'invalid PNG, no IHDR chunk' unless type == 'IHDR'

    canvas = read_IHDR data
    type, data = read_chunk png
    read_IDAT data, canvas
    type, data = read_chunk png
    raise 'oh no! IEND not next? crashing and burning!' unless type == 'IEND'

    new canvas
  end

  def self.check_crc(type, data, crc)
    return true if (type + data).png_crc == crc
    raise ArgumentError, "invalid CRC encountered in #{type} chunk" 
  end

  def self.paeth(a, b, c) # left, above, upper left
    #puts "paeth %p" % [[a, b, c]]
    p = a + b - c
    pa = (p - a).abs
    pb = (p - b).abs
    pc = (p - c).abs

    #puts "paethb %p" % [[pa, pb, pc]]
    return a if pa <= pb && pa <= pc
    return b if pb <= pc
    c
  end

  def self.read_chunk(png)
    size, type = png.slice!(0, 8).unpack 'Na4'
    data, crc = png.slice!(0, size + 4).unpack "a#{size}N"

    check_crc type, data, crc

    return type, data
  end

  def self.read_IDAT(data, canvas)
    data = Zlib::Inflate.inflate(data).unpack 'C*'
    scanline_length = 4 * canvas.width + 1 # for filter
    row = 0
    until data.empty? do
      row_data = data.slice! 0, scanline_length
      filter = row_data.shift
      puts "row #{row} filter #{filter}"
      case filter
      when 0 then # None
      when 1 then # Sub
        row_data.each_with_index do |byte, index|
          left = index < 4 ? 0 : row_data[index - 4]
          row_data[index] = (byte + left) % 256
          #p [byte, left, row_data[index]]
        end
      when 2 then # Up
        row_data.each_with_index do |byte, index|
          col = index / 4
          upper = row == 0 ? 0 : canvas[col, row - 1].values[index % 4]
          row_data[index] = (upper + byte) % 256
        end
      when 3 then # Average
        row_data.each_with_index do |byte, index|
          col = index / 4
          upper = row == 0 ? 0 : canvas[col, row - 1].values[index % 4]
          left = index < 4 ? 0 : row_data[index - 4]

          row_data[index] = (byte + ((left + upper)/2).floor) % 256
        end
      when 4 then # Paeth
        left = upper = upper_left = nil
        row_data.each_with_index do |byte, index|
          col = index / 4

          left = index < 4 ? 0 : row_data[index - 4]
          if row == 0 then
            upper = upper_left = 0
          else
            upper = canvas[col, row - 1].values[index % 4]
            upper_left = col == 0 ? 0 :
                           canvas[col - 1, row - 1].values[index % 4]
          end

          paeth = paeth left, upper, upper_left
          row_data[index] = (byte + paeth) % 256
          #p [byte, paeth, row_data[index]]
        end
      else
        raise ArgumentError, "invalid filter algorithm #{filter}"
      end

      col = 0
      row_data.each_slice 4 do |slice|
        p slice
        canvas[col, row] = PNG::Color.new(*slice)
        col += 1
      end

      row += 1
    end
  end

  def self.read_IHDR(data)
    width, height, *rest = data.unpack 'N2C5'
    raise ArgumentError, 'unsupported PNG file' unless rest == [8, 6, 0, 0, 0]
    return PNG::Canvas.new(width, height)
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
    File.open path, 'wb' do |f| f.write to_blob end
  end

  ##
  # Raw PNG data

  def to_blob
    blob = []
    blob << SIGNATURE

    blob << PNG.chunk('IHDR',
                      [ @height, @width, @bits, 6, 0, 0, 0 ].pack("N2C5"))
    # 0 == filter type code "none"
    data = @data.map { |row| [0] + row.map { |p| p.values } }.fast_flatten
    blob << PNG.chunk('IDAT', Zlib::Deflate.deflate(data.fast_pack, 9))
    blob << PNG.chunk('IEND', '')
    blob.join
  end

  ##
  # RGBA colors

  class Color

    attr_reader :values

    ##
    # Creates a new color with values +red+, +green+, +blue+, and +alpha+.

    def initialize(red, green, blue, alpha)
      @values = [red, green, blue, alpha]
    end

    ##
    # Transparent white

    Background = Color.new 0xFF, 0xFF, 0xFF, 0x00
 
    White      = Color.new 0xFF, 0xFF, 0xFF, 0xFF
    Black      = Color.new 0x00, 0x00, 0x00, 0xFF
    Gray       = Color.new 0x7F, 0x7F, 0x7F, 0xFF

    Red        = Color.new 0xFF, 0x00, 0x00, 0xFF
    Orange     = Color.new 0xFF, 0xA5, 0x00, 0xFF
    Yellow     = Color.new 0xFF, 0xFF, 0x00, 0xFF
    Green      = Color.new 0x00, 0xFF, 0x00, 0xFF
    Blue       = Color.new 0x00, 0x00, 0xFF, 0xFF
    Purple     = Color.new 0XFF, 0x00, 0xFF, 0xFF

    def ==(other) # :nodoc:
      self.class === other and other.values == values
    end

    ##
    # Red component

    def r; @values[0]; end

    ##
    # Green component

    def g; @values[1]; end

    ##
    # Blue component

    def b; @values[2]; end

    ##
    # Alpha transparency component

    def a; @values[3]; end

    ##
    # Blends +color+ into this color returning a new blended color.

    def blend(color)
      return Color.new((r * (0xFF - color.a) + color.r * color.a) >> 8,
                       (g * (0xFF - color.a) + color.g * color.a) >> 8,
                       (b * (0xFF - color.a) + color.b * color.a) >> 8,
                       (a * (0xFF - color.a) + color.a * color.a) >> 8)
    end

    ##
    # Returns a new color with an alpha value adjusted by +i+.

    def intensity(i)
      return Color.new(r,g,b,(a*i) >> 8)
    end

    def inspect # :nodoc:
      "#<%s %02x %02x %02x %02x>" % [self.class, *@values]
    end

    ##
    # An ASCII representation of this color, almost suitable for making ASCII
    # art!

    def to_ascii
      brightness = (((r + g + b) / 3) * a) / 0xFF
      return '00' if brightness >= 0xc0
      return '++' if brightness >= 0x7F
      return ',,' if brightness >= 0x40
      return '..'
    end

  end

  ##
  # PNG canvas

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

    def initialize(height, width, background = Color::White)
      @height = height
      @width = width
      @data = Array.new(@width) { |x| Array.new(@height) { background } }
    end

    ##
    # Retrieves the color of the pixel at (+x+, +y+).

    def [](x, y)
      raise "bad x value #{x} >= #{@height}" if x >= @height
      raise "bad y value #{y} >= #{@width}" if y >= @width
      @data[y][x]
    end

    ##
    # Sets the color of the pixel at (+x+, +y+) to +color+.

    def []=(x, y, color)
      raise "bad x value #{x} >= #{@height}" if x >= @height
      raise "bad y value #{y} >= #{@width}"  if y >= @width
      @data[y][x] = color
    end

    ##
    # Iterates over each pixel in the canvas.

    def each
      @data.each_with_index do |row, y|
        row.each_with_index do |color, x|
          yield x, y, color
        end
      end
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
      dx = x1 - x0
      sx = dx < 0 ? -1 : 1
      dx *= sx # TODO: abs?
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
        Range.new(*[x0,x1].sort).each do |x|
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
      (x0...(x1-sx)).each do |i|
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

  end

end


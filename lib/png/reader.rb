require 'png'
require 'enumerator'

class PNG
  def self.load_file path, metadata_only = false
    self.load File.read(path), metadata_only
  end

  def self.load png, metadata_only = false
    png = png.dup
    signature = png.slice! 0, 8
    raise ArgumentError, 'Invalid PNG signature' unless signature == SIGNATURE

    ihdr = read_chunk 'IHDR', png

    bit_depth, color_type, width, height = read_IHDR ihdr, metadata_only

    return [width, height, bit_depth] if metadata_only

    canvas = PNG::Canvas.new width, height

    type = png.slice(4, 4).unpack('a4').first
    read_chunk type, png if type == 'iCCP' # Ignore color profile

    read_IDAT read_chunk('IDAT', png), bit_depth, color_type, canvas
    read_chunk 'IEND', png

    canvas
  end

  def self.read_chunk expected_type, png
    size, type = png.slice!(0, 8).unpack 'Na4'
    data, crc = png.slice!(0, size + 4).unpack "a#{size}N"

    check_crc type, data, crc

    raise ArgumentError, "Expected #{expected_type} chunk, not #{type}" unless
      type == expected_type

    return data
  end

  def self.check_crc type, data, crc
    return true if (type + data).png_crc == crc
    raise ArgumentError, "Invalid CRC encountered in #{type} chunk"
  end

  def self.read_IHDR data, metadata_only = false
    width, height, bit_depth, color_type, *rest = data.unpack 'N2C5'

    unless metadata_only then
      raise ArgumentError, "Wrong bit depth: #{bit_depth}" unless
        bit_depth == 8
      raise ArgumentError, "Wrong color type: #{color_type}" unless
        color_type == RGBA or color_type = RGB
      raise ArgumentError, "Unsupported options: #{rest.inspect}" unless
        rest == [0, 0, 0]
    end

    return bit_depth, color_type, width, height
  end

  def self.read_IDAT data, bit_depth, color_type, canvas
    data = Zlib::Inflate.inflate(data).unpack 'C*'

    pixel_size = color_type == RGBA ? 4 : 3

    height = canvas.height
    scanline_length = pixel_size * canvas.width + 1 # for filter

    row = canvas.height - 1
    until data.empty? do
      row_data = data.slice! 0, scanline_length

      filter = row_data.shift
      case filter
      when NONE then
      when SUB then
        row_data.each_with_index do |byte, index|
          left = index < pixel_size ? 0 : row_data[index - pixel_size]
          row_data[index] = (byte + left) % 256
        end
      when UP then
        row_data.each_with_index do |byte, index|
          col = index / pixel_size
          upper = row == 0 ? 0 : canvas[col, row + 1].values[index % pixel_size]
          row_data[index] = (upper + byte) % 256
        end
      when AVG then
        row_data.each_with_index do |byte, index|
          col = index / pixel_size
          upper = row == 0 ? 0 : canvas[col, row + 1].values[index % pixel_size]
          left = index < pixel_size ? 0 : row_data[index - pixel_size]

          row_data[index] = (byte + ((left + upper)/2).floor) % 256
        end
      when PAETH then
        left = upper = upper_left = nil
        row_data.each_with_index do |byte, index|
          col = index / pixel_size

          left = index < pixel_size ? 0 : row_data[index - pixel_size]
          if row == height then
            upper = upper_left = 0
          else
            upper = canvas[col, row + 1].values[index % pixel_size]
            upper_left = col == 0 ? 0 :
              canvas[col - 1, row + 1].values[index % pixel_size]
          end

          paeth = paeth left, upper, upper_left
          row_data[index] = (byte + paeth) % 256
        end
      else
        raise ArgumentError, "invalid filter algorithm #{filter}"
      end

      col = 0
      row_data.each_slice pixel_size do |slice|
        slice << 0xFF if pixel_size == 3
        canvas[col, row] = PNG::Color.new(*slice)
        col += 1
      end

      row -= 1
    end
  end

  def self.paeth a, b, c # left, above, upper left
    p = a + b - c
    pa = (p - a).abs
    pb = (p - b).abs
    pc = (p - c).abs

    return a if pa <= pb && pa <= pc
    return b if pb <= pc
    c
  end
end

require 'test/unit'
require 'rubygems'

require 'test/test_png'
require 'png/reader'

class TestPngReader < Test::Unit::TestCase

  def setup
    @canvas = PNG::Canvas.new 5, 10, PNG::Color::White
    @png = PNG.new @canvas

    @IHDR_length = "\000\000\000\r"
    @IHDR_crc = "\2152\317\275"
    @IHDR_crc_value = @IHDR_crc.unpack('N').first
    @IHDR_data = "\000\000\000\n\000\000\000\n\b\006\000\000\000"
    @IHDR_chunk = "#{@IHDR_length}IHDR#{@IHDR_data}#{@IHDR_crc}"

    @blob = <<-EOF.unpack('m*').first
iVBORw0KGgoAAAANSUhEUgAAAAUAAAAKCAYAAAB8OZQwAAAAD0lEQVR4nGP4
jwUwDGVBALuJxzlQugpEAAAAAElFTkSuQmCC
    EOF
  end

  def test_class_check_crc
    assert PNG.check_crc('IHDR', @IHDR_data, @IHDR_crc_value)
  end

  def test_class_check_crc_exception
    begin
      PNG.check_crc('IHDR', @IHDR_data, @IHDR_crc_value + 1)
    rescue ArgumentError => e
      assert_equal "Invalid CRC encountered in IHDR chunk", e.message
    else
      flunk "exception wasn't raised"
    end
  end

  def test_class_read_chunk
    data = PNG.read_chunk 'IHDR', @IHDR_chunk

    assert_equal @IHDR_data, data
  end

  def test_class_read_IDAT
    canvas = PNG::Canvas.new 5, 10, PNG::Color::White

    data = ([ 0, [255] * (4*5) ] * 10)
    data = data.flatten.map { |n| n.chr }.join
    data = Zlib::Deflate.deflate(data)

    PNG.read_IDAT data, 8, PNG::RGBA, canvas

    assert_equal @blob, PNG.new(canvas).to_blob
  end

  def test_class_read_IHDR
    bit_depth, color_type, canvas = PNG.read_IHDR @IHDR_data
    assert_equal 10, canvas.width
    assert_equal 10, canvas.height
  end
end

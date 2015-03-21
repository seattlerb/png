dir = File.expand_path "~/.ruby_inline"
if File.directory? dir then
  require "fileutils"
  puts "nuking #{dir}"
  # force removal, Windoze is bitching at me, something to hunt later...
  FileUtils.rm_r dir, :force => true
end

require "rubygems"
require "minitest/autorun"
require "png/reader"

class TestPngReader < Minitest::Test

  def setup
    @canvas = PNG::Canvas.new 5, 10, PNG::Color::White
    @png = PNG.new @canvas

    @IHDR_length = "\000\000\000\r"
    @IHDR_crc = "\2152\317\275"
    @IHDR_crc_value = @IHDR_crc.unpack("N").first
    @IHDR_data = "\000\000\000\n\000\000\000\n\b\006\000\000\000"
    @IHDR_chunk = "#{@IHDR_length}IHDR#{@IHDR_data}#{@IHDR_crc}"

    @blob = <<-EOF.unpack("m*").first
iVBORw0KGgoAAAANSUhEUgAAAAUAAAAKCAYAAAB8OZQwAAAAD0lEQVR4nGP4
jwUwDGVBALuJxzlQugpEAAAAAElFTkSuQmCC
    EOF
  end

  def test_class_check_crc
    assert PNG.check_crc("IHDR", @IHDR_data, @IHDR_crc_value)
  end

  def test_class_check_crc_exception
    PNG.check_crc("IHDR", @IHDR_data, @IHDR_crc_value + 1)
  rescue ArgumentError => e
    assert_equal "Invalid CRC encountered in IHDR chunk", e.message
  else
    flunk "exception wasn't raised"
  end

  def test_class_read_chunk
    data = PNG.read_chunk "IHDR", @IHDR_chunk

    assert_equal @IHDR_data, data
  end

  def test_class_read_IDAT
    canvas = PNG::Canvas.new 5, 10, PNG::Color::White

    data = ([0, [255] * (4*5)] * 10)
    data = data.flatten.map(&:chr).join
    data = Zlib::Deflate.deflate(data)

    PNG.read_IDAT data, 8, PNG::RGBA, canvas

    assert_equal @blob, PNG.new(canvas).to_blob
  end

  def test_class_read_IHDR
    _, _, width, height = PNG.read_IHDR @IHDR_data
    assert_equal 10, width
    assert_equal 10, height
  end

  def test_class_load_metadata
    png, _ = util_png

    width, height, bit_depth = PNG.load(png.to_blob, :metadata)

    assert_equal 2, width
    assert_equal 2, height
    assert_equal 8, bit_depth
  end

  def test_class_load
    png, canvas = util_png

    new_png = PNG.load(png.to_blob)

    assert_equal canvas.data, new_png.data
  end

  def util_png
    canvas = PNG::Canvas.new 2, 2
    canvas[0, 0] = PNG::Color::Black
    canvas[1, 1] = PNG::Color::Black
    png = PNG.new canvas
    return png, canvas
  end
end

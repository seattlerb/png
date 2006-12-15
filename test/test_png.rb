require 'test/unit'
require 'png'

class TestArray < Test::Unit::TestCase

  def test_fast_pack
    data = [0xff, 0xff, 0xff, 0x00]

    assert_equal data.pack('C*'), data.fast_pack
  end

  def test_fast_flatten
    canvas = [
      [0, [0x01, 0x02, 0x03, 0x04], [0x05, 0x06, 0x07, 0x08]],
      [0, [0x09, 0x0a, 0x0b, 0x0c], [0x0d, 0x0e, 0x0f, 0x10]],
    ]
    assert_equal canvas.flatten, canvas.fast_flatten
  end

end

class TestPNGColor < Test::Unit::TestCase

  def setup
    @color = PNG::Color.new 0x01, 0x02, 0x03, 0x04
  end

  def test_r
    assert_equal 0x01, @color.r
  end

  def test_g
    assert_equal 0x02, @color.g
  end

  def test_b
    assert_equal 0x03, @color.b
  end

  def test_a
    assert_equal 0x04, @color.a
  end

  def test_blend
    c1 = @color
    c2 = PNG::Color.new 0xFF, 0xFE, 0xFD, 0xFC

    assert_equal PNG::Color.new(0xfb, 0xfa, 0xf9, 0xf8), c1.blend(c2)
  end

  def test_intensity
    assert_equal PNG::Color.new(0x01, 0x02, 0x03, 0x3c), @color.intensity(0xf00)
  end

  def test_inspect
    assert_equal "#<PNG::Color 01 02 03 04>", @color.inspect
  end

  def test_to_ascii
    assert_equal '00', PNG::Color::White.to_ascii
    assert_equal '++', PNG::Color::Yellow.to_ascii
    assert_equal ',,', PNG::Color::Red.to_ascii
    assert_equal '..', PNG::Color::Black.to_ascii
  end

end

class TestPNGCanvas < Test::Unit::TestCase

  def setup
    @canvas = PNG::Canvas.new 10, 10
  end

  def test_each
    canvas = PNG::Canvas.new 2, 2
    points = []

    canvas.each do |*data| points << data end

    expected = [
      [0, 0, PNG::Color::White],
      [1, 0, PNG::Color::White],
      [0, 1, PNG::Color::White],
      [1, 1, PNG::Color::White],
    ]

    assert_equal expected, points
  end

  def test_inspect
    assert_equal "#<PNG::Canvas 10x10>", @canvas.inspect
  end

  def test_point
    assert_equal PNG::Color.new(0xfe, 0x00, 0xfe, 0xfe),
                 @canvas.point(5, 5, PNG::Color::Purple)
  end

  def test_line
    @canvas.line 0, 0, 9, 9, PNG::Color::Black

    expected = <<-EOF
..000000000000000000
00..0000000000000000
0000..00000000000000
000000..000000000000
00000000..0000000000
0000000000..00000000
000000000000..000000
00000000000000..0000
0000000000000000..00
000000000000000000..
    EOF

    assert_equal expected, @canvas.to_s
  end

  def test_to_s
    expected = <<-EOF
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
00000000000000000000
    EOF

    assert_equal expected, @canvas.to_s
  end

end

class TestPNG < Test::Unit::TestCase

  def setup
    @canvas = PNG::Canvas.new 10, 10
    @png = PNG.new @canvas
  end

  def test_class_chunk
    chunk = PNG.chunk 'IDHR', [10, 10, 8, 6, 0, 0, 0 ].pack('N2C5')
    expected = "\000\000\000\rIDHR\000\000\000\n\000\000\000\n\b\006\000\000\000o\345\265\221"
    assert_equal expected, chunk
  end

  def test_to_blob
    expected = <<-EOF.unpack('m*').first
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAEUlEQVR42mP4
TyRgGFVIX4UAI/uOgGWVNeQAAAAASUVORK5CYII=
    EOF

    assert_equal expected, @png.to_blob
  end

end


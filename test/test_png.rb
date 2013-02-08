dir = File.expand_path "~/.ruby_inline"
if File.directory? dir then
  require 'fileutils'
  puts "nuking #{dir}"
  # force removal, Windoze is bitching at me, something to hunt later...
  FileUtils.rm_r dir, :force => true
end

require 'minitest/autorun'
require 'rubygems'
require 'png'
require 'png/reader'
require 'png/pie'

class TestPng < MiniTest::Unit::TestCase
  def setup
    @canvas = PNG::Canvas.new 5, 10, PNG::Color::White
    @png = PNG.new @canvas

    @blob = <<-EOF.unpack('m*').first
iVBORw0KGgoAAAANSUhEUgAAAAUAAAAKCAYAAAB8OZQwAAAAD0lEQVR4nGP4
jwUwDGVBALuJxzlQugpEAAAAAElFTkSuQmCC
    EOF
  end

  def test_class_chunk
    chunk = PNG.chunk 'IHDR', [10, 10, 8, 6, 0, 0, 0 ].pack('N2C5')

    header_crc = "\2152\317\275"
    header_data = "\000\000\000\n\000\000\000\n\b\006\000\000\000"
    header_length = "\000\000\000\r"
    header_chunk = "#{header_length}IHDR#{header_data}#{header_crc}"

    assert_equal header_chunk, chunk
  end

  def test_class_chunk_empty
    chunk = PNG.chunk 'IHDR'
    expected = "#{0.chr * 4}IHDR#{["IHDR".png_crc].pack 'N'}"
    assert_equal expected, chunk
  end

  def test_to_blob
    assert_equal @blob, @png.to_blob
  end

  def test_save
    path = "blah.png"
    @png.save(path)
    file = File.open(path, 'rb') { |f| f.read }
    assert_equal @blob, file
  ensure
    assert_equal 1, File.unlink(path)
  end

end

class TestCanvas < MiniTest::Unit::TestCase

  def setup
    @canvas = PNG::Canvas.new 5, 10, PNG::Color::White
  end

  def test_composite_default
    canvas1, canvas2 = util_composite_canvases

    canvas1.composite canvas2, 1, 1

    expected = " xxxxxxxx
                 xxxxxxxx
                 xx..xxxx
                 ..xxxxxx
                          ".gsub(/ /, '')

    assert_equal expected, canvas1.to_s.gsub(/ /, 'x')
  end

  def test_composite_underlay
    canvas1, canvas2 = util_composite_canvases

    canvas1.composite canvas2, 1, 1, :add

    expected = " xxxxxxxx
                 xxxx..xx
                 xx00xxxx
                 ..xxxxxx
                          ".gsub(/ /, '')

    assert_equal expected, canvas1.to_s.gsub(/ /, 'x')
  end

  def test_composite_overlay
    canvas1, canvas2 = util_composite_canvases

    canvas1.composite canvas2, 1, 1, :overlay

    expected = " xxxxxxxx
                 xxxx..xx
                 xx..xxxx
                 ..xxxxxx
                          ".gsub(/ /, '')

    assert_equal expected, canvas1.to_s.gsub(/ /, 'x')
  end

  def test_composite_blend
    canvas1, canvas2 = util_composite_canvases

    canvas1.composite canvas2, 1, 1, :blend

    expected = " xxxxxxxx
                 xxxx..xx
                 xx,,xxxx
                 ..xxxxxx
                          ".gsub(/ /, '')

    assert_equal expected, canvas1.to_s.gsub(/ /, 'x')
  end

  def test_composite_bad_style
    canvas1, canvas2 = util_composite_canvases

    assert_raises RuntimeError do
      canvas1.composite canvas2, 1, 1, :bad
    end
  end

  def test_extract
    canvas1, _ = util_composite_canvases

    expected = " xxxxxxxx
                 xxxx..xx
                 xx00xxxx
                 ..xxxxxx
                          ".gsub(/ /, '')

    assert_equal expected, canvas1.to_s.gsub(/ /, 'x')

    canvas2 = canvas1.extract(1, 1, 2, 2)

    expected = " xx..
                 00xx
                      ".gsub(/ /, '')

    assert_equal expected, canvas2.to_s.gsub(/ /, 'x')
  end

  def test_index
    assert_equal PNG::Color::White, @canvas[1, 2]
    assert_same @canvas[1, 2], @canvas.data[1][2]
  end

  def test_index_tall
    @canvas = PNG::Canvas.new 2, 4, PNG::Color::White
    @canvas[ 0, 0] = PNG::Color::Black
    @canvas[ 0, 3] = PNG::Color::Background
    @canvas[ 1, 0] = PNG::Color::Yellow
    @canvas[ 1, 3] = PNG::Color::Blue

    expected = "  ,,\n0000\n0000\n..++\n"

    assert_equal expected, @canvas.to_s
  end

  def test_index_wide
    @canvas = PNG::Canvas.new 4, 2, PNG::Color::White
    @canvas[ 0, 0] = PNG::Color::Black
    @canvas[ 3, 0] = PNG::Color::Background
    @canvas[ 0, 1] = PNG::Color::Yellow
    @canvas[ 3, 1] = PNG::Color::Blue

    expected = "++0000,,\n..0000  \n"

    assert_equal expected, @canvas.to_s
  end

  def test_index_bad_x
    begin
      @canvas[6, 1]
    rescue => e
      assert_equal "bad x value 6 >= 5", e.message
    else
      flunk "didn't raise"
    end
  end

  def test_index_bad_y
    begin
      @canvas[1, 11]
    rescue => e
      assert_equal "bad y value 11 >= 10", e.message
    else
      flunk "didn't raise"
    end
  end

  def test_index_equals
    @canvas[1, 2] = PNG::Color::Red
    assert_equal PNG::Color::Red, @canvas[1, 2]
    assert_same @canvas[1, 2], @canvas.data[7][1]

    expected = "
0000000000
0000000000
0000000000
0000000000
0000000000
0000000000
0000000000
00,,000000
0000000000
0000000000".strip + "\n"
    actual = @canvas.to_s
    assert_equal expected, actual
  end

  def test_index_equals_bad_x
    begin
      @canvas[6, 1] = PNG::Color::Red
    rescue => e
      assert_equal "bad x value 6 >= 5", e.message
    else
      flunk "didn't raise"
    end
  end

  def test_index_equals_bad_y
    begin
      @canvas[1, 11] = PNG::Color::Red
    rescue => e
      assert_equal "bad y value 11 >= 10", e.message
    else
      flunk "didn't raise"
    end
  end

#   def test_point
#     raise NotImplementedError, 'Need to write test_point'
#   end

  def test_inspect
    assert_equal "#<PNG::Canvas 5x10>", @canvas.inspect
  end

  def test_point
    assert_equal PNG::Color.new(0xff, 0x7f, 0xff, 0xff),
                 @canvas.point(0, 0, PNG::Color::Magenta)
    # flunk "this doesn't test ANYTHING"
  end

  def test_line
    @canvas.line 0, 9, 4, 0, PNG::Color::Black

    expected = <<-EOF
,,00000000
,,00000000
,,,,000000
00..000000
00,,,,0000
0000..0000
0000,,,,00
000000..00
000000,,,,
00000000..
    EOF

    assert_equal expected, @canvas.to_s
  end

  def test_positive_slope_line
    @canvas.line 0, 0, 4, 9, PNG::Color::Black

    expected = <<-EOF
00000000,,
00000000,,
000000,,,,
000000..00
0000,,,,00
0000..0000
00,,,,0000
00..000000
,,,,000000
..00000000
    EOF

    assert_equal expected, @canvas.to_s
  end

  def test_to_s_normal
    @canvas = PNG::Canvas.new 5, 10, PNG::Color::White
    expected = util_ascii_art(5, 10)
    assert_equal expected, @canvas.to_s
  end

  def test_to_s_wide
    @canvas = PNG::Canvas.new 250, 10, PNG::Color::White
    expected = util_ascii_art(36, 2) # scaled
    assert_equal expected, @canvas.to_s
  end

  def test_to_s_tall
    @canvas = PNG::Canvas.new 10, 250, PNG::Color::White
    expected = util_ascii_art(10, 250)
    assert_equal expected, @canvas.to_s
  end

  def test_to_s_huge
    @canvas = PNG::Canvas.new 250, 250, PNG::Color::White
    expected = util_ascii_art(36, 36) # scaled
    assert_equal expected, @canvas.to_s
  end

  def util_composite_canvases
    canvas1 = PNG::Canvas.new 4, 4
    canvas1[0, 0] = PNG::Color::Black
    canvas1[1, 1] = PNG::Color::White
    canvas1[2, 2] = PNG::Color::Black

    expected = " xxxxxxxx
                 xxxx..xx
                 xx00xxxx
                 ..xxxxxx
                          ".gsub(/ /, '')

    assert_equal expected, canvas1.to_s.gsub(/ /, 'x')


    canvas2 = PNG::Canvas.new 2, 2
    canvas2[0, 0] = PNG::Color::Black

    expected = " xxxx 
                 ..xx
                      ".gsub(/ /, '')

    assert_equal expected, canvas2.to_s.gsub(/ /, 'x')

    return canvas1, canvas2
  end

  def util_ascii_art(width, height)
    (("0" * width * 2) + "\n") * height
  end
end

class TestPng::TestColor < MiniTest::Unit::TestCase
  def setup
    @color = PNG::Color.new 0x01, 0x02, 0x03, 0x04
  end

  def test_class_from_str
    @color = PNG::Color.from "0x01020304"
    test_r
    test_g
    test_b
    test_a
  end

  def test_class_from_int
    @color = PNG::Color.from 0x01020304
    test_r
    test_g
    test_b
    test_a
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
#     c1 = @color
#     c2 = PNG::Color.new 0xFF, 0xFE, 0xFD, 0xFC

#     assert_equal PNG::Color.new(0xFB, 0xFA, 0xF9, 0xF8), c1.blend(c2)

    c1 = PNG::Color::White
    c2 = PNG::Color::Black

    assert_equal PNG::Color::Gray, c2.blend(c1)
    assert_equal PNG::Color::Gray, c1.blend(c2)
  end

  def test_intensity
    assert_equal PNG::Color.new(0x01, 0x02, 0x03, 0x3c), @color.intensity(0xf00)
  end

  def test_inspect
    assert_equal "#<PNG::Color 01 02 03 04>", @color.inspect
  end

  def test_inspect_name
    assert_equal "#<PNG::Color Red>", PNG::Color::Red.inspect
  end

  def test_pipe
    b = PNG::Color::Black
    w = PNG::Color::White
    t = PNG::Color::Background

    # first non-transparent
    assert_equal b, b | t
    assert_equal b, t | b

    assert_equal b, b | w
    assert_equal w, w | b

    assert_equal t, t | t
  end

  def test_to_ascii
    assert_equal '00', PNG::Color::White.to_ascii, "white"
    assert_equal '++', PNG::Color::Yellow.to_ascii, "yellow"
    assert_equal ',,', PNG::Color::Red.to_ascii, "red"
    assert_equal '..', PNG::Color::Black.to_ascii, "black"
    assert_equal '  ', PNG::Color::Background.to_ascii, "background"
  end

  def test_to_ascii_alpha
    assert_equal '00', PNG::Color.new(255,255,255,255).to_ascii
    assert_equal '00', PNG::Color.new(255,255,255,192).to_ascii
    assert_equal '++', PNG::Color.new(255,255,255,191).to_ascii
    assert_equal ',,', PNG::Color.new(255,255,255,127).to_ascii
    assert_equal ',,', PNG::Color.new(255,255,255,126).to_ascii
    assert_equal ',,', PNG::Color.new(255,255,255, 64).to_ascii
    assert_equal '..', PNG::Color.new(255,255,255, 63).to_ascii
    assert_equal '..', PNG::Color.new(255,255,255,  1).to_ascii
    assert_equal '  ', PNG::Color.new(255,255,255,  0).to_ascii
  end

  def test_to_s_name
    assert_equal 'Red', PNG::Color::Red.to_s
  end

  def test_to_s
    obj = PNG::Color.new(255,255,255,  0)
    assert_equal '#<PNG::Color:0xXXXXXX>', obj.to_s.sub(/0x[0-9a-f]+/, '0xXXXXXX')
  end

  def test_equals2
    assert_equal PNG::Color.new(255,255,255,  0), PNG::Color.new(255,255,255,  0)
  end

  def test_hash
    a = PNG::Color.new(255,255,255,  0)
    b = PNG::Color.new(255,255,255,  0)
    assert_equal a.hash, b.hash
  end

#   def test_values
#     raise NotImplementedError, 'Need to write test_values'
#   end
end

class TestPng::TestPie < MiniTest::Unit::TestCase
  def test_pie_chart_odd
    expected =
      ["          ..          ",
       "    ,,,,,,........    ",
       "  ,,,,,,,,..........  ",
       "  ,,,,,,,,..........  ",
       "  ,,,,,,,,..........  ",
       ",,,,,,,,,,............",
       "  ,,,,,,,,,,,,,,,,,,  ",
       "  ,,,,,,,,,,,,,,,,,,  ",
       "  ,,,,,,,,,,,,,,,,,,  ",
       "    ,,,,,,,,,,,,,,    ",
       "          ,,          ",
      nil].join("\n")

    actual = PNG::pie_chart(11, 0.25, PNG::Color::Black, PNG::Color::Green)
    assert_equal expected, actual.to_s
  end

  def test_pie_chart_even
    expected =
      ["          ..          ",
       "    ,,,,,,........    ",
       "  ,,,,,,,,..........  ",
       "  ,,,,,,,,..........  ",
       "  ,,,,,,,,..........  ",
       ",,,,,,,,,,............",
       "  ,,,,,,,,,,,,,,,,,,  ",
       "  ,,,,,,,,,,,,,,,,,,  ",
       "  ,,,,,,,,,,,,,,,,,,  ",
       "    ,,,,,,,,,,,,,,    ",
       "          ,,          ",
      nil].join("\n")

    actual = PNG::pie_chart(10, 0.25, PNG::Color::Black, PNG::Color::Green)
    assert_equal expected, actual.to_s
  end

  def util_angle(expect, x, y)
    actual = PNG.angle(x, y)
    case expect
    when Integer then
      assert_equal(expect, actual,
                   "[#{x}, #{y}] should be == #{expect}, was #{actual}")
    else
      assert_in_delta(expect, actual, 0.5)
    end
  end

  def test_math_is_hard_lets_go_shopping
    util_angle   0,  0,  0
    (25..500).step(25) do |n|
      util_angle   0,  0,  n
      util_angle  90,  n,  0
      util_angle 180,  0, -n
      util_angle 270, -n,  0
    end

    util_angle 359.5, -1, 250
    util_angle   0.0,  0, 250
    util_angle   0.5,  1, 250

    util_angle 89.5, 250,  1
    util_angle 90.0, 250,  0
    util_angle 90.5, 250, -1
  end
end

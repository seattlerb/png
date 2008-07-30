require 'test/unit'
require 'rubygems'

require 'png/font'

class TestPngFont < Test::Unit::TestCase

  def setup
  end

  def test_height
    assert_equal 6, PNG::Font.default.height
  end

  def test_width
    assert_equal 6, PNG::Font.default.width
  end

  def test_annotate
    canvas = PNG::Canvas.new 32, 8, PNG::Color::White
    canvas.annotate 1, 1, "hello", PNG::Font.default

    expected = "
0000000000000000000000000000000000000000000000000000000000000000
0000..0000000000000000000000000000..0000000000..0000000000000000
0000......000000......000000000000..0000000000..000000....000000
0000..0000..00..0000....0000000000..0000000000..0000..0000..0000
0000..0000..00..00..00000000000000..0000000000..0000..0000..0000
0000..0000..0000......000000000000..0000000000..000000....000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
".strip + "\n"

    assert_equal expected, canvas.to_s
  end

  def test_identity
    assert_same PNG::Font.default, PNG::Font.default
  end
end

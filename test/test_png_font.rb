dir = File.expand_path "~/.ruby_inline"
if test ?d, dir then
  require 'fileutils'
  puts "nuking #{dir}"
  # force removal, Windoze is bitching at me, something to hunt later...
  FileUtils.rm_r dir, :force => true
end

require 'rubygems'
require 'minitest/autorun'
require 'png/font'

class TestPngFont < MiniTest::Unit::TestCase

  def setup
    @font = PNG::Font.default
  end

  def test_height
    assert_equal 6, @font.height
  end

  def test_width
    assert_equal 6, @font.width
  end

  def test_coordinates
    assert_equal [ 0,  0,  5,  5], @font.coordinates('(')
    assert_equal [ 0,  6,  5, 11], @font.coordinates('0')
    assert_equal [ 0, 12,  5, 17], @font.coordinates('a')
    assert_equal [ 0, 18,  5, 23], @font.coordinates('A')

    assert_equal [42, 12, 47, 17], @font.coordinates('h')
    assert_equal [42, 18, 47, 23], @font.coordinates('H')
  end

  def test_index
    expected = "
0000....0000
00..0000..00
00..0000..00
00........00
00..0000..00
000000000000
".strip + "\n"

    assert_equal expected, @font['A'].to_s

    expected = "
00000000..00
00000000..00
00000000..00
00000000..00
00000000..00
000000000000
".strip + "\n"

    assert_equal expected, @font['l'].to_s
  end

  def test_index_identity
    assert_same @font['A'], @font['A']
  end

  def test_annotate
    canvas = PNG::Canvas.new 30, 6, PNG::Color::White
    canvas.annotate "hello", 0, 0

    expected = "
00..0000000000000000000000000000..0000000000..00000000000000
00......000000......000000000000..0000000000..000000....0000
00..0000..00..0000....0000000000..0000000000..0000..0000..00
00..0000..00..00..00000000000000..0000000000..0000..0000..00
00..0000..0000......000000000000..0000000000..000000....0000
000000000000000000000000000000000000000000000000000000000000
".strip + "\n"

    assert_equal expected, canvas.to_s
  end

  def test_identity
    assert_same PNG::Font.default, PNG::Font.default
  end
end

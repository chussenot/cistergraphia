# frozen_string_literal: true

require 'test_helper'

class CistergraphiaTest < Minitest::Test
  # Records the strokes a symbol draws instead of building XML
  class StrokeRecorder
    attr_reader :lines

    def initialize
      @lines = []
    end

    def line(x1:, y1:, x2:, y2:)
      @lines << [x1, y1, x2, y2]
    end
  end

  def strokes_for(num)
    recorder = StrokeRecorder.new
    Cistergraphia.digits(num).each { |d| Cistergraphia.draw_line(recorder, d, 0, 0) }
    recorder.lines.sort
  end

  def test_split_parts_add_back_up_to_the_original_value
    100.times do
      seq = Cistergraphia.cister('the quick brown fox')
      expected = 'the quick brown fox'.chars.map { |c| Cistergraphia::TABLET.fetch(c.to_sym) * 10 }

      assert_equal expected, seq.each_slice(2).map(&:sum)
    end
  end

  def test_unsupported_characters_are_separators_instead_of_crashing
    assert_equal Cistergraphia.cister('r d').size, Cistergraphia.cister('r2d').size
    assert_equal Cistergraphia.cister('snake case').size, Cistergraphia.cister('snake_case').size
    assert_equal 2, Cistergraphia.cister('  é!a?? ').size
  end

  def test_message_without_cipherable_characters_raises_a_domain_error
    ['', '   ', '!!!', '1234', nil].each do |message|
      assert_raises(Cistergraphia::EmptyMessageError) { Cistergraphia.encode(message) }
    end
  end

  def test_encode_pads_to_a_perfect_square
    %w[a ab abc hello cistercian].each do |message|
      size = Cistergraphia.encode(message).size

      assert Cistergraphia.perfect_square?(size), "#{size} is not a perfect square"
    end
  end

  def test_perfect_square_is_exact_for_large_numbers
    assert Cistergraphia.perfect_square?(((2**30) + 1)**2)
    refute Cistergraphia.perfect_square?((((2**30) + 1)**2) - 1)
  end

  def test_compound_digits_draw_every_stroke
    assert_equal 1, strokes_for(1).size
    assert_equal 2, strokes_for(5).size
    assert_equal 2, strokes_for(7).size
    assert_equal 2, strokes_for(8).size
    assert_equal 3, strokes_for(9).size
    assert_equal 3, strokes_for(9000).size
  end

  def test_all_nine_units_are_distinct
    glyphs = (1..9).map { |n| strokes_for(n) }

    assert_equal 9, glyphs.uniq.size
  end

  def test_place_values_are_rotations_of_the_same_glyph
    (1..9).each do |n|
      assert_equal strokes_for(n).size, strokes_for(n * 10).size
      assert_equal strokes_for(n).size, strokes_for(n * 100).size
      assert_equal strokes_for(n).size, strokes_for(n * 1000).size
    end
  end

  def test_to_svg_renders_one_stem_per_symbol
    sequence = [1, 9, 1234, 9999]
    svg = Nokogiri::XML(Cistergraphia.to_svg(sequence))
    lines = svg.css('line')
    stems = lines.count { |l| l['x1'] == l['x2'] && l['y2'].to_i - l['y1'].to_i == Cistergraphia::SYMBOL_HEIGHT }

    assert_equal 'svg', svg.root.name
    assert_equal sequence.size, stems
    assert_equal [1, 9, 1234, 9999].sum { |n| strokes_for(n).size } + sequence.size, lines.size
  end

  def test_snail_returns_spiral_order
    assert_equal [1, 2, 3, 6, 9, 8, 7, 4, 5], Cistergraphia.snail([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
  end
end

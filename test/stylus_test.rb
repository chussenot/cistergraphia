# frozen_string_literal: true

require 'test_helper'

class StylusTest < Minitest::Test
  Stylus = Cistergraphia::Stylus

  def test_strokes_are_pressed_left_to_right_and_verticals_top_down
    assert_equal [0, 0, 50, 0], Stylus.ductus([50, 0, 0, 0]) # right to left, turned round
    assert_equal [100, 0, 100, 50], Stylus.ductus([100, 50, 100, 0]) # bottom-up, turned round
    assert_equal [0, 50, 50, 0], Stylus.ductus([50, 0, 0, 50])     # diagonals too: left to right
    assert_equal [50, 0, 100, 50], Stylus.ductus([50, 0, 100, 50]) # already in hand
  end

  def test_the_head_sits_at_the_start_and_the_tail_reaches_the_end
    head, tail = Stylus.wedge([100, 0, 50, 0], Random.new(1)) # drawn right to left: pressed from the left

    back = midpoint(head[0], head[2])
    assert_in_delta 50, back[0], 1e-9 # the head's back is centred on the start, on the left
    assert_in_delta 0, back[1], 1e-9
    tip = tail[1]
    assert_in_delta 100, tip[0], 2.5  # the hand may fall a little short or long (a few percent)
    assert_in_delta 0, tip[1], 6.0    # or a little off the line (up to ±6 degrees over 50)
  end

  def test_the_hand_is_repeatable
    assert_equal Stylus.wedge([50, 0, 50, 150], Random.new(7)), Stylus.wedge([50, 0, 50, 150], Random.new(7))
    refute_equal Stylus.wedge([50, 0, 50, 150], Random.new(7)), Stylus.wedge([50, 0, 50, 150], Random.new(8))
  end

  def test_the_page_hand_presses_a_stroke_the_same_way_every_time_whichever_way_it_was_drawn
    assert_equal Stylus.press([50, 0, 100, 50]), Stylus.press([100, 50, 50, 0])
    refute_equal Stylus.press([50, 0, 100, 50]), Stylus.press([50, 50, 100, 0]) # each stroke its own hand
    assert_match(/\AM[^Z]+ZM[^Z]+Z\z/, Stylus.press(Cistergraphia::Glyphs::STEM)) # a head and a tail
  end

  def test_a_plate_is_pressed_one_path_per_sign_and_keeps_its_strokes_for_the_decoder
    svg = Cistergraphia.to_svg([1, 2, 3, 4])
    doc = REXML::Document.new(svg)

    assert_equal 4, doc.root.get_elements('//path').size
    hidden = doc.root.get_elements('//g').find { |g| g['display'] == 'none' }
    assert_equal 4 + 4, hidden.get_elements('line').size # four stems, four units
    assert_equal [1, 2, 3, 4], Cistergraphia::SVG.read(svg)
    assert_equal svg, Cistergraphia.to_svg([1, 2, 3, 4]) # the same plate, pressed the same way
  end

  def test_turned_signs_are_pressed_upright_then_turned_with_their_cell
    # Rongorongo 2 x 2: the bottom row upright, the top row turned and read right to left
    paths = REXML::Document.new(Cistergraphia.to_svg([1, 1, 1, 1], layout: :rongorongo)).root.get_elements('//path')

    assert_equal [100.0, 220.0], stem_start(paths[0]) # bottom left, upright: the stem's head on top
    assert_equal [220.0, 200.0], stem_start(paths[2]) # top right, turned: the stem's head at the bottom
  end

  private

  def midpoint((x1, y1), (x2, y2))
    [(x1 + x2) / 2.0, (y1 + y2) / 2.0]
  end

  # The centre of the back of the first wedge drawn in a sign: its stem's start
  def stem_start(path)
    corner1, _point, corner2 = path['d'][/M([^Z]*)Z/, 1].split('L').map { |p| p.split.map(&:to_f) }
    midpoint(corner1, corner2).map { |v| v.round(0) }
  end
end

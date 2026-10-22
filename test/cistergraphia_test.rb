# frozen_string_literal: true

require 'test_helper'

class CistergraphiaTest < Minitest::Test
  def strokes_for(num)
    Cistergraphia::Glyphs.strokes(num).drop(1) # drop the stem
  end

  def glyph(num)
    Cistergraphia::Glyphs.strokes(num).map(&Cistergraphia::Glyphs::CANONICAL).sort
  end

  def test_split_parts_add_back_up_to_the_original_value
    100.times do
      seq = Cistergraphia.cister('the quick brown fox')
      expected = 'the quick brown fox'.chars.map { |c| Cistergraphia::TABLET.fetch(c.to_sym) * 10 }

      assert_equal expected, seq.each_slice(2).map(&:sum)
    end
  end

  def test_normalize_keeps_only_tablet_characters
    assert_equal 'rendez vous r d', Cistergraphia.normalize('  Rendez-vous, R2-D2!! ')
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

  def test_evil_symbols_never_split_a_character_pair
    50.times do
      sequence = Cistergraphia.encode('hello world')
      firsts = sequence.each_slice(2).map(&:first)

      refute_includes firsts, Cistergraphia::EVIL_MARKER
      assert_equal 'hello world', Cistergraphia.decipher(sequence)
    end
  end

  def test_perfect_square_is_exact_for_large_numbers
    assert Cistergraphia.perfect_square?(((2**30) + 1)**2)
    refute Cistergraphia.perfect_square?((((2**30) + 1)**2) - 1)
  end

  def test_compound_digits_draw_every_stroke
    { 1 => 1, 5 => 2, 7 => 2, 8 => 2, 9 => 3, 9000 => 3, 1993 => 8 }.each do |num, count|
      assert_equal count, strokes_for(num).size, "strokes for #{num}"
    end
  end

  def test_every_value_from_0_to_9999_has_a_distinct_glyph
    assert_equal 10_000, (0..9999).map { |n| glyph(n) }.uniq.size
  end

  def test_place_values_are_mirror_images_of_the_units
    (1..9).each do |n|
      units = Cistergraphia::Glyphs::LINES.fetch(n)

      tens = units.map { |x1, y1, x2, y2| [100 - x1, y1, 100 - x2, y2] }
      hundreds = units.map { |x1, y1, x2, y2| [x1, 150 - y1, x2, 150 - y2] }

      assert_equal tens, Cistergraphia::Glyphs::LINES.fetch(n * 10)
      assert_equal hundreds, Cistergraphia::Glyphs::LINES.fetch(n * 100)
    end
  end

  def test_snail_returns_spiral_order_without_mutating_its_input
    matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    assert_equal [1, 2, 3, 6, 9, 8, 7, 4, 5], Cistergraphia::Layout.snail(matrix)
    assert_equal [[1, 2, 3], [4, 5, 6], [7, 8, 9]], matrix
  end

  def test_spiral_coordinates_visit_every_cell_once
    coords = Cistergraphia::Layout.spiral_coordinates(6)

    assert_equal 36, coords.uniq.size
    assert_equal (0..5).map { |col| [0, col] }, coords.first(6)  # along the top
    assert_equal (1..5).map { |row| [row, 5] }, coords[6, 5]     # down the right side
    assert_includes [[2, 2], [2, 3], [3, 2], [3, 3]], coords.last # ends in the middle
  end

  def test_to_svg_lays_the_sequence_out_as_a_snail
    sequence = (1..9).to_a
    doc = REXML::Document.new(Cistergraphia.to_svg(sequence))
    stems = doc.root.get_elements('//line').select { |l| l['x1'] == l['x2'] && (l['y2'].to_i - l['y1'].to_i) == 150 }

    assert_equal 9, stems.size
    assert_equal sequence, Cistergraphia::SVG.read(Cistergraphia.to_svg(sequence))
  end

  def test_boustrophedon_coordinates_turn_every_other_row
    coords = Cistergraphia::Layout.boustrophedon_coordinates(3)

    assert_equal [[2, 0, false], [2, 1, false], [2, 2, false]], coords.first(3) # bottom row, left to right
    assert_equal [[1, 2, true], [1, 1, true], [1, 0, true]], coords[3, 3] # back, upside down
    assert_equal [[0, 0, false], [0, 1, false], [0, 2, false]], coords.last(3)
    assert_equal(16, Cistergraphia::Layout.boustrophedon_coordinates(4).map { |row, col, _| [row, col] }.uniq.size)
  end

  def test_turning_a_sign_swaps_its_places
    # Half a turn mirrors both ways: units <-> thousands, tens <-> hundreds
    turned = Cistergraphia::Glyphs.strokes(4127).map { |stroke| Cistergraphia::Glyphs.turn(stroke) }
    undirected = ->(strokes) { strokes.map { |x1, y1, x2, y2| [[x1, y1], [x2, y2]].sort }.sort }

    assert_equal undirected.call(Cistergraphia::Glyphs.strokes(7214)), undirected.call(turned)
    assert_equal 7214, Cistergraphia::Glyphs.read(turned)
  end

  def test_rongorongo_plates_draw_turned_rows_upside_down
    # 2 x 2: bottom row upright, left to right; top row turned, right to left
    svg = Cistergraphia.to_svg([1, 2, 3, 4], layout: :rongorongo)

    assert_equal [1, 2, 3, 4], Cistergraphia::SVG.read(svg, layout: :rongorongo)
    assert_equal [4000, 3000, 2, 1], Cistergraphia::SVG.read(svg) # read as a snail, the top row is upside down
  end

  def test_inscribe_never_draws_a_plate_that_reads_along_both_layouts
    # "jj" as raw rongorongo plates also reads as letters along the snail about 1 time in 100
    ambiguous = 2000.times.count do
      !Cistergraphia.unambiguous?(Cistergraphia.to_svg(Cistergraphia.encode('jj'), layout: :rongorongo), :rongorongo)
    end

    assert_predicate ambiguous, :positive?, 'the hazard this test guards against' # ~20 expected
    500.times do
      _sequence, svg = Cistergraphia.inscribe('jj', layout: :rongorongo)

      assert_equal 'jj', Cistergraphia.decode(svg)
    end
  end

  def test_every_keyless_path_visits_every_cell_once_at_every_side
    Cistergraphia::Layout::KEYLESS.each do |layout|
      (1..14).each do |side|
        cells = Cistergraphia::Layout.path(side, layout).map { |row, col, _| [row, col] }

        assert_equal side * side, cells.uniq.size, "#{layout} at #{side}"
        assert(cells.all? { |row, col| row.between?(0, side - 1) && col.between?(0, side - 1) }, "#{layout} at #{side}")
      end
    end
  end

  def test_the_leap_steps_as_the_zodiac_did_and_the_unwinding_is_not_the_snail_backwards
    leap = Cistergraphia::Layout.path(6, :leap)

    assert_equal [[0, 0, false], [1, 2, false], [2, 4, false], [3, 0, false]], leap.first(4)
    assert_equal [0, 1, false], leap[6], 'the next orbit starts a column to the right'
    pairs = ->(layout) { Cistergraphia::Layout.path(6, layout).each_slice(2).to_set { |(a, b)| [a.first(2), b.first(2)].sort } }

    assert_empty pairs.call(:unwinding) & pairs.call(:phaistos), 'no two signs are read as one pair along both'
    unwinding = Cistergraphia::Layout.path(6, :unwinding)

    assert_equal [[2, 2, false], [0, 5, false]], [unwinding.first, unwinding.last]
  end

  def test_at_a_side_of_two_three_of_the_ways_are_one_walk_and_a_one_letter_plate_still_reads
    assert_equal %i[phaistos rongorongo], Cistergraphia::Layout.others(:leap, 2)
    assert_equal %i[phaistos rongorongo leap furrows], Cistergraphia::Layout.others(:unwinding, 4)
    %i[leap furrows unwinding].each do |way|
      _sequence, svg = Cistergraphia.inscribe('x', layout: way)

      assert_equal 'x', Cistergraphia.decode(svg), way
    end
  end

  def test_a_pathless_plate_lies_in_grid_order_and_still_reads_along_its_way
    sequence, svg = Cistergraphia.inscribe('Meet me at the old abbey', layout: :leap, pathless: true)

    assert Cistergraphia::Pathless.pathless?(svg)
    refute Cistergraphia::Pathless.pathless?(Cistergraphia.inscribe('abbey').last)
    cells = Cistergraphia::SVG.lines(svg).map { |line| Cistergraphia::Layout.cell_of(line) }.uniq

    assert_equal cells.sort, cells, 'the file holds the signs row by row, not in reading order'
    assert_equal sequence, Cistergraphia::SVG.read(svg, layout: :leap)
    assert_equal 'meet me at the old abbey', Cistergraphia.decode(svg), 'the decoder still finds the way'
  end

  def test_a_pathless_plate_is_pressed_by_its_cells_not_by_its_way
    # The same numbers at the same cells, laid along two ways: the same wedges
    # (seeded by the cell), so the hand's tremor tells nothing of the order
    numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
    grid = Cistergraphia::Layout.path(4, :leap).zip(numbers).to_h { |(row, col, _), num| [[row, col], num] }
    along_furrows = Cistergraphia::Layout.path(4, :furrows).map { |row, col, _| grid[[row, col]] }
    wedges = ->(seq, way) { Cistergraphia::SVG.render(seq, layout: way, pathless: true).scan(/<path d="[^"]+"/) }

    assert_equal wedges.call(numbers, :leap), wedges.call(along_furrows, :furrows)
    refute_equal wedges.call(numbers, :leap), Cistergraphia::SVG.render(numbers, layout: :leap).scan(/<path d="[^"]+"/),
                 'a plate with its way told is pressed in reading order'
  end

  def test_pathless_plates_are_games_without_a_key
    assert_raises(Cistergraphia::Error) { Cistergraphia.inscribe('abbey', passphrase: 'molesme', pathless: true) }
    grille = Cistergraphia::Grille.new('K7Q2M-ZXB4P')

    assert_raises(Cistergraphia::Error) { Cistergraphia.inscribe('abbey', layout: grille, pathless: true) }
  end

  def test_unknown_layouts_are_refused
    assert_raises(Cistergraphia::Error) { Cistergraphia.to_svg([1], layout: :spiral) }
  end

  def test_decode_detects_the_layout
    alphabet = [*'a'..'z', ' ']
    Cistergraphia::Layout::KEYLESS.each do |layout|
      50.times do
        message = [*'a'..'z'].sample + Array.new(rand(0..40)) { alphabet.sample }.join
        _sequence, svg = Cistergraphia.inscribe(message, layout: layout)

        assert_equal Cistergraphia.normalize(message), Cistergraphia.decode(svg), layout
        assert_equal Cistergraphia.normalize(message), Cistergraphia.decode(svg, layout: layout)
      end
    end
  end

  def test_round_trip_for_random_messages
    alphabet = [*'a'..'z', ' ', ' ', ' ']
    100.times do
      message = [*'a'..'z'].sample + Array.new(rand(0..80)) { alphabet.sample }.join

      assert_equal Cistergraphia.normalize(message),
                   Cistergraphia.decode(Cistergraphia.to_svg(Cistergraphia.encode(message)))
    end
  end

  def test_decode_tolerates_reversed_strokes_and_float_coordinates
    line = /x1="(?<x1>\d+)" y1="(?<y1>\d+)" x2="(?<x2>\d+)" y2="(?<y2>\d+)"/
    svg = Cistergraphia.to_svg(Cistergraphia.encode('monk')).gsub(line) do
      m = Regexp.last_match
      %(x1="#{m[:x2]}.0" y1="#{m[:y2]}" x2="#{m[:x1]}" y2="#{m[:y1]}")
    end

    assert_equal 'monk', Cistergraphia.decode(svg)
  end

  def test_decipher_unwinds_evil_pairs_nested_inside_other_pairs
    # Older encoders could insert a pair anywhere, even inside another pair
    assert_equal 'a', Cistergraphia.decipher([4, 42, 7, 9999, 9999, 6])
  end

  def test_decode_rejects_input_it_did_not_produce
    [
      '', 'hello', '<html/>', '<svg', '<svg xmlns="http://www.w3.org/2000/svg"/>',
      '<svg><line x1="a" y1="0" x2="0" y2="0"/></svg>',
      '<svg><line x1="100" y1="50" x2="100" y2="200"/><line x1="100" y1="50" x2="140" y2="90"/></svg>',
      Cistergraphia.to_svg([10, 9999, 5]).sub('<line', '<line x1="1" y1="1" x2="2" y2="2"/><line')
    ].each do |svg|
      assert_raises(Cistergraphia::DecodeError, svg) { Cistergraphia.decode(svg) }
    end
  end

  def test_decipher_rejects_sequences_that_are_not_characters
    assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decipher([9999]) }
    assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decipher([1, 2]) }
    assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decipher([10]) }
    assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decipher([5, 9999]) }
  end
end

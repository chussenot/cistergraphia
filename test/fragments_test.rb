# frozen_string_literal: true

require 'test_helper'

class FragmentsTest < Minitest::Test
  C = Cistergraphia
  Fragments = Cistergraphia::Fragments
  MESSAGES = ['the brothers will gather in the chapter house after compline',
              'Meet me at the old abbey after vespers', 'ora et labora', 'relics'].freeze

  def test_a_plate_breaks_into_two_to_four_fragments_that_tile_it
    40.times do |seed|
      pieces = Fragments::Breaking.cut(10, Random.new(seed))

      assert_includes 2..Fragments::MAX_PIECES, pieces.size
      assert(pieces.all? { |piece| [piece.rows, piece.cols].min >= Fragments::MIN_SIDE })
      cells = pieces.flat_map { |piece| piece.cells.map { |r, c| [piece.row + r, piece.col + c] } }
      assert_equal (0...10).to_a.product((0...10).to_a), cells.sort
    end
  end

  def test_a_broken_plate_rejoins_into_its_message
    MESSAGES.each_with_index do |message, seed|
      _, svg, pieces = Fragments.inscribe(message, random: Random.new(seed))

      assert Fragments.broken?(svg)
      assert_equal pieces.size, Fragments.read(svg).size
      assert_equal C.normalize(message), C.decode(svg)
    end
  end

  def test_it_rejoins_one_way_only_and_says_where_each_fragment_goes
    _, svg, pieces = Fragments.inscribe('ora et labora', random: Random.new(3))
    rejoining = Fragments.rejoin(svg)

    assert_equal 1, Fragments::Join.all(Fragments.read(svg), C::Layout::KEYLESS).size
    assert_equal :phaistos, rejoining.layout
    expected = pieces.map { |piece| [piece.row, piece.col, piece.turned] }.sort
    assert_equal expected, rejoining.places.map { |_, row, col, turned| [row, col, turned] }.sort
  end

  def test_the_file_never_says_where_a_fragment_goes_or_whether_it_is_turned
    _, svg, pieces = Fragments.inscribe('the brothers will gather in the chapter house', random: Random.new(5))
    transforms = svg.scan(/<g class="fragment" transform="([^"]*)"/).flatten

    assert_equal pieces.size, transforms.size
    transforms.each do |transform|
      tilt = transform[/rotate\((-?[\d.]+)/, 1].to_f
      assert_operator tilt.abs, :<=, Fragments::Tray::TILT
    end
    refute_match(/data-|rotate\(180/, svg)
  end

  def test_fragments_laid_where_they_belong_show_the_plate_as_drawn
    sequence, svg, = Fragments.inscribe('ora et labora', random: Random.new(1))
    board = laid(Fragments.read(svg), Fragments.rejoin(svg).places)

    assert_equal(sequence, C::Layout.path(6).map { |row, col, _| board.fetch([row, col]) })
  end

  # Cell => the sign it shows, the fragments laid on the board (a turned one's signs upright again)
  def laid(fragments, places)
    places.each_with_object({}) do |(index, row, col, turned), board|
      fragment = fragments[index]
      fragment.readings.each do |(r, c), readings|
        r, c = fragment.opposite(r, c) if turned
        board[[row + r, col + c]] = readings[turned ? 1 : 0].first
      end
    end
  end

  def test_the_same_plate_breaks_the_same_way
    pieces = 2.times.map do
      srand(1) # the splits of each value into two
      Fragments.inscribe('ora et labora', random: Random.new(7))
    end

    assert_equal pieces.first, pieces.last
  end

  def test_refusals
    assert_equal Fragments::TOO_SMALL, assert_raises(C::Error) { Fragments.inscribe('ab') }.message
    assert_equal Fragments::NOT_ALONG_THE_ROWS,
                 assert_raises(C::Error) { Fragments.inscribe('ora et labora', layout: :rongorongo) }.message
    assert_equal Fragments::NOT_UNDER_A_GRILLE,
                 assert_raises(C::Error) { Fragments.inscribe('ora', layout: C::Grille.new('K7Q2M-ZXB4P')) }.message
    _, svg, = Fragments.inscribe('ora et labora')
    assert_raises(C::Error) { C.decode(svg, passphrase: 'abbey of molesme') }
  end

  def test_a_lost_fragment_does_not_rejoin
    _, svg, = Fragments.inscribe('the brothers will gather', random: Random.new(2))
    without = svg.sub(%r{  <g class="fragment".*?\n  </g>}m, '')

    refute_equal svg, without
    error = assert_raises(C::DecodeError) { C.decode(without) }
    assert_match(/square plate|rejoin/, error.message)
  end

  def test_too_many_fragments_are_refused_before_any_search
    _, svg, = Fragments.inscribe('the brothers will gather', random: Random.new(2))
    group = svg[%r{  <g class="fragment".*?\n  </g>}m]
    crowded = svg.sub('</svg>', "#{group * Fragments::MAX_PIECES}\n</svg>")

    error = assert_raises(C::DecodeError) { C.decode(crowded) }
    assert_match(/at most #{Fragments::MAX_PIECES} fragments/, error.message)
  end

  def test_a_hostile_plate_where_every_pair_balances_is_still_read_quickly
    side = 16 # four fragments of 16 x 16 signs: a 32 x 32 board, the largest a message makes
    cells = (0...side).to_a.product((0...side).to_a)
    null = Fragments::Fragment.new(side, side, cells.to_h { |cell| [cell, [[9999], [9999], false]] })

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = assert_raises(C::DecodeError) { Fragments::Join.all([null] * 4, C::Layout::KEYLESS) }
    assert_match(/too many ways/, error.message)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
  end

  def test_an_intact_plate_is_not_broken
    _, svg = C.inscribe('ora et labora')

    refute Fragments.broken?(svg)
  end

  # Whether an edition can be the message: every letter read is right, and
  # every restoration allows the true letter (as in WeatheringTest)
  def faithful?(edition, message)
    expected = C.normalize(message).chars
    edition.scan(/\[([^\]]*)\]|(.)/).all? do |bracket, plain|
      truth = expected.shift
      plain ? plain == truth : bracket.split('/', -1).include?(truth)
    end && expected.empty?
  end

  def test_a_weathered_broken_plate_rejoins_into_its_edition
    MESSAGES.first(3).each_with_index do |message, seed|
      _, svg, pieces, damage = Fragments.inscribe(message, weathered: true, random: Random.new(seed))
      edition = C.decode(svg)

      refute_empty damage
      assert C::Lacunae.weathered?(svg)
      assert_equal 1, Fragments::Join.all(Fragments.read(svg), C::Layout::KEYLESS).size
      assert_includes 1..pieces.size, svg.scan('class="lacunae"').size, 'a lacunae layer in each worn fragment'
      assert_match(/\[/, edition)
      assert faithful?(edition, message), "#{edition.inspect} is not #{message.inspect}"
    end
  end

  def test_a_weathered_fragment_never_carries_what_was_lost
    sequence, svg, _, damage = Fragments.inscribe('the brothers will gather', weathered: true, random: Random.new(4))
    lost = svg.scan(%r{<g class="lacunae".*?</g>}m).sum { |layer| layer.scan('<line').size }
    strokes = sequence.sum { |num| C::Glyphs.strokes(num).size }
    taken = damage.sum { |index, gone| (C::Glyphs.strokes(sequence[index]).map(&C::Glyphs::CANONICAL) & gone).size }

    assert_equal damage.values.sum(&:size), lost
    assert_equal strokes - taken + lost, svg.scan('<line').size
  end

  def test_a_worn_sign_reads_as_its_candidates_both_ways
    _, svg, = Fragments.inscribe('ora et labora', weathered: true, random: Random.new(3))
    worn = Fragments.read(svg).flat_map { |fragment| fragment.readings.values }.select(&:last)

    refute_empty worn
    assert(worn.all? { |upright, turned, _| [upright, turned].compact.any? })
    assert(worn.any? { |upright, turned, _| [upright, turned].compact.any? { |values| values.size > 1 } })
  end

  def test_a_sign_worn_past_one_corner_is_refused
    x, y = C::Layout.origin(0, 0)
    stem = C::Layout.relative(C::Glyphs::STEM, -x, -y)
    everywhere = C::Weathering::POSITIONS.values.flatten(1).map { |stroke| C::Layout.relative(stroke, -x, -y) }

    assert_equal 10, Fragments::Reading.readings([stem], everywhere.first(5), 0, 0).first.size # one corner
    error = assert_raises(C::DecodeError) { Fragments::Reading.readings([stem], everywhere, 0, 0) }
    assert_match(/past one corner/, error.message)
  end

  # Rejoined, for the bench: every sign's value or nothing, the lacunae as the
  # generator laid them (turned with their fragments), and the plate drawn whole
  def test_a_ruined_plate_rejoined_gives_the_bench_its_lacunae_and_a_whole_drawing
    [3, 4, 7].each do |seed|
      sequence, svg, pieces, damage = Fragments.inscribe('the brothers will gather in the chapter house',
                                                         weathered: true, random: Random.new(seed))
      whole = Fragments.rejoined(svg)

      assert_equal :phaistos, whole.layout
      assert_equal sequence.each_with_index.map { |num, i| damage.key?(i) ? nil : num }, whole.signs
      assert_equal damage.transform_values(&:sort), whole.damage.transform_values(&:sort)
      assert(whole.candidates.all? { |index, candidates| candidates.include?(sequence[index]) })
      assert_whole_drawing(whole.svg, pieces)
    end
  end

  # The fragments moved into place, turned where they lie turned: a plate, not a board and a tray
  def assert_whole_drawing(svg, pieces)
    assert_equal pieces.size, svg.scan('<g class="fragment"').size
    assert_equal pieces.count(&:turned), svg.scan('rotate(180 ').size
    refute_includes svg, 'class="board"'
  end

  def test_only_a_plate_that_rejoins_one_way_is_rejoined
    _, svg, = Fragments.inscribe('ora et labora', random: Random.new(3))
    assert_equal :phaistos, Fragments.rejoined(svg).layout # intact fragments: no lacunae
    assert_empty Fragments.rejoined(svg).damage

    halves = svg.scan(%r{<g class="fragment".*?</g>\n  </g>}m)
    lost = halves.first ? svg.sub(halves.first, '') : svg
    assert_raises(C::DecodeError) { Fragments.rejoined(lost) }
  end
end

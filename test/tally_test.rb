# frozen_string_literal: true

require 'test_helper'

class TallyTest < Minitest::Test
  C = Cistergraphia
  Tally = Cistergraphia::Tally
  Weathering = Cistergraphia::Weathering
  WHOLE = Weathering::POSITIONS.values.flatten(1)
  MESSAGE = 'the brothers will gather in the chapter house after compline'

  def test_each_place_is_summed_on_its_own_without_carries
    assert_equal 0, Tally.add([])
    assert_equal 5555, Tally.add([1234, 4321])
    assert_equal 1358, Tally.add([9999, 2469]) # each place mod 10: 9+9 = 8, 9+6 = 5, 9+4 = 3, 9+2 = 1
  end

  def test_rows_columns_and_corner_sum_the_grid
    sequence = C.encode('ora et labora')
    tally = Tally.signs(sequence, :phaistos)
    grid = Tally.grid(sequence, :phaistos)

    assert_equal grid.map { |row| Tally.add(row) }, tally[:rows]
    assert_equal grid.transpose.map { |col| Tally.add(col) }, tally[:cols]
    assert_equal Tally.add(tally[:rows]), tally[:corner]
    assert_equal Tally.add(tally[:cols]), tally[:corner]
  end

  def test_tally_signs_are_drawn_apart_and_read_back
    %i[phaistos rongorongo].each do |layout|
      sequence = C.encode('ora et labora')
      svg = C::SVG.render(sequence, layout: layout, tally: true)

      assert_equal Tally.signs(sequence, layout), Tally::Plate.read(svg, layout)
      assert_equal 'ora et labora', C.decode(svg) # the strokes never include the tallies
      assert_includes svg, 'class="cord"'
    end
  end

  def test_scattered_whole_signs_come_back_from_their_lines
    sequence = C.encode(MESSAGE)
    lost = (0...sequence.size).step(2).to_a.sample(10, random: Random.new(4)).map { |start| start + 1 }
    candidates = sequence.each_with_index.map do |value, index|
      lost.include?(index) ? Weathering.candidates(Weathering.surviving(value, WHOLE), WHOLE) : [value]
    end

    restored = Tally.restore(candidates, Tally.signs(sequence, :phaistos), :phaistos)
    assert_equal sequence.map { |value| [value] }, restored
  end

  def test_tallies_that_do_not_add_up_are_no_restoration
    sequence = C.encode('ora et labora')
    candidates = sequence.map { |value| [value] }
    candidates[0] = Weathering.candidates(Weathering.surviving(sequence[0], WHOLE), WHOLE)
    wrong = Tally.signs(sequence, :phaistos).merge(rows: Array.new(6) { 1111 }, cols: Array.new(6) { 1111 })

    assert_raises(C::DecodeError) { Tally.restore(candidates, wrong, :phaistos) }
  end

  def test_whole_signs_are_lost_only_where_a_tally_gives_them_back
    10.times do |seed|
      sequence = C.encode(MESSAGE)
      lines = Tally.lines(Integer.sqrt(sequence.size), :phaistos)
      damage = Weathering.weather(sequence, random: Random.new(seed), lines: lines)
      wholes = damage.select { |_, lost| lost.size == WHOLE.size }.keys

      refute_empty wholes
      wholes.each { |index| assert(alone_on_a_line?(index, damage, lines), "sign #{index} is not alone on a line") }
    end
  end

  def alone_on_a_line?(index, damage, lines)
    lines[index].any? { |line| damage.keys.one? { |other| lines[other].include?(line) } }
  end

  def test_weathered_plates_with_tallies_restore_completely
    %i[phaistos rongorongo].each do |layout|
      _, svg, damage = C::Lacunae.inscribe(MESSAGE, layout: layout, tally: true)

      assert(damage.any? { |_, lost| lost.size == WHOLE.size }, 'some whole signs lost')
      assert_equal C.normalize(MESSAGE), C.decode(svg).delete('[]'), layout
    end
  end

  def test_no_tally_signs_under_a_grille
    error = assert_raises(C::Error) { C.inscribe('ora', layout: C::Grille.new('K7Q2M-ZXB4P'), tally: true) }
    assert_equal Tally::NOT_UNDER_A_GRILLE, error.message
    assert_raises(C::Error) { C::Lacunae.inscribe('ora', layout: C::Grille.new('K7Q2M-ZXB4P'), tally: true) }
  end
end

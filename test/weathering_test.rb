# frozen_string_literal: true

require 'test_helper'

class WeatheringTest < Minitest::Test
  C = Cistergraphia
  Weathering = Cistergraphia::Weathering
  Lacunae = Cistergraphia::Lacunae
  MESSAGES = ['the brothers will gather in the chapter house after compline',
              'Meet me at the old abbey after vespers', 'ora et labora'].freeze

  # Whether an edition can be the message: every letter read is right, and
  # every restoration allows the true letter
  def faithful?(edition, message)
    expected = Array(C.normalize(message).chars)
    edition.scan(/\[([^\]]*)\]|(.)/).all? do |bracket, plain|
      truth = expected.shift
      plain ? plain == truth : bracket.split('/', -1).include?(truth) || (bracket == ' ' && truth == ' ')
    end && expected.empty?
  end

  def test_each_quadrant_has_five_stroke_positions_and_the_stem_none
    all = Weathering::POSITIONS.values.flatten(1)

    assert_equal 20, all.uniq.size
    refute_includes all, Cistergraphia::Glyphs::CANONICAL.call(Cistergraphia::Glyphs::STEM)
    assert_equal Cistergraphia::Glyphs::STROKE_PLACES.keys.sort, all.sort
  end

  def test_an_intact_sign_has_one_reading
    assert_equal [1098], Weathering.candidates(Weathering.surviving(1098, []), [])
  end

  def test_a_lost_quadrant_could_hold_any_digit
    lost = Weathering::POSITIONS.fetch(10)

    assert_equal (0..9).map { |d| 1008 + (d * 10) }, Weathering.candidates(Weathering.surviving(1098, lost), lost).sort
  end

  def test_the_strokes_that_survive_still_constrain_a_quadrant
    hundreds = Weathering::POSITIONS.fetch(100) # 9 = top bar, inner bar, outer vertical
    lost = [hundreds[0], hundreds[2]] # the top bar and the falling diagonal

    seen = Weathering.surviving(920, lost) # the inner bar and the outer vertical
    assert_equal [820, 920], Weathering.candidates(seen, lost).sort
  end

  def test_a_pair_balances_as_a_letter_a_null_or_not_at_all
    assert_equal 'a', Weathering.balance(3, 7)
    assert_equal Weathering::NULL, Weathering.balance(1234, 9999)
    assert_nil Weathering.balance(3, 8)
  end

  def test_lacunae_are_fair_to_the_reader
    40.times do |seed|
      sequence = C.encode(MESSAGES[seed % MESSAGES.size])
      damage = Weathering.weather(sequence, random: Random.new(seed))

      refute_empty damage
      assert_equal damage.size, damage.keys.map { |index| index / 2 }.uniq.size, 'one lacuna per pair'
      doubts = damage.keys.filter_map { |index| doubted_word(sequence, index - (index % 2), damage) }
      assert_equal doubts.uniq, doubts, 'one doubt per word at most'
    end
  end

  # The word a lacuna leaves in doubt (nil when the balance settles it), checking it is a fair doubt
  def doubted_word(sequence, start, damage)
    letters = Weathering.outcomes(sequence, start, damage)
    assert_includes letters, Weathering.balance(sequence[start], sequence[start + 1])
    return if letters.size == 1

    assert_operator letters.size, :<=, Weathering::MAX_DOUBT
    refute_includes letters, ' '
    Weathering.words_of(sequence)[start]
  end

  def test_weathered_plates_restore_along_every_layout
    [:phaistos, :rongorongo, C::Grille.new('K7Q2M-ZXB4P')].each do |layout|
      MESSAGES.each do |message|
        _, svg, damage = Lacunae.inscribe(message, layout: layout)
        edition = C.decode(svg, layout: (layout if layout.is_a?(C::Grille)))

        refute_empty damage
        assert_match(/\[/, edition)
        assert faithful?(edition, message), "#{edition.inspect} is not #{message.inspect} (#{layout})"
      end
    end
  end

  # The generator checks the other layout from the data: it must find exactly
  # what the decoder finds reading the file along that layout
  def test_the_other_layout_is_checked_as_the_decoder_would_read_the_file
    [[:phaistos, false], [:rongorongo, false], [:phaistos, true], [:rongorongo, true]].each do |layout, tally|
      MESSAGES.each_with_index do |message, seed|
        sequence, damage = Lacunae.weathered(message, layout, tally, Random.new(seed))
        svg = C::SVG.render(sequence, layout: layout, damage: damage, tally: tally)
        (C::Layout::KEYLESS - [layout]).each do |other|
          assert_same_reading(read_file(svg, other), Lacunae::Along.edition(sequence, damage, layout, other, tally))
        end
      end
    end
  end

  def read_file(svg, layout)
    Lacunae.decode(svg, layout: layout)
  rescue C::DecodeError
    nil
  end

  def assert_same_reading(from_file, from_data)
    from_file.nil? ? assert_nil(from_data) : assert_equal(from_file, from_data)
  end

  def test_the_file_never_carries_what_was_lost
    sequence, svg, damage = Lacunae.inscribe('the brothers will gather')
    lost = C::SVG.lines(svg, layer: :lacunae)
    strokes = C::SVG.lines(svg)

    assert_equal damage.values.sum(&:size), lost.size
    assert_empty lost & strokes
    taken = damage.sum { |index, gone| (C::Glyphs.strokes(sequence[index]).map(&C::Glyphs::CANONICAL) & gone).size }
    assert_equal sequence.sum { |num| C::Glyphs.strokes(num).size } - taken, strokes.size # positions, not all inked
    assert_includes svg, 'class="weathering"'
    assert_equal sequence.size, C::SVG.lines(svg).map { |line| C::Layout.cell_of(line) }.uniq.size # every stem survives
  end

  def test_the_same_plate_wears_the_same_way
    sequence = C.encode('ora et labora')
    damage = Weathering.weather(sequence, random: Random.new(7))

    assert_equal C::SVG.render(sequence, damage: damage), C::SVG.render(sequence, damage: damage)
    assert_equal damage, Weathering.weather(sequence, random: Random.new(7))
  end

  def test_even_one_letter_weathers
    _, svg, damage = Lacunae.inscribe('a')

    refute_empty damage
    assert_equal 'a', C.decode(svg).delete('[]').split('/').first
  end

  def test_an_intact_plate_reads_as_before
    _, svg = C.inscribe('ora et labora')

    refute Lacunae.weathered?(svg)
    refute_includes svg, 'weathering'
    assert_equal 'ora et labora', C.decode(svg)
  end

  def test_the_edition_follows_the_leiden_conventions
    tokens = [Weathering::Edition::Token.new(['a'], :read), Weathering::Edition::Token.new(['b'], :restored),
              Weathering::Edition::Token.new(%w[c e], :doubt)]

    assert_equal 'a[b][c/e]', tokens.join
    assert_equal ' ', Weathering::Edition::Token.new([' '], :restored).to_s
  end

  def test_a_pair_wholly_lost_is_weighed_without_trying_every_pair_of_values
    all = Weathering::POSITIONS.values.flatten(1)
    lost = Weathering.candidates(Weathering.surviving(1234, all), all) # 10,000 values each

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    readings = Weathering.readings(lost, lost)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
    assert_equal (C::CHARACTERS.values + [Weathering::NULL]).sort, readings
  end

  def test_a_pair_that_cannot_balance_is_no_edition
    assert_raises(C::DecodeError) { Weathering::Edition.text([[[3], false], [[8], true]]) }
  end

  def test_sealed_plates_do_not_weather
    error = assert_raises(C::Error) { Lacunae.inscribe('relics', passphrase: 'abbey of molesme') }
    assert_equal Lacunae::NOT_SEALED, error.message

    _, svg, = Lacunae.inscribe('relics')
    assert_raises(C::Error) { C.decode(svg, passphrase: 'abbey of molesme') }
  end

  def test_a_weathered_grille_plate_needs_its_key
    grille = C::Grille.new('K7Q2M-ZXB4P')
    _, svg, = Lacunae.inscribe('ora et labora', layout: grille)

    assert_raises(C::GrilleKeyNeededError) { C.decode(svg) }
    assert_raises(C::WrongGrilleError) { C.decode(svg, layout: C::Grille.new('00000-00000')) }
  end

  # The survey: what the reader's page learns from a weathered plate's file alone
  def test_the_survey_finds_the_layout_the_values_and_the_lacunae_of_a_weathered_plate
    [[:phaistos, false], [:rongorongo, false], [:phaistos, true]].each do |layout, tally|
      message = 'the brothers will gather in the chapter house'
      sequence, svg, damage = C::Lacunae.inscribe(message, layout: layout, tally: tally, random: Random.new(7))

      assert_equal layout, C::Lacunae::Survey.layout(svg)
      assert_equal C.decode(svg), C::Lacunae::Survey.edition(svg, layout)
      assert_equal sequence.each_with_index.map { |value, index| damage.key?(index) ? nil : value },
                   C::Lacunae::Survey.values(svg, layout)
      assert_survey_shows_the_damage(C::Lacunae::Survey.damaged(svg, layout), sequence, damage)
    end
  end

  # The lost strokes as they were lost, and the lost value among the candidates
  def assert_survey_shows_the_damage(damaged, sequence, damage)
    assert_equal damage, damaged.to_h { |sign| [sign[:index], sign[:lost]] }.sort.to_h
    damaged.each { |sign| assert_includes sign[:candidates], sequence[sign[:index]] }
  end

  def test_the_survey_reads_a_grille_plate_only_with_its_key
    grille = C::Grille.new('K7Q2M-ZXB4P')
    _, svg, damage = C::Lacunae.inscribe('ora et labora', layout: grille)

    assert_nil C::Lacunae::Survey.layout(svg)
    assert_nil C::Lacunae::Survey.edition(svg, C::Grille.new('00000-00000'))
    assert_equal damage.keys.sort, C::Lacunae::Survey.damaged(svg, grille).map { |sign| sign[:index] }.sort
  end

  # Small plates have few words to carry a doubt: they lose one pair in two
  def test_small_plates_lose_one_pair_in_two_and_large_ones_one_in_three
    assert_equal 4, C::Weathering.target_for(8, nil) # 4 × 4
    assert_equal 9, C::Weathering.target_for(18, nil) # 6 × 6
    assert_equal 10, C::Weathering.target_for(32, nil) # 8 × 8
    assert_equal 16, C::Weathering.target_for(50, nil) # 10 × 10
    assert_equal 4, C::Weathering.target_for(8, []) # tally signs: one in two throughout
    _, _, damage = C::Lacunae.inscribe('ora et', random: Random.new(3))
    assert_operator damage.size, :>=, 3 # a 4 × 4 plate, 8 pairs: 4 asked for, as many as are fair
  end
end

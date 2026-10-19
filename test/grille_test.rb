# frozen_string_literal: true

require 'test_helper'
require 'rexml/document'

class GrilleTest < Minitest::Test
  Grille = Cistergraphia::Grille
  KEY = 'K7Q2M-ZXB4P'

  def test_a_key_is_ten_letters_and_digits_read_kindly
    assert_equal KEY, Grille.new('k7q2m zxb4p').to_s
    assert_equal Grille.new('K7Q2MZXB4P'), Grille.new(' k7q2m-zxb4p ')
    assert_equal '10000-00000', Grille.new('lO000-0000o').to_s # Crockford's look-alikes: l and I for 1, O for 0
  end

  def test_a_malformed_key_says_what_a_key_looks_like
    ['', 'K7Q2M', 'K7Q2M-ZXB4PP', 'K7Q2M-ZXB4U', 'K7Q2M-ZXB4!'].each do |key|
      error = assert_raises(Cistergraphia::Error, key) { Grille.new(key) }
      assert_includes error.message, KEY
    end
  end

  def test_generated_keys_are_valid_and_different
    keys = Array.new(50) { Grille.generate }

    assert(keys.all? { |grille| grille.to_s.match?(/\A[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}\z/) })
    assert_equal 50, keys.uniq.size
  end

  def test_orbits_cover_the_plate_four_cells_at_a_time
    orbits = Grille.orbits(6)

    assert_equal 9, orbits.size
    assert(orbits.all? { |orbit| orbit.uniq.size == 4 })
    assert_equal (0...6).to_a.product((0...6).to_a), orbits.flatten(1).sort
    assert_raises(Cistergraphia::Error) { Grille.orbits(5) } # an odd side has a centre that never turns
  end

  def test_four_turns_read_every_cell_exactly_once
    [2, 4, 6, 10, 18, 32].each do |size|
      grille = Grille.generate
      path = grille.path(size)

      assert_equal size * size, path.size
      assert_equal (0...size).to_a.product((0...size).to_a), path.sort, "#{size} x #{size}"
      (0..3).each { |turn| assert_equal size * size / 4, grille.holes(size, turn).size }
    end
  end

  def test_turning_the_grille_moves_its_holes_a_quarter_clockwise
    grille = Grille.new(KEY)
    turned = grille.holes(8).map { |cell| Grille.quarter_turn(cell, 8) }.sort

    assert_equal grille.holes(8, 1), turned
    assert_equal [[0, 7]], [Grille.quarter_turn([0, 0], 8)] # the top-left corner goes to the top-right
  end

  def test_holes_are_read_row_by_row
    holes = Grille.new(KEY).holes(10, 2)

    assert_equal holes.sort, holes
  end

  def test_the_key_sets_the_grille_for_every_plate_size
    assert_equal Grille.new(KEY).holes(10), Grille.new(KEY).holes(10)
    refute_equal Grille.new(KEY).holes(10), Grille.new('K7Q2M-ZXB4Q').holes(10)
    assert_equal 256, Grille.new(KEY).holes_by_orbit(32).size # past one digest's 128 holes
    assert(Grille.new(KEY).holes_by_orbit(32).all? { |hole| hole.between?(0, 3) })
  end

  def test_a_game_plate_reads_back_with_its_grille_and_only_with_it
    grille = Grille.new(KEY)
    _sequence, svg = Cistergraphia.inscribe('Meet me at the abbey after vespers', layout: grille)

    assert_equal 'meet me at the abbey after vespers', Cistergraphia.decode(svg, layout: grille)
    assert_raises(Cistergraphia::GrilleKeyNeededError) { Cistergraphia.decode(svg) }
    error = assert_raises(Cistergraphia::WrongGrilleError) { Cistergraphia.decode(svg, layout: Grille.new('00000-00000')) }
    assert_equal Grille::WRONG_KEY, error.message
  end

  def test_a_sealed_plate_under_a_grille_has_an_even_side
    grille = Grille.new(KEY)
    [1, 30, 60, 120].each do |length|
      sequence, svg = Cistergraphia.inscribe('x' * length, passphrase: 'abbey of molesme', layout: grille)

      assert_predicate Integer.sqrt(sequence.size), :even?
      assert_equal 'x' * length, Cistergraphia.decode(svg, passphrase: 'abbey of molesme', layout: grille)
    end
  end

  def test_a_grille_plate_is_square_and_the_others_are_not
    _, under_grille = Cistergraphia.inscribe('ora et labora', layout: Grille.new(KEY))
    _, snail = Cistergraphia.inscribe('ora et labora')

    assert Cistergraphia::SVG.square?(under_grille)
    refute Cistergraphia::SVG.square?(snail)
    error = assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decode(snail, layout: Grille.new(KEY)) }
    assert_equal 'This plate was not written under a grille', error.message
  end

  def test_signs_sit_in_the_middle_of_their_square_cells
    x, y = Cistergraphia::Layout.origin(0, 0, Grille.new(KEY))

    assert_equal [50 + 35, 50 + 10], [x, y] # 170 x 170 cells for 100 x 150 signs
  end

  def test_the_stencil_is_cut_where_the_grille_reads_first
    grille = Grille.new(KEY)
    sequence, plate = Cistergraphia.inscribe('ora et labora', layout: grille)
    size = Integer.sqrt(sequence.size)
    stencil = REXML::Document.new(Cistergraphia::SVG.stencil(size, grille)).root
    holes = stencil.get_elements('//path').first['d'].scan(/M(\d+) (\d+)h154/).map { |x, y| [x.to_i, y.to_i] }

    assert_equal REXML::Document.new(plate).root['width'], stencil['width']
    expected = grille.holes(size).map { |row, col| [50 + (170 * col) + 8, 50 + (170 * row) + 8] }
    assert_equal expected, holes
    assert_includes stencil.to_s, "Grille #{KEY}"
  end
end

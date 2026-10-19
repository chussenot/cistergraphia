# frozen_string_literal: true

require 'test_helper'

class TwoReadersTest < Minitest::Test
  Grille = Cistergraphia::Grille
  TwoReaders = Cistergraphia::TwoReaders
  KEY = 'K7Q2M-ZXB4P'

  def test_the_novice_key_is_drawn_from_the_abbot_key_and_not_the_other_way
    abbot = Grille.new(KEY)

    assert_equal abbot.novice, Grille.new(KEY).novice # always the same
    refute_equal abbot.code, abbot.novice.code
    refute_equal abbot.code, Grille.new(abbot.novice.code).novice.code # the novice's key leads elsewhere
  end

  def test_the_two_grilles_share_the_orbits_without_overlap
    [2, 6, 10, 32].each do |size|
      abbot = Grille.new(KEY).as(:abbot).pierced(size)
      novice = Grille.new(KEY).novice.pierced(size)

      assert_empty abbot & novice
      assert_equal (0...(size * size / 4)).to_a, (abbot + novice).sort
    end
  end

  def test_a_plate_with_two_readers_is_read_once_through_both_grilles
    size = 12
    path = Grille.new(KEY).as(:pair).path(size)

    assert_equal size * size, path.uniq.size # every cell once: the abbot's share, then the novice's
  end

  def test_a_whole_grille_reads_as_before
    assert_equal [3, 2, 0, 1, 3, 2, 1, 0, 2], Grille.new(KEY).holes_by_orbit(6) # plates already made still read
    assert_equal 36, Grille.new(KEY).path(6).uniq.size
  end

  def test_the_abbot_reads_both_messages_and_the_novice_only_the_decoy
    _sequence, svg, abbot = TwoReaders.inscribe('Relics lie under the third pillar', 'Vespers at six in the choir')

    reading = TwoReaders.read(svg, abbot)
    assert_equal ['relics lie under the third pillar', 'vespers at six in the choir', :abbot], reading.to_a
    reading = TwoReaders.read(svg, Grille.new(abbot.novice.code))
    assert_equal ['vespers at six in the choir', nil, :novice], reading.to_a
  end

  def test_sealed_plates_with_two_readers
    passphrase = 'abbey of molesme'
    _sequence, svg, abbot = TwoReaders.inscribe('Les reliques sont à Cîteaux', 'Vêpres à six heures',
                                                passphrase: passphrase)

    assert_equal ['Les reliques sont à Cîteaux', 'Vêpres à six heures', :abbot],
                 TwoReaders.read(svg, abbot, passphrase: passphrase).to_a
    assert_raises(Cistergraphia::WrongGrilleError) { TwoReaders.read(svg, abbot, passphrase: 'not the passphrase') }
  end

  def test_the_passphrase_alone_does_not_open_the_abbots_share
    passphrase = 'abbey of molesme'
    _sequence, svg, abbot = TwoReaders.inscribe('Les reliques sont à Cîteaux', 'Vêpres', passphrase: passphrase)
    share = Cistergraphia::SVG.read(svg, layout: abbot.as(:abbot)) # the cells a novice knows are the abbot's

    assert_raises(Cistergraphia::DecodeError) { Cistergraphia::Secret.decrypt(share, passphrase) }
    assert_equal 'Les reliques sont à Cîteaux',
                 Cistergraphia::Secret.decrypt(share, TwoReaders.abbots_passphrase(passphrase, abbot))
  end

  def test_an_ordinary_grille_plate_reads_whole
    grille = Grille.new(KEY)
    _sequence, svg = Cistergraphia.inscribe('Ora et labora', layout: grille)

    assert_equal ['ora et labora', nil, :whole], TwoReaders.read(svg, grille).to_a
  end

  def test_a_wrong_key_or_no_key_reads_nothing
    _sequence, svg, = TwoReaders.inscribe('Relics', 'Vespers', grille: Grille.new(KEY))

    assert_raises(Cistergraphia::GrilleKeyNeededError) { Cistergraphia.decode(svg) }
    assert_raises(Cistergraphia::WrongGrilleError) { TwoReaders.read(svg, Grille.new('00000-00000')) }
  end

  def test_a_given_key_grows_the_plate_until_both_messages_fit
    long = 'the brothers will gather in the chapter house after compline' * 2
    sequence, svg, abbot = TwoReaders.inscribe(long, 'vespers', grille: Grille.new(KEY))

    assert_equal Grille.new(KEY), abbot
    assert_predicate Integer.sqrt(sequence.size), :even?
    assert_equal long.squeeze(' '), TwoReaders.read(svg, abbot).message
  end

  def test_both_stencils_are_cut_from_one_plate
    size = 10
    abbot = Cistergraphia::SVG.stencil(size, Grille.new(KEY).as(:abbot))
    novice = Cistergraphia::SVG.stencil(size, Grille.new(KEY).novice)

    assert_equal Grille.new(KEY).as(:abbot).pierced(size).size, abbot.scan('h154v154').size
    assert_equal Grille.new(KEY).novice.pierced(size).size, novice.scan('h154v154').size
  end
end

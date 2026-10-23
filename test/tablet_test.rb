# frozen_string_literal: true

require 'test_helper'

class TabletTest < Minitest::Test
  C = Cistergraphia
  Tablet = Cistergraphia::Tablet
  SEED = 'K7Q2M-ZXB4P'

  def test_a_seed_draws_the_shared_values_dealt_out_again_and_always_the_same
    tablet = Tablet.draw(SEED)

    assert_equal C::CHARACTERS.keys.sort, tablet.values.sort
    assert_equal C::TABLET.keys.map(&:to_s), tablet.keys
    assert_equal tablet, Tablet.draw(SEED)
    assert_equal tablet, Tablet.draw('k7q2m zxb4p'), 'any case, spaces and dashes'
    assert_equal Tablet.draw('K7Q2MZXB4P'), Tablet.draw('K7Q2MZXB4P'.tr('0', 'O')), 'look-alikes read as digits'
    refute_equal tablet, Tablet.draw(Tablet.generate)
    assert_equal tablet.invert, Tablet.characters(SEED)
    assert_equal tablet.to_a, Tablet.rows(SEED)
    assert_equal 'K7Q2M-ZXB4P', Tablet.show('k7q2mzxb4p')
  end

  def test_a_seed_is_ten_letters_and_digits_in_the_grille_key_alphabet
    assert_equal 10, Tablet.generate.length
    assert_match(/\A[#{Tablet::ALPHABET}]{10}\z/, Tablet.generate)
    %w[abbey K7Q2M-ZXB4 K7Q2M-ZXB4PU].each do |bad|
      error = assert_raises(C::Error) { Tablet.draw(bad) }

      assert_equal Tablet::NOT_A_SEED, error.message
    end
  end

  def test_a_plate_with_its_own_tablet_reads_by_its_seed_and_as_nonsense_without
    message = 'Meet me at the old abbey after vespers'
    C::Layout::KEYLESS.each do |way|
      sequence, svg = C.inscribe(message, layout: way, tablet: SEED)

      assert_equal SEED.delete('-'), Tablet.seed_of(svg)
      assert_equal C.normalize(message), C.decode(svg), way
      assert_equal C.normalize(message), C.decipher(sequence, tablet: SEED)
      shared = C.decipher(sequence)

      assert_equal C.normalize(message).size, shared.size, 'every pair still lands on a tablet value'
      refute_equal C.normalize(message), shared, 'but the letters are another tablet\'s'
    end
  end

  def test_a_pathless_plate_may_have_its_own_tablet_too
    _, svg = C.inscribe('the relics are under the third stone', layout: :unwinding, pathless: true, tablet: SEED)

    assert C::Pathless.pathless?(svg)
    assert_equal 'the relics are under the third stone', C.decode(svg),
                 'the way by the pair test, the letters by the seed'
  end

  def test_a_plate_on_the_shared_tablet_carries_no_seed
    _, svg = C.inscribe('ora et labora')

    assert_nil Tablet.seed_of(svg)
    refute_includes svg, Tablet::ATTRIBUTE
  end

  def test_the_plates_that_cannot_have_a_tablet_of_their_own
    sealed = assert_raises(C::Error) { C.inscribe('abbey', passphrase: 'molesme', tablet: SEED) }
    grilled = assert_raises(C::Error) { C.inscribe('abbey', layout: C::Grille.new('K7Q2M-ZXB4P'), tablet: SEED) }
    damaged = assert_raises(C::Error) { Tablet.check(nil, :phaistos, damaged: true) }

    assert_equal [Tablet::NOT_SEALED, Tablet::NOT_UNDER_A_GRILLE, Tablet::NOT_DAMAGED],
                 [sealed, grilled, damaged].map(&:message)
  end
end

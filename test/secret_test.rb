# frozen_string_literal: true

require 'test_helper'

class SecretTest < Minitest::Test
  PASSPHRASE = 'correct horse battery staple'

  def round_trip(message, passphrase = PASSPHRASE)
    svg = Cistergraphia.to_svg(Cistergraphia.encode(message, passphrase: passphrase))
    Cistergraphia.decode(svg, passphrase: passphrase)
  end

  def test_round_trip_keeps_the_exact_message
    message = "Rendez-vous à 23h00, porte nord — 7 moines 🙏\nNo normalisation: CAPS, digits & punctuation!"

    assert_equal message, round_trip(message)
  end

  def test_sequence_is_a_perfect_square_of_valid_glyph_values
    sequence = Cistergraphia.encode('meet me at dawn', passphrase: PASSPHRASE)

    assert Cistergraphia.perfect_square?(sequence.size)
    assert(sequence.all? { |n| n.between?(0, 9999) })
  end

  def test_same_message_gives_a_different_image_every_time
    a = Cistergraphia.encode('same message', passphrase: PASSPHRASE)
    b = Cistergraphia.encode('same message', passphrase: PASSPHRASE)

    refute_equal a, b
  end

  def test_wrong_passphrase_is_rejected
    svg = Cistergraphia.to_svg(Cistergraphia.encode('top secret', passphrase: PASSPHRASE))

    error = assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decode(svg, passphrase: 'correct horse battery stapler') }
    assert_match(/Wrong passphrase/, error.message)
  end

  def test_any_altered_glyph_is_detected
    sequence = Cistergraphia.encode('top secret', passphrase: PASSPHRASE)
    length = (sequence[0] * 10_000) + sequence[1]

    [2, 2 + (length / 2), 1 + length].each do |index| # header, middle and tag
      tampered = sequence.dup
      tampered[index] = (tampered[index] + 1) % 10_000

      assert_raises(Cistergraphia::DecodeError, "glyph #{index}") { Cistergraphia::Secret.decrypt(tampered, PASSPHRASE) }
    end
  end

  def test_padding_glyphs_are_not_authenticated_but_not_needed_either
    message = sequence = nil
    (1..20).each do |n| # find a length whose grid needs padding
      message = 'x' * n
      sequence = Cistergraphia.encode(message, passphrase: PASSPHRASE)
      break if sequence.size > 2 + (sequence[0] * 10_000) + sequence[1]
    end
    sequence[-1] = (sequence[-1] + 1) % 10_000

    assert_equal message, Cistergraphia::Secret.decrypt(sequence, PASSPHRASE)
  end

  def test_short_passphrases_are_refused
    error = assert_raises(Cistergraphia::Error) { Cistergraphia.encode('hello', passphrase: 'short') }
    assert_match(/at least 8/, error.message)
  end

  def test_passphrase_problem_explains_the_rule
    assert_equal 'Secret mode needs a passphrase', Cistergraphia::Secret.passphrase_problem('')
    assert_equal 'A passphrase needs at least 8 characters', Cistergraphia::Secret.passphrase_problem('1234567')
    assert_nil Cistergraphia::Secret.passphrase_problem('12345678')
    assert_nil Cistergraphia::Secret.passphrase_problem('🙏' * 8) # characters, not bytes
  end

  def test_a_short_passphrase_never_opens_a_plate
    sequence = Cistergraphia.encode('top secret', passphrase: PASSPHRASE)

    assert_raises(Cistergraphia::WrongPassphraseError) { Cistergraphia::Secret.decrypt(sequence, 'short') }
  end

  def test_empty_message_is_refused
    assert_raises(Cistergraphia::EmptyMessageError) { Cistergraphia.encode("  \n ", passphrase: PASSPHRASE) }
  end

  # A sealed plate's values are the ciphertext's base-10000 digits, uniform over
  # 0..9999: one may be 9999 by chance (about one 100-sign plate in sixty), so
  # the game's structure is tested by its pairs. In a game every letter's pair
  # sums to a multiple of ten (only the null pairs do not: 82% of this plate's
  # pairs); in a sealed plate one pair in ten does by chance (measured on 300
  # plates: 10% on average, 22% at most)
  def test_secret_images_carry_none_of_the_game_structure
    sequence = Cistergraphia.encode('the abbot will travel north at dawn' * 3, passphrase: PASSPHRASE)
    pairs = sequence.each_slice(2).to_a
    balanced = pairs.count { |a, b| ((a + b) % 10).zero? }.fdiv(pairs.size)

    assert_operator balanced, :<, 0.5, 'no pair structure: a game plate balances every letter'
    assert_raises(Cistergraphia::DecodeError) { Cistergraphia.decipher(sequence) }
  end

  def test_unknown_format_version_is_rejected
    payload = "\x02".b + ("\x00".b * 60)
    sequence = Cistergraphia::Secret.to_digits(payload)

    error = assert_raises(Cistergraphia::DecodeError) do
      Cistergraphia::Secret.decrypt([sequence.size / 10_000, sequence.size % 10_000, *sequence], PASSPHRASE)
    end
    assert_match(/version 2/, error.message)
  end

  def test_truncated_sequences_are_rejected
    sequence = Cistergraphia.encode('top secret', passphrase: PASSPHRASE)

    assert_raises(Cistergraphia::DecodeError) { Cistergraphia::Secret.decrypt(sequence.first(5), PASSPHRASE) }
    assert_raises(Cistergraphia::DecodeError) { Cistergraphia::Secret.decrypt([9], PASSPHRASE) }
  end

  def test_digits_round_trip_keeps_leading_zero_bytes
    bytes = "\x00\x00\xFF\x00".b

    assert_equal bytes, Cistergraphia::Secret.from_digits(Cistergraphia::Secret.to_digits(bytes))
  end

  def test_the_sealed_size_has_an_upper_bound_without_sealing
    ['a', 'Les reliques sont à Cîteaux', 'x' * 500].each do |message|
      sizes = Array.new(5) { Cistergraphia::Secret.seal_to_digits(message, PASSPHRASE).size }

      assert_operator sizes.max, :<=, Cistergraphia::Secret.max_sealed_size(message)
      assert_operator sizes.min, :>=, Cistergraphia::Secret.max_sealed_size(message) - 1
    end
  end
end

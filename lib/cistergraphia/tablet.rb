# frozen_string_literal: true

require 'digest'
require 'securerandom'

module Cistergraphia
  # A plate's tablet of values. Every plate reads by a tablet, the mapping of
  # the twenty-seven characters (the letters and the space) to their values;
  # the shared one is TABLET. A plate may have a tablet of its own: the same
  # values dealt out again, drawn from a seed the file carries on its root
  # (data-tablet). Its reader must build the tablet in the notebook, sum by
  # sum; the decoder reads the seed and needs nothing else.
  #
  # Design Decisions:
  # - The values are the shared tablet's, only permuted: the pairs still sum to
  #   a value on the tablet, so the way is still found by the pair test and the
  #   null marks still read, under any tablet
  # - The seed is written in the grille key's alphabet and length, and
  #   normalised the same way (case, dashes, the look-alikes O, I and L)
  # - The permutation is drawn by a Fisher-Yates shuffle from a Random seeded by
  #   the SHA-256 of the seed, so every Ruby draws the same tablet
  # - A game's plate only, intact, under a keyless way: a sealed plate has no
  #   tablet to find, a grille plate has a key already, and the bench and the
  #   board speak in letters
  module Tablet
    ALPHABET = Grille::ALPHABET
    LENGTH = Grille::LENGTH
    ATTRIBUTE = 'data-tablet'
    SHORT = 6 # words: under this, a plate with its own tablet is close to guessing (docs/design.md)
    NOT_SEALED = 'A sealed plate has no tablet to find: its passphrase is the whole key'
    NOT_UNDER_A_GRILLE = 'A grille plate has a key already: one key at a time'
    NOT_DAMAGED = 'A worn or broken plate keeps the shared tablet: the bench and the board speak in letters'
    NOT_A_SEED = "A tablet's seed has #{LENGTH} letters and digits, as a grille key".freeze
    NOT_PATHLESS = 'One thing to find at a time: a pathless plate keeps the shared tablet'

    module_function

    # A new seed, at random
    def generate
      Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join
    end

    # A seed as written anywhere: any case, spaces and dashes, O for 0, I or L for 1
    def normalize(seed)
      code = seed.to_s.upcase.delete(" \t-").gsub(/[OIL]/, Grille::LOOK_ALIKES)
      raise Error, NOT_A_SEED unless code.length == LENGTH && code.delete(ALPHABET).empty?

      code
    end

    # A seed as shown: in two halves, as a grille key
    def show(seed)
      code = normalize(seed)
      "#{code[0, LENGTH / 2]}-#{code[LENGTH / 2, LENGTH / 2]}"
    end

    # The tablet a seed draws: character => value, the shared values dealt out again
    def draw(seed)
      random = Random.new(Digest::SHA256.hexdigest("cistergraphia tablet #{normalize(seed)}").to_i(16))
      TABLET.keys.map(&:to_s).zip(shuffle(CHARACTERS.keys, random)).to_h
    end

    # Fisher-Yates, written out so that every Ruby deals the same
    def shuffle(items, random)
      items = items.dup
      (items.size - 1).downto(1) do |i|
        j = random.rand(i + 1)
        items[i], items[j] = items[j], items[i]
      end
      items
    end

    # value => character, for reading a plate written with this tablet
    def characters(seed)
      draw(seed).invert
    end

    # The rows of a tablet for a page or a terminal: [character, value], in the shared tablet's order
    def rows(seed)
      draw(seed).to_a
    end

    # The seed a plate's file carries, or nil for a plate on the shared tablet
    # (a string test on the root's attribute, as Pathless reads its class)
    def seed_of(svg)
      svg.to_s[/<svg\b[^>]*\s#{ATTRIBUTE}="([^"]+)"/, 1]
    end

    # The plates that cannot have a tablet of their own, in the library's words
    def check(passphrase, layout, damaged: false)
      raise Error, NOT_SEALED if passphrase
      raise Error, NOT_UNDER_A_GRILLE if layout.is_a?(Grille)
      raise Error, NOT_DAMAGED if damaged
    end
  end
end

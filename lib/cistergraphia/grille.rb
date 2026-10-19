# frozen_string_literal: true

require 'digest'
require 'securerandom'

module Cistergraphia
  # The turning grille, a third way to read a plate (after Cardano's stencil of
  # 1550 and Fleissner's turning grille of 1881, the one in Jules Verne's
  # Mathias Sandorf). The plate is laid out like a page; a square parchment
  # pierced with holes is laid on it; the signs under the holes are read row by
  # row; then the parchment is turned a quarter clockwise, four times: N, E, S, W.
  #
  # An n x n plate (n even) splits into n²/4 orbits: a cell of its top-left
  # quarter and the three cells it visits as the plate turns by quarters. The
  # grille pierces exactly one cell of each orbit, so its four turns uncover
  # every cell once: the whole plate is the message, in the grille's order.
  #
  # The key is a code of 10 characters (50 bits, Crockford's base 32) that sets
  # the grille for a plate of any size: each orbit's hole is drawn from SHA-256
  # of the code and the plate's side. Read without the grille, a plate is an
  # anagram of its own message. A turning grille is a transposition cipher of
  # the 19th century, not secrecy: see docs/security-study.md.
  class Grille
    ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
    LOOK_ALIKES = { 'O' => '0', 'I' => '1', 'L' => '1' }.freeze
    LENGTH = 10
    EXAMPLE = 'K7Q2M-ZXB4P'
    TURNS = %w[N E S W].freeze
    WRONG_KEY = 'This grille does not read this plate: check its key'
    WRONG_KEY_OR_PASSPHRASE = 'Wrong grille key or passphrase, or the plate was altered'

    attr_reader :code

    def self.generate
      new(Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join)
    end

    # The cells of an n x n plate by orbit: each [row, col] of its top-left
    # quarter, followed by where a quarter turn clockwise takes it, three times
    def self.orbits(size)
      raise Error, 'A grille needs a plate with an even side' if size.odd?

      half = (0...(size / 2)).to_a
      half.product(half).map do |cell|
        (1..3).each_with_object([cell]) { |_, orbit| orbit << quarter_turn(orbit.last, size) }
      end
    end

    def self.quarter_turn((row, col), size)
      [col, size - 1 - row]
    end

    # A square plate needs its grille, and a grille needs a square plate
    def self.check(svg, layout)
      square = SVG.square?(svg)
      raise GrilleKeyNeededError, 'This plate was written under a grille: it needs its key' if square && layout.nil?
      raise DecodeError, 'This plate was not written under a grille' if layout.is_a?(Grille) && !square
    end

    # Any case, spaces and dashes are fine, and so are the look-alikes Crockford
    # allows (O for 0, I or L for 1)
    def initialize(key)
      @code = key.to_s.upcase.delete(" \t-").gsub(/[OIL]/, LOOK_ALIKES)
      return if @code.length == LENGTH && @code.delete(ALPHABET).empty?

      raise Error, "A grille key has #{LENGTH} letters and digits, like #{EXAMPLE}"
    end

    def to_s
      "#{code[0, 5]}-#{code[5, 5]}"
    end

    def ==(other)
      other.is_a?(Grille) && other.code == code
    end
    alias eql? ==

    def hash
      code.hash
    end

    # Which of its four cells is pierced (0..3), orbit by orbit, on an n x n plate
    def holes_by_orbit(size)
      count = size * size / 4
      blocks = count.ceildiv(4 * 32) # four holes per byte, 32 bytes per digest
      bytes = (0...blocks).flat_map { |block| Digest::SHA256.digest("cistergraphia-grille:#{code}:#{size}:#{block}").bytes }
      bytes.flat_map { |byte| [byte >> 6, (byte >> 4) & 3, (byte >> 2) & 3, byte & 3] }.first(count)
    end

    # [row, col] of the holes with the grille turned clockwise by `turn` quarters, row by row
    def holes(size, turn = 0)
      Grille.orbits(size).zip(holes_by_orbit(size)).map { |orbit, pierced| orbit[(pierced + turn) % 4] }.sort
    end

    # Every cell of the plate in the order the grille reads them: the holes at N,
    # then at E, S and W
    def path(size)
      (0..3).flat_map { |turn| holes(size, turn) }
    end
  end
end

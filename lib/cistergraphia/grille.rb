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

    PARTS = %i[whole abbot novice pair].freeze

    attr_reader :code, :part

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
    # allows (O for 0, I or L for 1). The part is which orbits the grille
    # pierces: all of them (:whole), or, on a plate with two readers, the
    # abbot's or the novice's; :pair is that plate, both read in turn
    def initialize(key, part: :whole)
      @code = key.to_s.upcase.delete(" \t-").gsub(/[OIL]/, LOOK_ALIKES)
      @part = PARTS.include?(part) ? part : raise(Error, "Unknown grille part #{part.inspect}")
      return if @code.length == LENGTH && @code.delete(ALPHABET).empty?

      raise Error, "A grille key has #{LENGTH} letters and digits, like #{EXAMPLE}"
    end

    def to_s
      "#{code[0, 5]}-#{code[5, 5]}"
    end

    def ==(other)
      other.is_a?(Grille) && other.code == code && other.part == part
    end
    alias eql? ==

    def hash
      [code, part].hash
    end

    # The same key for another part of a plate with two readers
    def as(part)
      Grille.new(code, part: part)
    end

    # The novice's grille, drawn from this one's key (the abbot's) by SHA-256:
    # whoever has the abbot's key has both, the novice's key gives only its own
    def novice
      bits = Digest::SHA256.digest("cistergraphia-novice:#{code}").unpack1('B*')
      Grille.new(bits[0, LENGTH * 5].scan(/.{5}/).map { |chunk| ALPHABET[chunk.to_i(2)] }.join, part: :novice)
    end

    # The orbits this grille pierces on an n x n plate. The novice's are about
    # half of them, drawn from the novice's key; the abbot's are the others
    def pierced(size)
      all = (0...(size * size / 4)).to_a
      case part
      when :novice then all.select { |orbit| novice_share(size)[orbit] }
      when :abbot then all.reject { |orbit| novice.novice_share(size)[orbit] }
      else all
      end
    end

    # Which of its four cells is pierced (0..3), orbit by orbit, on an n x n plate
    def holes_by_orbit(size)
      stream("cistergraphia-grille:#{code}:#{size}", size * size / 4)
    end

    # [row, col] of the holes with the grille turned clockwise by `turn` quarters, row by row
    def holes(size, turn = 0)
      orbits = Grille.orbits(size)
      by_orbit = holes_by_orbit(size)
      pierced(size).map { |orbit| orbits[orbit][(by_orbit[orbit] + turn) % 4] }.sort
    end

    # The cells of the plate this grille reads, in its order: the holes at N,
    # then at E, S and W. A plate with two readers reads the abbot's, then the novice's
    def path(size)
      return as(:abbot).path(size) + novice.path(size) if part == :pair

      (0..3).flat_map { |turn| holes(size, turn) }
    end

    protected

    # One bit per orbit, from this key: true for the novice's orbits
    def novice_share(size)
      stream("cistergraphia-share:#{code}:#{size}", size * size / 4).map(&:odd?)
    end

    private

    # `count` numbers from 0 to 3, drawn from SHA-256 of the label
    def stream(label, count)
      blocks = count.ceildiv(4 * 32) # four per byte, 32 bytes per digest
      bytes = (0...blocks).flat_map { |block| Digest::SHA256.digest("#{label}:#{block}").bytes }
      bytes.flat_map { |byte| [byte >> 6, (byte >> 4) & 3, (byte >> 2) & 3, byte & 3] }.first(count)
    end
  end
end

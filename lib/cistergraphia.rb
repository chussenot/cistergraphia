# frozen_string_literal: true

# Cistergraphia Core Module
# ========================
#
# Purpose:
# - Encrypt a message into Cistercian numerals laid out as a snail (spiral)
# - Decrypt an SVG produced by this module back into the message
# - Two modes: the game (a keyless cipher meant to be cracked, see
#   docs/security-study.md) and secret mode (passphrase, AES-256-GCM)
#
# Design Decisions:
# - Module-based design for encapsulation
# - Glyph geometry lives in Cistergraphia::Glyphs, SVG layout and parsing in
#   Cistergraphia::SVG, secret mode in Cistergraphia::Secret; this file holds
#   the game cipher and the public entry points
# - Each character value is split into two random parts (same message, a
#   different picture every time)
# - 'Evil' pairs [noise, 9999] pad the sequence to a perfect square; 9999 can
#   never come from a character, so the decoder can drop them reliably
# - The sequence is laid out along one of two reading paths (layouts):
#   Phaistos, a clockwise spiral from the top-left to the centre (default), or
#   Rongorongo, reverse boustrophedon: rows from the bottom, every other row
#   running back with its signs turned half round. The decoder tries both;
#   #inscribe redraws any game plate that would read along both
#
# Constraints:
# - Limited to the characters defined in TABLET; anything else is a separator
# - Symbol dimensions are fixed (100x150)
# - Grid must be a perfect square
# - Only SVGs rendered by this module can be decoded (geometry is matched exactly)

module Cistergraphia
  # Base class for every error raised on bad user input
  class Error < ArgumentError; end

  # Raised when a message contains nothing that can be enciphered
  class EmptyMessageError < Error; end

  # Raised when an SVG or a sequence cannot be deciphered
  class DecodeError < Error; end

  # Raised when a secret plate does not open with the passphrase given
  class WrongPassphraseError < DecodeError; end

  EVIL_MARKER = 9999 # Never produced by a character (max value is 9000)

  # Mapping of characters to numerical values
  TABLET = {
    a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9, j: 10,
    k: 11, l: 12, m: 13, n: 14, o: 15, p: 16, q: 18, r: 19, s: 100,
    t: 200, u: 300, v: 400, w: 500, x: 600, y: 700, z: 800, ' ': 900
  }.freeze

  # Value => character, for decoding
  CHARACTERS = TABLET.to_h { |char, value| [value * 10, char.to_s] }.freeze

  module_function

  # Lower-cases the message and turns everything missing from TABLET into single spaces
  def normalize(message)
    message.to_s.downcase.gsub(/[^a-z ]/, ' ').squeeze(' ').strip
  end

  # Full pipeline: message => sequence padded to a perfect square.
  # With a passphrase the message is encrypted (secret mode), otherwise enciphered (game).
  def encode(message, passphrase: nil)
    return Secret.encrypt(message, passphrase) if passphrase

    sequence = cister(message)
    inject_evil_symbols(sequence) until perfect_square?(sequence.size)
    sequence
  end

  # Full pipeline: SVG rendered by #to_svg => message (normalized in game mode).
  # Without a layout, both are tried: only the right one yields letters (game)
  # or passes authentication (secret).
  def decode(svg, passphrase: nil, layout: nil)
    errors = (layout ? [layout] : SVG::LAYOUTS).map do |candidate|
      sequence = SVG.read(svg, layout: candidate)
      return passphrase ? Secret.decrypt(sequence, passphrase) : decipher(sequence)
    rescue DecodeError => e
      e
    end
    raise errors.find { |e| e.is_a?(WrongPassphraseError) } || errors.first
  end

  # Message => [sequence, SVG plate] along a layout. In game mode, a plate that
  # would also read as letters along another layout (short messages, about 1 in
  # 100 two-letter ones) is drawn again with new random splits, so the
  # decoder's layout detection is never wrong. Secret plates need no check: the
  # wrong layout fails authentication instead of yielding a false message.
  def inscribe(message, passphrase: nil, layout: :phaistos)
    100.times do
      sequence = encode(message, passphrase: passphrase)
      svg = to_svg(sequence, layout: layout)
      return [sequence, svg] if passphrase || unambiguous?(svg, layout)
    end
    raise Error, 'Could not draw an unambiguous plate for this message'
  end

  # True when the plate reads as letters along its own layout only
  def unambiguous?(svg, layout)
    (SVG::LAYOUTS - [layout]).none? do |other|
      decipher(SVG.read(svg, layout: other))
    rescue DecodeError
      false
    end
  end

  # Renders a sequence as an SVG document along a layout's reading path
  def to_svg(sequence, layout: :phaistos)
    SVG.render(sequence, layout: layout)
  end

  # Converts a message into a sequence of numbers using the TABLET mapping
  def cister(message)
    chars = normalize(message).chars
    raise EmptyMessageError, 'Message has no characters that can be enciphered' if chars.empty?

    chars.map { |c| TABLET.fetch(c.to_sym) * 10 }
         .flat_map { |n| split(n) }
  end

  # Inverse of #encode: drops evil symbols and joins the pairs back
  def decipher(sequence)
    values = strip_evil_symbols(sequence)
    raise DecodeError, 'No enciphered characters found' if values.empty?
    raise DecodeError, 'Sequence has an odd number of values' if values.size.odd?

    values.each_slice(2).map do |a, b|
      CHARACTERS.fetch(a + b) { raise DecodeError, "#{a} + #{b} is not a known character" }
    end.join
  end

  # Splits a number into two random parts that add up to it
  def split(num)
    part = rand(num)
    [num - part, part].shuffle
  end

  # Reads an array of rows in a snail pattern (clockwise spiral from the top-left)
  def snail(matrix)
    return [] if matrix.empty?

    matrix.first + snail(matrix.drop(1).transpose.reverse)
  end

  # [row, col] of each grid cell, in snail order
  def spiral_coordinates(size)
    snail(Array.new(size) { |row| Array.new(size) { |col| [row, col] } })
  end

  # [row, col, turned] of each grid cell in reverse boustrophedon order, the
  # rongorongo way: rows from the bottom, left to right, then the tablet turns
  # half round, so every other row runs back with its signs upside down
  def boustrophedon_coordinates(size)
    (size - 1).downto(0).each_with_index.flat_map do |row, k|
      cols = k.even? ? (0...size).to_a : (size - 1).downto(0).to_a
      cols.map { |col| [row, col, k.odd?] }
    end
  end

  # Inserts a pair of 'evil' symbols between two character pairs
  def inject_evil_symbols(array)
    array.insert(2 * rand(0..(array.length / 2)), rand(EVIL_MARKER), EVIL_MARKER)
  end

  # Removes every [noise, EVIL_MARKER] pair. Each marker removes the value right
  # before it, which also unwinds pairs nested inside other pairs.
  def strip_evil_symbols(sequence)
    sequence.each_with_object([]) do |value, kept|
      next kept << value unless value == EVIL_MARKER
      raise DecodeError, 'Evil symbol without its noise value' if kept.empty?

      kept.pop
    end
  end

  # Checks if a number is a perfect square (exact, no floating point)
  def perfect_square?(num)
    Integer.sqrt(num)**2 == num
  end
end

require_relative 'cistergraphia/glyphs'
require_relative 'cistergraphia/stylus'
require_relative 'cistergraphia/svg'
require_relative 'cistergraphia/secret'

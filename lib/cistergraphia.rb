# frozen_string_literal: true

# Cistergraphia Core Module
# ========================
#
# Purpose:
# - Encrypt a message into Cistercian numerals laid out as a snail (spiral)
# - Decrypt an SVG produced by this module back into the message
#
# Design Decisions:
# - Module-based design for encapsulation
# - Glyph geometry lives in Cistergraphia::Glyphs, SVG layout and parsing in
#   Cistergraphia::SVG; this file holds the cipher and the public entry points
# - Each character value is split into two random parts (same message, a
#   different picture every time)
# - 'Evil' pairs [noise, 9999] pad the sequence to a perfect square; 9999 can
#   never come from a character, so the decoder can drop them reliably
# - The sequence is laid out along a snail (clockwise spiral from the top-left)
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

  # Full pipeline: message => sequence padded to a perfect square
  def encode(message)
    sequence = cister(message)
    inject_evil_symbols(sequence) until perfect_square?(sequence.size)
    sequence
  end

  # Full pipeline: SVG rendered by #to_svg => message (normalized)
  def decode(svg)
    decipher(SVG.read(svg))
  end

  # Renders a sequence as an SVG document, laid out as a snail
  def to_svg(sequence)
    SVG.render(sequence)
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
require_relative 'cistergraphia/svg'

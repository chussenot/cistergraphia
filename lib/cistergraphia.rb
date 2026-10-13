# frozen_string_literal: true

# Cistergraphia Core Module
# ========================
#
# Purpose:
# - Core encryption logic for the Cistercian number system
# - SVG symbol generation and layout calculations
#
# Design Decisions:
# - Module-based design for encapsulation
# - Fixed symbol dimensions for consistent layout
# - Randomized number splitting for added complexity
# - Evil symbol injection for perfect square grid
# - Single SVG renderer shared by the CLI and the web app
#
# Constraints:
# - Limited to the characters defined in TABLET; anything else is a separator
# - Symbol dimensions are fixed (100x100)
# - Numbers must be converted to specific line patterns
# - Grid must be a perfect square

require 'nokogiri'

module Cistergraphia
  # Raised when a message contains nothing that can be enciphered
  class EmptyMessageError < ArgumentError; end

  # Constants for layout and symbol dimensions
  SPACE = 20
  PADDING = 50 # Add padding around the content
  SYMBOL_WIDTH = 100 # Width of each symbol
  SYMBOL_HEIGHT = 100 # Height of each symbol
  STROKE = { 'stroke' => 'black', 'stroke-width' => 2 }.freeze

  # Mapping of characters to numerical values
  TABLET = {
    a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9, j: 10,
    k: 11, l: 12, m: 13, n: 14, o: 15, p: 16, q: 18, r: 19, s: 100,
    t: 200, u: 300, v: 400, w: 500, x: 600, y: 700, z: 800, ' ': 900
  }.freeze

  # Strokes (x1, y1, x2, y2 relative to the symbol origin) and the place values
  # that use them. Compound digits (5, 7, 8, 9) are made of several strokes.
  STROKES = {
    [1, 5, 7, 9] => [50, 0, 100, 0],
    [2, 8, 9] => [50, 50, 100, 50],
    [3] => [50, 0, 100, 50],
    [4, 5] => [50, 50, 100, 0],
    [6, 7, 8, 9] => [100, 0, 100, 50],
    [10, 50, 70, 90] => [50, 0, 0, 0],
    [20, 80, 90] => [50, 50, 0, 50],
    [30] => [50, 0, 0, 50],
    [40, 50] => [50, 50, 0, 0],
    [60, 70, 80, 90] => [0, 50, 0, 0],
    [100, 500, 700, 900] => [50, 100, 100, 100],
    [200, 800, 900] => [50, 50, 100, 50],
    [300] => [50, 100, 100, 50],
    [400, 500] => [50, 50, 100, 100],
    [600, 700, 800, 900] => [100, 50, 100, 100],
    [1000, 5000, 7000, 9000] => [50, 100, 0, 100],
    [2000, 8000, 9000] => [50, 50, 0, 50],
    [3000] => [50, 100, 0, 50],
    [4000, 5000] => [50, 50, 0, 100],
    [6000, 7000, 8000, 9000] => [0, 50, 0, 100]
  }.freeze

  # Inverted STROKES: place value => list of strokes, built once at load time
  LINES = STROKES.each_with_object({}) do |(values, coords), lines|
    values.each { |value| (lines[value] ||= []) << coords.freeze }
  end.freeze

  module_function

  # Full pipeline: message => sequence padded to a perfect square
  def encode(message)
    sequence = cister(message)
    inject_evil_symbols(sequence) until perfect_square?(sequence.size)
    sequence
  end

  # Converts a message into a sequence of numbers using the TABLET mapping
  def cister(message)
    chars = message.to_s
                   .downcase
                   .gsub(/[^a-z ]/, ' ') # Characters missing from TABLET become separators
                   .squeeze(' ')
                   .strip
                   .chars
    raise EmptyMessageError, 'Message has no characters that can be enciphered' if chars.empty?

    chars.map { |c| TABLET.fetch(c.to_sym) * 10 }
         .flat_map { |n| split(n) }
  end

  # Splits a number into two random parts that add up to it
  def split(num)
    part = rand(num)
    [num - part, part].shuffle
  end

  # Breaks a number into its individual digits, each multiplied by its place value
  def digits(num)
    num.to_s.chars.reverse.map.with_index { |c, i| c.to_i * (10**i) }.reverse
  end

  # Arranges an array in a snail pattern (spiral order)
  def snail(array)
    return [] if array.empty?

    array.shift + snail(array.transpose.reverse)
  end

  # Randomly inserts a pair of 'evil' symbols into the array
  def inject_evil_symbols(array)
    array.insert(rand(0..array.length), [rand(9999), 9999]).flatten!
  end

  # Checks if a number is a perfect square (exact, no floating point)
  def perfect_square?(num)
    Integer.sqrt(num)**2 == num
  end

  # Calculates the dimensions needed to display the sequence in a grid
  def calculate_dimensions(sequence)
    cols = Integer.sqrt(sequence.size)
    raise EmptyMessageError, 'Cannot lay out an empty sequence' if cols.zero?

    rows = sequence.size.ceildiv(cols)
    width = ((SYMBOL_WIDTH + SPACE) * cols) + (PADDING * 2)
    height = ((SYMBOL_HEIGHT + SPACE) * rows) + (PADDING * 2)

    [width, height, cols, rows]
  end

  # Renders the sequence as a standalone SVG document
  def to_svg(sequence)
    width, height, cols, _rows = calculate_dimensions(sequence)

    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |doc|
      doc.svg(
        'xmlns' => 'http://www.w3.org/2000/svg',
        'version' => '1.1',
        'width' => width,
        'height' => height,
        'viewBox' => "0 0 #{width} #{height}"
      ) do
        doc.rect('width' => '100%', 'height' => '100%', 'fill' => 'white')
        doc.g(STROKE) { draw_grid(doc, sequence, cols) }
      end
    end.to_xml
  end

  # Draws the sequence row by row, `cols` symbols per row
  def draw_grid(doc, sequence, cols)
    sequence.each_slice(cols).with_index do |row, r|
      y = PADDING + ((SYMBOL_HEIGHT + SPACE) * r)
      row.each_with_index { |num, i| symbol(doc, digits(num), i, y) }
    end
  end

  # Draws a symbol at a specific position in the document
  def symbol(doc, ds, index, y = 0)
    x = PADDING + ((SYMBOL_WIDTH + SPACE) * index)
    # Main vertical stem of the symbol
    doc.line(x1: 50 + x, y1: y, x2: 50 + x, y2: SYMBOL_HEIGHT + y)
    ds.each { |num| draw_line(doc, num, x, y) }
  end

  # Draws every stroke making up a single place value (e.g. 9 => three strokes)
  def draw_line(doc, num, x, y)
    LINES.fetch(num, []).each do |x1, y1, x2, y2|
      doc.line(x1: x1 + x, y1: y1 + y, x2: x2 + x, y2: y2 + y)
    end
  end
end

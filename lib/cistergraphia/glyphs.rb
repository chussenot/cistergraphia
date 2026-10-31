# frozen_string_literal: true

module Cistergraphia
  # Geometry of a single Cistercian numeral (0-9999), both ways:
  # number => strokes to draw, and drawn strokes => number.
  #
  # Only the units glyphs are defined; tens, hundreds and thousands are mirror
  # images of them, exactly like the medieval numerals. The stem is taller than
  # two digit cells, so the top and bottom halves never share a stroke and every
  # value is unambiguous.
  module Glyphs
    WIDTH = 100
    HEIGHT = 150 # Two 50px digit cells with a 50px gap between them
    STEM = [50, 0, 50, HEIGHT].freeze

    # Strokes (x1, y1, x2, y2 relative to the symbol origin) of the units digits,
    # drawn in the top-right cell. Compound digits are made of several strokes.
    UNITS = {
      1 => [[50, 0, 100, 0]],
      2 => [[50, 50, 100, 50]],
      3 => [[50, 0, 100, 50]],
      4 => [[50, 50, 100, 0]],
      5 => [[50, 0, 100, 0], [50, 50, 100, 0]],
      6 => [[100, 0, 100, 50]],
      7 => [[50, 0, 100, 0], [100, 0, 100, 50]],
      8 => [[50, 50, 100, 50], [100, 0, 100, 50]],
      9 => [[50, 0, 100, 0], [50, 50, 100, 50], [100, 0, 100, 50]]
    }.freeze

    # Tens mirror the units horizontally, hundreds vertically, thousands both ways
    PLACES = {
      1 => ->(x, y) { [x, y] },
      10 => ->(x, y) { [WIDTH - x, y] },
      100 => ->(x, y) { [x, HEIGHT - y] },
      1000 => ->(x, y) { [WIDTH - x, HEIGHT - y] }
    }.freeze

    # Place value (e.g. 300) => list of strokes, built once at load time
    LINES = PLACES.each_with_object({}) do |(place, mirror), lines|
      UNITS.each do |digit, strokes|
        lines[digit * place] = strokes.map do |x1, y1, x2, y2|
          [*mirror.call(x1, y1), *mirror.call(x2, y2)].freeze
        end.freeze
      end
    end.freeze

    # Strokes are compared regardless of the direction they were drawn in
    CANONICAL = ->(stroke) { stroke.each_slice(2).sort.flatten }

    # Place => { sorted canonical strokes => digit }, for reading glyphs back
    DIGITS = PLACES.keys.to_h do |place|
      [place, UNITS.keys.to_h { |digit| [LINES.fetch(digit * place).map(&CANONICAL).sort, digit] }]
    end.freeze

    # Canonical stroke => place it belongs to (the four quadrants never share a stroke)
    STROKE_PLACES = DIGITS.each_with_object({}) do |(place, glyphs), places|
      glyphs.each_key { |strokes| strokes.each { |stroke| places[stroke] = place } }
    end.freeze

    module_function

    # Breaks a number into its individual digits, each multiplied by its place value
    def digits(num)
      num.to_s.chars.reverse.map.with_index { |c, i| c.to_i * (10**i) }.reverse
    end

    # Absolute strokes of one symbol (stem first) whose top-left corner is (x, y)
    def strokes(num, x = 0, y = 0)
      [STEM, *digits(num).flat_map { |value| LINES.fetch(value, []) }].map do |x1, y1, x2, y2|
        [x1 + x, y1 + y, x2 + x, y2 + y]
      end
    end

    # A stroke (relative to the symbol origin) turned half round in its cell, as a
    # rongorongo reader sees the line above once the tablet is turned: units
    # trade places with thousands, tens with hundreds
    def turn((x1, y1, x2, y2))
      [WIDTH - x1, HEIGHT - y1, WIDTH - x2, HEIGHT - y2]
    end

    # The number a sign reads as once turned half round: its units trade
    # places with its thousands, its tens with its hundreds
    def turned(num)
      read(strokes(num).map { |stroke| turn(stroke) })
    end

    # Turns the strokes of one symbol (relative to its origin) back into a number
    def read(strokes)
      strokes = strokes.map(&CANONICAL)
      raise DecodeError, 'A sign without its stem' unless strokes.delete(CANONICAL.call(STEM))

      strokes.group_by { |stroke| STROKE_PLACES.fetch(stroke) { raise DecodeError, "Unknown stroke #{stroke}" } }
             .sum do |place, place_strokes|
               DIGITS.fetch(place).fetch(place_strokes.sort) { raise DecodeError, 'Unknown glyph' } * place
             end
    end
  end
end

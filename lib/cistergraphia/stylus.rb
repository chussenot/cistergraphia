# frozen_string_literal: true

module Cistergraphia
  # The hand that presses a plate. Every stroke becomes a wedge, as a stylus
  # leaves it in clay: a notched triangular head where it bites, then a tail
  # that thins as it lifts. The ductus is a right-handed scribe's (left to
  # right, verticals top-down), so every head sits on the left or on top, as on
  # a cuneiform tablet. A seeded unevenness (angle, length, head) makes it a
  # hand, and the same plate is always pressed the same way.
  #
  # Only the look: plates keep their strokes as lines for the decoder (see SVG).
  #
  # A plate's hand is seeded by each sign's place in it. The page's own signs
  # (the key, the tables, the preview) share another hand, seeded by each
  # stroke (#press): a stroke always looks the same there, so a sign that
  # changes keeps the strokes it shares.
  module Stylus
    HEAD = 12         # width of the head's back face, in glyph units (a sign is 100 x 150)
    HEAD_LENGTH = 14  # from the back of the head to its point
    TAIL = 6          # width of the tail where it leaves the head
    NOTCH = 0.18      # depth of the bite in the head's back, relative to its width
    VARIATION = 6     # the unevenness of the hand: up to ±6 degrees, a few percent

    module_function

    # One stroke pressed by the page's hand, as SVG path data
    def press(stroke)
      seed = Glyphs::CANONICAL.call(stroke).reduce { |acc, value| (acc * 1000) + value }
      wedge(stroke, Random.new(seed)).map { |polygon| outline(polygon) }.join
    end

    # A closed polygon as SVG path data, moved by (x, y), with one decimal
    def outline(points, x = 0, y = 0)
      "M#{points.map { |px, py| "#{(px + x).round(1)} #{(py + y).round(1)}" }.join('L')}Z"
    end

    # The outlines of one stroke (x1, y1, x2, y2), pressed: the head and the
    # tail, each a closed polygon of [x, y] points
    def wedge(stroke, random)
      x1, y1, x2, y2 = ductus(stroke)
      angle, length, width, head_length = hand(x2 - x1, y2 - y1, random)
      start = [x1, y1]
      along = [Math.cos(angle), Math.sin(angle)]
      [head(start, along, width, [head_length, length * 0.6].min), tail(start, along, width, length)]
    end

    # Left to right; verticals top-down
    def ductus((x1, y1, x2, y2))
      x1 > x2 || (x1 == x2 && y1 > y2) ? [x2, y2, x1, y1] : [x1, y1, x2, y2]
    end

    # The stroke as this hand presses it: its angle and length, slightly
    # uneven, and the size of the stylus' head
    def hand(delta_x, delta_y, random)
      [Math.atan2(delta_y, delta_x) + (wobble(random) * VARIATION * Math::PI / 90),
       uneven(Math.hypot(delta_x, delta_y), 0.012, random),
       uneven(HEAD, 0.05, random),
       uneven(HEAD_LENGTH, 0.05, random)]
    end

    # A size, a few percent off (spread per unit of VARIATION)
    def uneven(value, spread, random)
      value * (1 + (wobble(random) * VARIATION * spread))
    end

    def wobble(random)
      random.rand - 0.5
    end

    # The head: its two back corners, its point along the stroke, the notch
    def head(start, along, width, length)
      across = across(along)
      [at(start, across, width / 2.0), at(start, along, length),
       at(start, across, -width / 2.0), at(start, along, width * NOTCH)]
    end

    # The tail: from inside the head to the end of the stroke
    def tail(start, along, width, length)
      root = at(start, along, width * NOTCH)
      [at(root, across(along), TAIL / 2.0), at(start, along, length), at(root, across(along), -TAIL / 2.0)]
    end

    def across((along_x, along_y))
      [-along_y, along_x]
    end

    def at((x, y), (dx, dy), distance)
      [x + (dx * distance), y + (dy * distance)]
    end
  end
end

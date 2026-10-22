# frozen_string_literal: true

module Cistergraphia
  # Where a plate's signs go: the grid, and the order in which it is read.
  #
  # A layout is :phaistos (the snail, clockwise from the top-left corner to the
  # centre), :rongorongo (reverse boustrophedon: rows from the bottom, every
  # other one turned half round), :leap (the Zodiac's step: one row down, two
  # columns across, wrapping), :furrows (boustrophedon by columns), :unwinding
  # (from the centre outward, counter-clockwise) or a Grille (rows read through
  # a turning grille, with its key). Under a grille the cells are square, so that the
  # parchment turned by a quarter lands on the grid again, and each sign is
  # centred in its cell: only a grille's plate is square.
  module Layout
    SPACE = 20
    PADDING = 50 # Padding around the content
    CELL_WIDTH = Glyphs::WIDTH + SPACE
    CELL_HEIGHT = Glyphs::HEIGHT + SPACE
    SQUARE_CELL = CELL_HEIGHT
    SQUARE_INSET = [(SQUARE_CELL - Glyphs::WIDTH) / 2, (SQUARE_CELL - Glyphs::HEIGHT) / 2].freeze
    KEYLESS = %i[phaistos rongorongo leap furrows unwinding].freeze # read without a key: the decoder tries them all

    module_function

    # [width, height, cols, rows] of the plate for a sequence: a square grid,
    # one cell wider and taller with tally signs
    def dimensions(sequence, layout = :phaistos, tally: false)
      cols = Integer.sqrt(sequence.size)
      raise EmptyMessageError, 'Cannot lay out an empty sequence' if cols.zero?

      rows = sequence.size.ceildiv(cols)
      width, height = cell(layout)
      extra = tally ? 1 : 0
      [(width * (cols + extra)) + (PADDING * 2), (height * (rows + extra)) + (PADDING * 2), cols, rows]
    end

    # [width, height] of a grid cell
    def cell(layout)
      layout.is_a?(Grille) ? [SQUARE_CELL, SQUARE_CELL] : [CELL_WIDTH, CELL_HEIGHT]
    end

    # Where the sign sits in its cell
    def inset(layout)
      layout.is_a?(Grille) ? SQUARE_INSET : [0, 0]
    end

    # [row, col, turned] of every sign, in reading order
    def path(size, layout = :phaistos)
      return layout.path(size).map { |row, col| [row, col, false] } if layout.is_a?(Grille)
      unless KEYLESS.include?(layout)
        raise Error, "Unknown layout #{layout.inspect}: use #{KEYLESS.join(', ')} or a grille"
      end

      public_send(layout, size)
    end

    # The keyless layouts that can read a plate of this side as another message:
    # those that form other pairs of signs. Two layouts that pair the same cells
    # in the same order (within a pair, order does not matter: the values add)
    # read any plate alike, so one is not an alternative to the other. At a side
    # of 2 the leap, the furrows and the unwinding are one such walk
    def others(layout, size)
      (KEYLESS - [layout]).reject { |other| pairs(size, other) == pairs(size, layout) }
    end

    # The pairs a layout forms, each as its two [row, col, turned] sorted
    def pairs(size, layout)
      path(size, layout).each_slice(2).map(&:sort)
    end

    # The snail: clockwise from the top-left corner to the centre
    def phaistos(size)
      spiral_coordinates(size).map { |row, col| [row, col, false] }
    end

    # The turning tablet: rows from the bottom, every other one turned half round
    def rongorongo(size)
      boustrophedon_coordinates(size)
    end

    # The leap, the Zodiac's step: one row down and two columns across at every
    # sign, wrapping at the edge; when the orbit closes (after `size` signs) the
    # next starts one column to the right
    def leap(size)
      (0...size).flat_map { |start| (0...size).map { |i| [i, (start + (2 * i)) % size, false] } }
    end

    # The furrows: boustrophedon by columns, as the ox turns at the end of the
    # field. Down the first column, up the second, from the left; no sign turned
    def furrows(size)
      (0...size).flat_map do |col|
        rows = col.even? ? (0...size).to_a : (size - 1).downto(0).to_a
        rows.map { |row| [row, col, false] }
      end
    end

    # The unwinding: from the centre outward, counter-clockwise, to the top-right
    # corner. The snail turned a quarter and read backwards: the snail itself
    # read backwards would pair the same signs, and read the whole message backwards
    def unwinding(size)
      spiral_coordinates(size).map { |row, col| [col, size - 1 - row, false] }.reverse
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

    # Top-left corner of a grid cell
    def cell_origin(row, col, layout)
      width, height = cell(layout)
      [PADDING + (width * col), PADDING + (height * row)]
    end

    # Top-left corner of the sign in a grid cell
    def origin(row, col, layout = :phaistos)
      x, y = cell_origin(row, col, layout)
      dx, dy = inset(layout)
      [x + dx, y + dy]
    end

    # A cell's lines made relative to its sign and turned back upright
    def upright(lines, row, col, turned, layout)
      x, y = origin(row, col, layout)
      local = lines.map { |x1, y1, x2, y2| [x1 - x, y1 - y, x2 - x, y2 - y] }
      turned ? local.map { |stroke| Glyphs.turn(stroke) } : local
    end

    # Grid [row, col] a line belongs to, from its top-left-most point
    def cell_of(line, layout = :phaistos)
      x1, y1, x2, y2 = line
      width, height = cell(layout)
      [([y1, y2].min - PADDING).div(height), ([x1, x2].min - PADDING).div(width)]
    end
  end
end

# frozen_string_literal: true

module Cistergraphia
  # Where a plate's signs go: the grid, and the order in which it is read.
  #
  # A layout is :phaistos (the snail, clockwise from the top-left corner to the
  # centre), :rongorongo (reverse boustrophedon: rows from the bottom, every
  # other one turned half round) or a Grille (rows read through a turning
  # grille, with its key). Under a grille the cells are square, so that the
  # parchment turned by a quarter lands on the grid again, and each sign is
  # centred in its cell: only a grille's plate is square.
  module Layout
    SPACE = 20
    PADDING = 50 # Padding around the content
    CELL_WIDTH = Glyphs::WIDTH + SPACE
    CELL_HEIGHT = Glyphs::HEIGHT + SPACE
    SQUARE_CELL = CELL_HEIGHT
    SQUARE_INSET = [(SQUARE_CELL - Glyphs::WIDTH) / 2, (SQUARE_CELL - Glyphs::HEIGHT) / 2].freeze
    KEYLESS = %i[phaistos rongorongo].freeze # read without a key, so the decoder can try them

    module_function

    # [width, height, cols, rows] of the plate for a sequence: a square grid
    def dimensions(sequence, layout = :phaistos)
      cols = Integer.sqrt(sequence.size)
      raise EmptyMessageError, 'Cannot lay out an empty sequence' if cols.zero?

      rows = sequence.size.ceildiv(cols)
      width, height = cell(layout)
      [(width * cols) + (PADDING * 2), (height * rows) + (PADDING * 2), cols, rows]
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
      case layout
      when :phaistos then Cistergraphia.spiral_coordinates(size).map { |row, col| [row, col, false] }
      when :rongorongo then Cistergraphia.boustrophedon_coordinates(size)
      when Grille then layout.path(size).map { |row, col| [row, col, false] }
      else raise Error, "Unknown layout #{layout.inspect}: use #{KEYLESS.join(', ')} or a grille"
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

    # Grid [row, col] a line belongs to, from its top-left-most point
    def cell_of(line, layout = :phaistos)
      x1, y1, x2, y2 = line
      width, height = cell(layout)
      [([y1, y2].min - PADDING).div(height), ([x1, x2].min - PADDING).div(width)]
    end
  end
end

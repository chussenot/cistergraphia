# frozen_string_literal: true

module Cistergraphia
  # A pathless plate says nothing of where it begins: the reader finds the
  # way. Its file carries one class on the root, and its signs lie in grid
  # order, each wedge seeded by its cell, so that neither the order of the
  # elements nor the hand's tremor tells which of the five ways it runs. The
  # decoder reads it as any other plate: it tries every way.
  module Pathless
    CLASS = 'pathless'
    NOT_SEALED = 'A sealed plate cannot be pathless: it reads as no letters along any way'
    NOT_UNDER_A_GRILLE = 'A grille plate hides its way by its key already'
    NOT_DAMAGED = 'A pathless plate cannot be worn or broken yet'

    module_function

    # Whether a plate was written pathless (a string test: the class on the root)
    def pathless?(svg)
      svg.to_s.include?(%(class="#{CLASS}"))
    end

    # The signs (Layout.placed) in grid order, row by row, each seeded by its
    # cell: the file's order and the hand's tremor tell nothing of the way
    def by_cell(signs, cols)
      signs.sort_by { |(row, col, _), *| [row, col] }
           .map { |(row, col, turned), num, index, _| [[row, col, turned], num, index, (row * cols) + col] }
    end

    # What each cell of a plate reads, upright and turned half round, as
    # [row, col, upright, turned] in grid order (nil where the strokes read as
    # no sign that way): what a desk needs to lay any of the five ways over it
    def grid(svg)
      cells = SVG.lines(svg).group_by { |line| Layout.cell_of(line) }
      cells.sort.map do |(row, col), strokes|
        [row, col, *[false, true].map { |turned| reading(strokes, row, col, turned) }]
      end
    end

    def reading(strokes, row, col, turned)
      Glyphs.read(Layout.upright(strokes, row, col, turned, :phaistos))
    rescue DecodeError
      nil
    end

    # The plates that cannot be pathless, in the library's words
    def check(passphrase, layout)
      raise Error, NOT_SEALED if passphrase
      raise Error, NOT_UNDER_A_GRILLE if layout.is_a?(Grille)
    end
  end
end

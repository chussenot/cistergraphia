# frozen_string_literal: true

module Cistergraphia
  # Tally signs: sums on a higher cord, as on an Inka khipu. One sign at the
  # end of every row, one under every column, and one in the corner.
  #
  # Purpose:
  # - Give a weathered plate enough redundancy to lose whole signs: a row with
  #   one sign left open gets it back from its tally
  # - Restore by propagation: tallies fix a lone open digit in a row or a
  #   column; the pair balance keeps only the values that can balance; repeat
  #   until nothing changes
  #
  # Design Decisions:
  # - Each place is summed on its own, mod 10, without carries: the units of a
  #   row check each other, as do the tens, hundreds and thousands. Two
  #   quadrants lost in one row in different places are then two problems
  #   with one unknown each, where a sum of whole values would leave one
  #   equation with two. It is also a sum a monk could check by eye, column by
  #   column. Khipu sums are true sums: this is a deliberate departure
  # - Rows and columns are the grid's, whatever the reading path; the tally
  #   signs themselves are never weathered (the higher cord survives)
  # - The corner sums the row tallies (and so the column tallies too)
  #
  # Constraints:
  # - Game plates only, like weathering
  module Tally
    PLACES = Glyphs::PLACES.keys.freeze
    CLASS = 'tally-lines'
    RUBRIC = '#a3301c' # the tally signs and their cords, as a scribe's rubric
    NOT_UNDER_A_GRILLE = 'Tally signs are not drawn under a grille yet'
    NOT_SEALED = 'Tally signs are for game plates: a sealed plate never loses a stroke'

    module_function

    # A carry-free sum: each place's digits added mod 10
    def add(values)
      PLACES.sum { |place| (values.sum { |value| (value / place) % 10 } % 10) * place }
    end

    # { rows: [...], cols: [...], corner: n } for a sequence laid along a layout
    def signs(sequence, layout)
      grid = grid(sequence, layout)
      rows = grid.map { |row| add(row) }
      { rows: rows, cols: grid.transpose.map { |col| add(col) }, corner: add(rows) }
    end

    # The sequence's values on the grid, by [row][col]
    def grid(sequence, layout)
      size = Integer.sqrt(sequence.size)
      grid = Array.new(size) { Array.new(size) }
      Layout.path(size, layout).zip(sequence) { |(row, col), value| grid[row][col] = value }
      grid
    end

    # The lines a reading-order index belongs to: [[:row, r], [:col, c]]
    def lines(size, layout)
      Layout.path(size, layout).map { |row, col| [[:row, row], [:col, col]] }
    end

    # Candidate values of every sign, narrowed by the tallies and the pair
    # balance until nothing changes. candidates: one array per sign, in reading order
    def restore(candidates, tally, layout)
      candidates = candidates.map(&:dup)
      members = members(Integer.sqrt(candidates.size), layout)
      loop do # the balance first: a sign wholly lost keeps at most 28 values if its partner is known
        changed = balance_pairs(candidates)
        changed += members.sum { |line, indices| fix_lone_digits(candidates, indices, tally_of(tally, line)) }
        return candidates if changed.zero?
      end
    end

    # Line => the reading-order indices on it
    def members(size, layout)
      lines(size, layout).each_with_index.with_object(Hash.new { |h, k| h[k] = [] }) do |(on, index), lines|
        on.each { |line| lines[line] << index }
      end
    end

    def tally_of(tally, (kind, number))
      tally.fetch(kind == :row ? :rows : :cols).fetch(number)
    end

    # In each place, a line with one sign whose digit is still open gets it from
    # its tally; a line with none must add up. Returns how many signs were narrowed
    def fix_lone_digits(candidates, indices, sum)
      PLACES.sum do |place|
        open = indices.reject { |index| digits_at(candidates[index], place).one? }
        next check_line(candidates, indices, place, sum) if open.empty?
        next 0 unless open.one?

        digit = missing_digit(candidates, indices - open, place, sum)
        narrow(candidates, open.first) { |value| (value / place) % 10 == digit }
      end
    end

    def check_line(candidates, indices, place, sum)
      raise DecodeError, 'The tallies do not add up' unless missing_digit(candidates, indices, place, sum).zero?

      0
    end

    # The digit a line's tally leaves for its one open sign, in a place
    def missing_digit(candidates, settled, place, sum)
      ((sum / place % 10) - settled.sum { |index| digits_at(candidates[index], place).first }) % 10
    end

    # Only the values that can balance with some value of their partner. Returns how many signs were narrowed
    def balance_pairs(candidates)
      (0...candidates.size).step(2).sum do |first|
        next 0 if candidates[first].one? && candidates[first + 1].one?

        balance_against(candidates, first, first + 1, first: true) +
          balance_against(candidates, first + 1, first, first: false)
      end
    end

    # Narrow one sign of a pair to the values that balance with some value of the other
    def balance_against(candidates, index, partner, first:)
      partners = candidates[partner]
      return 0 if first && partners.include?(EVIL_MARKER) # a null pair: any first sign will do

      allowed = balancing(partners, first: first)
      narrow(candidates, index) { |value| allowed.include?(value) }
    end

    # Every value that balances with one of these partners: a few dozen when the
    # partner is known, so a sign wholly lost (10,000 values) is narrowed by lookup
    def balancing(partners, first:)
      values = partners.flat_map { |partner| CHARACTERS.keys.map { |sum| sum - partner } }
      values << EVIL_MARKER unless first # the second sign of a null pair
      values.grep(0..EVIL_MARKER).to_set
    end

    def digits_at(values, place)
      values.map { |value| (value / place) % 10 }.uniq
    end

    # Keep a sign's candidates that pass the block: 1 if that narrowed it, else 0
    def narrow(candidates, index, &)
      kept = candidates[index].select(&)
      raise DecodeError, 'The tallies do not add up' if kept.empty?
      return 0 if kept.size == candidates[index].size

      candidates[index] = kept
      1
    end

    # The tally signs in a plate's SVG: drawn, hidden, read back
    module Plate
      module_function

      # The tally signs of a plate in its SVG, one row and one column past the
      # grid, with the cords that set them apart in the gutters: pressed, and as
      # hidden lines in their own layer (what the decoder reads; never strokes)
      def layer(sequence, cols, layout)
        raise Error, NOT_UNDER_A_GRILLE if layout.is_a?(Grille)

        placed = placed(sequence, cols, layout)
        pressed = placed.each_with_index.flat_map { |((row, col), num), i| press(num, row, col, layout, i) }
        hidden = placed.flat_map { |(row, col), num| hidden(num, row, col, layout) }
        %(<g class="tally" fill="#{RUBRIC}">\n#{cords(cols, layout)}\n#{pressed.join("\n")}\n</g>\n) +
          %(<g class="#{CLASS}" stroke="black" stroke-width="2" display="none">\n#{hidden.join("\n")}\n</g>)
      end

      # [[row, col], value] of every tally sign
      def placed(sequence, cols, layout)
        tally = Tally.signs(sequence, layout)
        cells(cols).zip(tally[:rows] + tally[:cols] + [tally[:corner]])
      end

      # Where the tally signs go: the end of each row, under each column, the corner
      def cells(cols)
        (0...cols).map { |row| [row, cols] } + (0...cols).map { |col| [cols, col] } + [[cols, cols]]
      end

      def press(num, row, col, layout, seed)
        SVG.press(Glyphs.strokes(num), false, Layout.origin(row, col, layout), Random.new(-1 - seed))
           .map { |outline| %(  <path d="#{outline}"/>) }
      end

      def hidden(num, row, col, layout)
        x, y = Layout.origin(row, col, layout)
        Glyphs.strokes(num).map { |stroke| SVG.line_tag(Layout.relative(stroke, -x, -y)) }
      end

      # Two thin rules in the gutters, between the grid and its tallies
      def cords(cols, layout)
        width, height = Layout.cell(layout)
        x, y = Layout.cell_origin(cols, cols, layout)
        from = Layout::PADDING - 10
        %(  <rect class="cord" x="#{x - 12}" y="#{from}" width="3" height="#{y + height - from}"/>\n) +
          %(  <rect class="cord" x="#{from}" y="#{y - 12}" width="#{x + width - from}" height="3"/>)
      end

      # The tally signs a plate carries ({ rows:, cols:, corner: }), or nil without
      def read(svg, layout)
        lines = SVG.lines(svg, layer: :tally)
        return if lines.empty?

        by_cell = lines.group_by { |line| Layout.cell_of(line, layout) }
        cols = by_cell.keys.map(&:first).max
        values = cells(cols).map { |cell| read_sign(by_cell, cell, layout) }
        { rows: values.first(cols), cols: values[cols, cols], corner: values.last }
      end

      def read_sign(by_cell, (row, col), layout)
        strokes = by_cell.fetch([row, col]) { raise DecodeError, 'A tally sign is missing' }
        Glyphs.read(Layout.upright(strokes, row, col, false, layout))
      end
    end
  end
end

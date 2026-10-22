# frozen_string_literal: true

module Cistergraphia
  # Broken plates: a game plate in two to four fragments, shuffled into a tray
  # below an empty board the size of the plate, and the rejoining of them by
  # the pair checksum.
  #
  # Purpose:
  # - Break a plate along its grid, turn some fragments half round, and lay
  #   them in a tray: the reader rejoins them on the board
  # - Rejoin a broken plate: of every way the fragments tile the board, turned
  #   or not, read along either keyless layout, the one whose pairs all balance
  # - A broken plate may be weathered too: it is weathered first, as an intact
  #   plate is (Weathering), then broken. Rejoined, it reads as an edition
  #
  # Design Decisions:
  # - Breaks follow the grid, straight across a fragment (each break splits one
  #   fragment in two), and every fragment is at least MIN_SIDE signs each way.
  #   Straight breaks let several fragments fit the same hole, so the shapes
  #   alone do not rejoin a plate: the sums do, as the sums of a khipu rejoined
  #   two of its fragments
  # - Every edge is worn, each fragment on its own: they never fit like a jigsaw
  # - A fragment's signs are written in its own frame, already turned if it lies
  #   turned in the tray; its place in the tray (a translation and a slight
  #   tilt) is its only transform. The file holds neither where a fragment
  #   belongs nor whether it is turned
  # - A fragment turns half round only: a quarter turn lays the stems flat,
  #   which no reader would take for upright
  # - A plate is broken only if exactly one arrangement rejoins it: the
  #   decoder's own search is run on every new plate
  # - A weathered fragment's signs are read as their candidate values (what its
  #   strokes allow, the lost positions anything), upright and turned; an
  #   arrangement holds when every pair can balance. A lacuna widens what a
  #   pair allows a little, the arrangement a great deal: wrong ones still fail
  #   (the generator checks it), and only the true one is printed as an edition
  # - A fragment's own frame is the plate's, as if it lay at the top-left
  #   corner: its signs sit where a plate's would, centred in cell boxes that
  #   start at BOARD. Turned half round, it lands on the same boxes; moved by
  #   whole cells onto the board, it shows the plate exactly as it was drawn
  #
  # Constraints:
  # - Game plates only, and along the snail only. The snail crosses every
  #   break, so pairs straddle every join. Rongorongo pairs never straddle a
  #   line, and a Rongorongo plate turned half round balances just as well
  #   (its lines read in reverse order): the sums could not tell which is up
  # - No tally signs (yet)
  # - At most MAX_PIECES fragments: the search is n! x 2^n arrangements, each
  #   read along both layouts (768 for four), and most fail on their first pairs
  # - The search is bounded for crafted files too: a sign worn past one corner
  #   is refused (MAX_CANDIDATES), and so are fragments that would have the
  #   decoder weigh more than MAX_WEIGHINGS pairs. Every fragment touches the
  #   plate's edge, so a wrong arrangement fails within the snail's first ring
  module Fragments
    CLASS = 'fragment'
    EDGE = Layout::SPACE / 2 # a fragment's margin around its signs: half the gap between two
    BOARD = Layout::PADDING - EDGE # where the board starts, and a fragment's box in its own frame
    MIN_SIDE = 2
    MAX_PIECES = 4
    MAX_CANDIDATES = 10 # a lacuna takes at most one corner of a sign: ten digits it may have held
    MAX_WEIGHINGS = 20_000 # pairs weighed in all; honest plates need under 3,000 (experiments/weathering)
    SEALED = 'A broken plate is a game plate: read it without a passphrase'
    NOT_SEALED = 'A sealed plate cannot be broken: its signs carry no sums to rejoin it by'
    NOT_UNDER_A_GRILLE = 'A plate under a grille cannot be broken yet'
    NOT_ALONG_THE_ROWS = 'Only a Phaistos plate can be broken: a Rongorongo plate turned half round ' \
                         'balances just as well, its lines in reverse order'
    NOT_TALLIED = 'A broken plate cannot carry tally signs yet'
    TOO_SMALL = 'Too short a message to break: a broken plate needs at least 4 × 4 signs'

    # What a fragment's cells are, in its own frame
    module Cells
      # [row, col] of every cell, row by row
      def cells
        (0...rows).to_a.product((0...cols).to_a)
      end

      # Where a cell lands once the fragment is turned half round
      def opposite(row, col)
        [rows - 1 - row, cols - 1 - col]
      end
    end

    # A fragment where it belongs on the plate's grid, and whether it lies turned in the tray
    Piece = Struct.new(:row, :col, :rows, :cols, :turned) do
      include Cells

      # The two pieces it breaks into, across its rows or its columns (first: the first piece's side)
      def split(axis, first)
        return [with(rows: first), with(row: row + first, rows: rows - first)] if axis == :rows

        [with(cols: first), with(col: col + first, cols: cols - first)]
      end

      def with(**changes)
        self.class.new(**to_h, **changes)
      end
    end

    # A sign as a fragment shows it, in its own frame: where, its value, whether
    # it is turned, its place in the reading order, and the strokes a lacuna took
    Sign = Struct.new(:row, :col, :num, :turned, :index, :lost) do
      def origin
        Layout.origin(row, col)
      end

      # The strokes that survive, turned as the sign lies
      def strokes
        Lacunae.strokes(num, lost).map { |stroke| turned ? Glyphs.turn(stroke) : stroke }
      end
    end

    # A fragment as the file shows it: its size, each cell's sign read upright
    # and turned half round, as candidate values (one for an intact sign; nil
    # where it does not read), and whether a lacuna took part of it
    # ({ [row, col] => [upright, turned, worn] }), and the stroke positions the
    # lacunae took ({ [row, col] => canonical upright strokes }, for the bench)
    Fragment = Struct.new(:rows, :cols, :readings, :lost) do
      include Cells

      # Its size from the cells it has, its last row and column
      def self.of(readings, lost = {})
        new(*readings.keys.transpose.map { |side| side.max + 1 }, readings, lost)
      end
    end

    # A way the fragments rejoin: the layout it reads along, the message (an
    # edition, if weathered), and where each fragment goes ([fragment index,
    # row, col, turned], in file order)
    Rejoining = Struct.new(:layout, :message, :places)

    # A broken plate rejoined, for the bench: the layout it reads along, every
    # sign's value in reading order (nil where a lacuna leaves it open), the
    # lacunae ({ index => lost strokes, canonical and upright }), what each
    # worn sign may hold, and the plate drawn whole from the file's own
    # fragments, each moved to its place
    Whole = Struct.new(:layout, :signs, :damage, :candidates, :svg)

    module_function

    # [sequence, svg, pieces, damage] for a broken game plate, along the snail;
    # weathered first if asked (damage is then Weathering's, else empty)
    def inscribe(message, layout: :phaistos, weathered: false, random: Random.new)
      refuse(layout)

      100.times do
        sequence = Cistergraphia.encode(message)
        raise Error, TOO_SMALL if Integer.sqrt(sequence.size) < 2 * MIN_SIDE

        damage = weathered ? Weathering.weather(sequence, random: random) : {}
        pieces = Breaking.cut(Integer.sqrt(sequence.size), random)
        svg = Tray.render(sequence, layout, pieces, random, damage)
        return [sequence, svg, pieces, damage] if Join.all(read(svg), Layout::KEYLESS).one?
      end
      raise Error, 'Could not break this plate so that it rejoins one way only'
    end

    def refuse(layout)
      raise Error, NOT_UNDER_A_GRILLE if layout.is_a?(Grille)
      raise Error, NOT_ALONG_THE_ROWS unless layout == :phaistos
    end

    # Whether a plate is broken (a string test: intact plates are not parsed twice)
    def broken?(svg)
      svg.to_s.include?(%(class="#{CLASS}"))
    end

    # The message of a broken plate, rejoined
    def decode(svg, passphrase: nil, layout: nil)
      raise Error, SEALED if passphrase

      rejoin(svg, layout).message
    end

    # The one way a broken plate's fragments rejoin (along a layout, if given)
    def rejoin(svg, layout = nil)
      found = Join.all(read(svg), layout ? [layout] : Layout::KEYLESS)
      raise DecodeError, 'The fragments do not rejoin: no arrangement balances every pair' if found.empty?
      raise DecodeError, 'The fragments rejoin into more than one message' if found.map(&:message).uniq.size > 1

      found.first
    end

    # A weathered broken plate rejoined (one way, or DecodeError), for the bench
    def rejoined(svg)
      fragments = read(svg)
      Rejoined.of(svg, fragments, rejoin(svg))
    end

    # The fragments of a broken plate, in the order the file lists them
    def read(svg)
      root = SVG.parse(svg).root
      raise DecodeError, 'Not an SVG document' unless root&.name == 'svg'

      groups = []
      root.each_recursive { |node| groups << node if node.name == 'g' && node.attributes['class'] == CLASS }
      raise DecodeError, "A broken plate has at most #{MAX_PIECES} fragments" if groups.size > MAX_PIECES

      groups.map { |group| Reading.fragment(group) }
    end

    # A fragment read from its hidden lines, in its own frame: the strokes, and
    # the stroke positions lacunae took (weathered plates)
    module Reading
      module_function

      def fragment(group)
        cells = by_cell(group, :strokes)
        raise DecodeError, 'A fragment has no signs' if cells.empty?

        lost = by_cell(group, :lacunae)
        fragment = Fragment.of(cells.to_h { |cell, strokes| [cell, readings(strokes, lost.fetch(cell, []), *cell)] },
                               cells.to_h { |cell, _| [cell, gone(lost, cell)] })
        raise DecodeError, 'A fragment has lost a sign' unless fragment.cells.size == fragment.readings.size

        fragment
      end

      # A cell's lost stroke positions, canonical and upright in the fragment's frame
      def gone(lost, (row, col))
        Layout.upright(lost.fetch([row, col], []), row, col, false, :phaistos).map(&Glyphs::CANONICAL)
      end

      # A fragment's lines in one layer (:strokes, or :lacunae), as SVG.lines reads a plate's, by cell
      def by_cell(group, layer)
        lines = []
        group.each_recursive do |node|
          lines << %w[x1 y1 x2 y2].map { |attr| SVG.coordinate(node.attributes[attr]) } if SVG.in_layer?(node, layer)
        end
        lines.group_by { |line| Layout.cell_of(line) }
      end

      # A sign's candidate values read upright and turned half round (nil where
      # it does not read), and whether a lacuna took part of it
      def readings(strokes, lost, row, col)
        raise DecodeError, 'A fragment sign lies outside its fragment' if row.negative? || col.negative?

        seen, gone = [strokes, lost].map { |lines| Layout.upright(lines, row, col, false, :phaistos) }
        [candidates(seen, gone), candidates(turned(seen), turned(gone)), gone.any?]
      end

      def candidates(seen, gone)
        values = legible(seen, gone)
        raise DecodeError, 'A sign of a broken plate is worn past one corner' if values && values.size > MAX_CANDIDATES

        values
      end

      # What the strokes allow, or nil where they are no sign (read the other way up, say)
      def legible(seen, gone)
        Weathering.candidates(seen, gone)
      rescue DecodeError
        nil
      end

      def turned(lines)
        lines.map { |stroke| Glyphs.turn(stroke) }
      end
    end

    # Where a plate breaks: straight across, one fragment in two at a time
    module Breaking
      module_function

      # Two to MAX_PIECES fragments tiling the grid, one in two turned half round
      def cut(size, random)
        breaks = 1 + random.rand(MAX_PIECES - 1)
        pieces = breaks.times.reduce([Piece.new(0, 0, size, size)]) { |found, _| break_one(found, random) }
        pieces.each { |piece| piece.turned = random.rand(2).zero? }
      end

      # The pieces with one of them broken in two (as they were when none can break)
      def break_one(pieces, random)
        splittable = pieces.select { |piece| [piece.rows, piece.cols].max >= 2 * MIN_SIDE }
        return pieces if splittable.empty?

        piece = splittable.sample(random: random)
        pieces.flat_map { |other| other.equal?(piece) ? split(piece, random) : [other] }
      end

      # One piece broken in two, straight across its rows or its columns
      def split(piece, random)
        sides = { rows: piece.rows, cols: piece.cols }.select { |_, side| side >= 2 * MIN_SIDE }
        axis = sides.keys.sample(random: random)
        piece.split(axis, MIN_SIDE + random.rand(sides[axis] - (2 * MIN_SIDE) + 1))
      end
    end

    # Every way the fragments tile the board, turned or not, read along the layouts
    module Join
      module_function

      # Fragments laid on the board along a tiling ([[index, row, col], ...]),
      # some turned half round (turns, by fragment index): what each cell shows
      Laid = Struct.new(:fragments, :tiling, :owner, :turns) do
        # The sign in a cell, read upright or turned as the path says: [candidate
        # values (nil if it does not read), worn?]
        def sign(row, col, turned)
          index, top, left = owner[row][col]
          upright, half, worn = readings(index, row - top, col - left)
          [turns[index] == turned ? upright : half, worn]
        end

        # What the fragment shows at a cell of its own, wherever it lies turned
        def readings(index, row, col)
          fragment = fragments[index]
          fragment.readings.fetch(turns[index] ? fragment.opposite(row, col) : [row, col])
        end

        # [index, row, col, turned] of every fragment, in file order
        def places
          tiling.map { |index, row, col| [index, row, col, turns[index]] }.sort
        end
      end

      # Pairs left to weigh, in all the arrangements a search tries
      class Budget
        def initialize(pairs)
          @left = pairs
        end

        def spend
          @left -= 1
          raise DecodeError, 'These fragments allow too many ways to rejoin them' if @left.negative?
        end
      end

      # The arrangements whose pairs all balance, as Rejoinings
      def all(fragments, layouts)
        size = side(fragments)
        paths = layouts.to_h { |layout| [layout, Layout.path(size, layout)] }
        budget = Budget.new(MAX_WEIGHINGS)
        tilings(fragments, size).flat_map do |tiling|
          owner = owners(fragments, tiling, size)
          [false, true].repeated_permutation(fragments.size).flat_map do |turns|
            laid = Laid.new(fragments, tiling, owner, turns)
            paths.filter_map { |layout, path| rejoining(laid, [layout, path], budget) }
          end
        end
      end

      # The side of the board the fragments cover
      def side(fragments)
        cells = fragments.sum { |fragment| fragment.rows * fragment.cols }
        size = Integer.sqrt(cells)
        raise DecodeError, 'The fragments do not make a square plate' unless size.positive? && size**2 == cells

        size
      end

      # Each cell's fragment, as [index, its top row, its left column]
      def owners(fragments, tiling, size)
        owner = Array.new(size) { Array.new(size) }
        tiling.each do |index, row, col|
          mark(owner, fragments[index], row, col, [index, row, col])
        end
        owner
      end

      # The board read along a path: a Rejoining if every pair can balance, else
      # nil (on the first pair that cannot, which is where most arrangements stop)
      def rejoining(laid, (layout, path), budget)
        cells = []
        path.each_slice(2) do |pair|
          budget.spend
          signs = pair.map { |row, col, turned| laid.sign(row, col, turned) }
          return nil unless balances?(*signs.map(&:first))

          cells.concat(signs)
        end
        text = edition(cells)
        Rejoining.new(layout, text, laid.places) if text
      end

      # The edition of a board whose pairs all balance; nil if they are all null pairs (no letters)
      def edition(cells)
        Weathering::Edition.text(cells)
      rescue DecodeError
        nil
      end

      # Whether a pair can balance: at once for two intact signs, else by what their candidates allow
      def balances?(firsts, seconds)
        return false if firsts.nil? || seconds.nil?
        return !Weathering.balance(firsts.first, seconds.first).nil? if firsts.one? && seconds.one?

        Weathering.readings(firsts, seconds).any?
      end

      # Every way to tile the board with all the fragments: [[index, row, col], ...]
      def tilings(fragments, size)
        found = []
        lay(fragments, Array.new(size) { Array.new(size) }, [], found)
        found
      end

      # The first empty cell, row by row, is the top-left corner of some fragment
      def lay(fragments, board, placed, found)
        row, col = first_empty(board)
        return found << placed.dup unless row

        fragments.each_with_index do |fragment, index|
          next if placed.any? { |done, _, _| done == index } || !fits?(board, fragment, row, col)

          mark(board, fragment, row, col, index)
          lay(fragments, board, placed << [index, row, col], found)
          placed.pop
          mark(board, fragment, row, col, nil)
        end
      end

      def first_empty(board)
        board.each_with_index do |cells, row|
          col = cells.index(nil)
          return [row, col] if col
        end
        nil
      end

      def fits?(board, fragment, row, col)
        row + fragment.rows <= board.size && col + fragment.cols <= board.size &&
          board[row, fragment.rows].all? { |cells| cells[col, fragment.cols].none? }
      end

      def mark(board, fragment, row, col, value)
        board[row, fragment.rows].each { |cells| cells.fill(value, col, fragment.cols) }
      end
    end

    # The plate whole again: what the bench needs, from the fragments laid where
    # the one rejoining puts them (each sign's value or candidates, its lost
    # strokes turned as the fragment lies), and the drawing
    module Rejoined
      module_function

      def of(svg, fragments, rejoining)
        signs = signs(laid(fragments, rejoining), Join.side(fragments), rejoining.layout)
        damage, candidates = lacunae(signs)
        Whole.new(rejoining.layout, signs.map { |candidates, worn| worn ? nil : candidates.first }, damage, candidates,
                  drawing(svg, fragments, rejoining.places))
      end

      # [{ index => lost strokes }, { index => candidates }] of the worn signs
      def lacunae(signs)
        worn = signs.each_with_index.select { |(_, worn), _| worn }
        [worn.to_h { |(_, _, lost), index| [index, lost] },
         worn.to_h { |(candidates, _, _), index| [index, candidates] }]
      end

      # Every sign along the path, as #sign reads it
      def signs(laid, side, layout)
        Layout.path(side, layout).map { |row, col, turned| sign(laid, row, col, turned) }
      end

      # The fragments where the rejoining puts them
      def laid(fragments, rejoining)
        tiling = rejoining.places.map { |index, row, col, _| [index, row, col] }
        owner = Join.owners(fragments, tiling, Join.side(fragments))
        Join::Laid.new(fragments, tiling, owner, rejoining.places.map(&:last))
      end

      # [candidates, worn?, lost strokes upright on the plate] of the sign in a cell
      def sign(laid, row, col, turned)
        index, top, left = laid.owner[row][col]
        [*laid.sign(row, col, turned), lost(laid.fragments[index], [row - top, col - left], laid.turns[index])]
      end

      # A fragment cell's lost strokes as they lie on the plate: turned with the fragment
      def lost(fragment, cell, turned)
        lost = fragment.lost.fetch(turned ? fragment.opposite(*cell) : cell, [])
        turned ? lost.map { |stroke| Glyphs::CANONICAL.call(Glyphs.turn(stroke)) } : lost
      end

      # The file's fragment groups moved onto the plate's grid: translated to
      # their cells, turned half round about their own middle where they lie turned
      def drawing(svg, fragments, places)
        groups = groups(svg)
        moved = places.map do |index, row, col, turned|
          groups[index].add_attribute('transform', transform(fragments[index], [row, col], turned))
          groups[index].to_s
        end
        Tray.document(*canvas(Join.side(fragments)), "  #{Lacunae::PATTERN}", moved)
      end

      # [width, height] of a whole plate of this side
      def canvas(side)
        Layout.cell(:phaistos).map { |length| (length * side) + (2 * Layout::PADDING) }
      end

      def groups(svg)
        groups = []
        SVG.parse(svg, quoted: true).root.each_recursive do |node|
          groups << node if node.name == 'g' && node.attributes['class'] == CLASS
        end
        groups
      end

      def transform(fragment, (row, col), turned)
        width, height = Layout.cell(:phaistos)
        middle = "#{BOARD + (fragment.cols * width / 2.0)} #{BOARD + (fragment.rows * height / 2.0)}"
        turn = turned ? " rotate(180 #{middle})" : ''
        "translate(#{col * width} #{row * height})#{turn}"
      end
    end

    # The broken plate as drawn: the empty board, and the fragments in the tray below it
    module Tray
      GAP = 40    # between the board and the tray, and between fragments
      TILT = 4    # degrees a fragment lies askew in the tray, at most
      JITTER = 3  # how worn a fragment's edge is
      STEP = 30   # how often along an edge it is worn
      CLAY = '#ece6da'
      RIM = '#b3a993'

      # Where the fragments go in the tray: each where it lies highest, along a
      # skyline of what is already laid ([[from x, to x, first free y], ...])
      class Skyline
        attr_reader :room, :bottom

        def initialize(top, room)
          @spans = [[0, room, top]]
          @room = room
          @bottom = top
        end

        # Where a fragment's box goes: its top-left corner
        def place(width, height)
          x, y = @spans.filter_map { |from, _, _| [from, top_over(from, width)] if from + width <= @room }
                       .min_by { |from, top| [top, from] }
          raise_to(x, x + width + GAP, y + height + GAP)
          @bottom = [@bottom, y + height].max
          [BOARD + x, y]
        end

        private

        def top_over(from, width)
          @spans.select { |left, right, _| left < from + width && right > from }.map(&:last).max
        end

        # The skyline from one x to another raised to a new top: what lay there before is cut away
        def raise_to(from, upto, top)
          kept = @spans.flat_map do |left, right, free|
            [[left, [right, from].min, free], [[left, upto].max, right, free]]
          end
          @spans = (kept.select { |left, right, _| left < right } + [[from, upto, top]]).sort
        end
      end

      module_function

      # The board, and below it a tray a little wider: fragments as wide as the
      # board fit side by side. Damage is Weathering's, by reading index
      def render(sequence, layout, pieces, random, damage = {})
        size = Integer.sqrt(sequence.size)
        tray = tray_below(size, layout)
        fragments = lay(pieces, [sequence, damage], layout, tray, random)
        defs = damage.empty? ? board(size, layout) : "  #{Lacunae::PATTERN}\n#{board(size, layout)}"
        document(tray.room + (2 * BOARD), tray.bottom + BOARD, defs, fragments)
      end

      def tray_below(size, layout)
        width, height = Layout.cell(layout).map { |side| side * size }
        Skyline.new(BOARD + height + GAP, width + ((MAX_PIECES - 1) * GAP))
      end

      # The fragments drawn in the tray, the tallest first (in shuffled order among equals)
      def lay(pieces, (sequence, damage), layout, tray, random)
        where = reading_order(Integer.sqrt(sequence.size), layout)
        tallest = pieces.shuffle(random: random).each_with_index.sort_by { |piece, i| [-piece.rows, i] }.map(&:first)
        tallest.map do |piece|
          fragment(box(piece, layout), signs(piece, [sequence, damage], where), tray, random)
        end
      end

      # [row, col] => [reading index, turned]
      def reading_order(size, layout)
        Layout.path(size, layout).each_with_index.to_h { |(row, col, turned), index| [[row, col], [index, turned]] }
      end

      # [width, height] of a piece's box
      def box(piece, layout)
        width, height = Layout.cell(layout)
        [width * piece.cols, height * piece.rows]
      end

      def document(width, height, board, fragments)
        <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
            <rect width="100%" height="100%" fill="white"/>
          #{board}
          #{fragments.join("\n")}
          </svg>
        SVG
      end

      # The empty board, ruled in cells, where the plate was
      def board(size, layout)
        width, height = Layout.cell(layout)
        cell = %(<rect width="#{width}" height="#{height}" fill="#faf7f1" stroke="#e4dccb" stroke-width="2"/>)
        <<~SVG.chomp
          <defs><pattern id="board" x="#{BOARD}" y="#{BOARD}" width="#{width}" height="#{height}" patternUnits="userSpaceOnUse">#{cell}</pattern></defs>
          <rect class="board" x="#{BOARD}" y="#{BOARD}" width="#{width * size}" height="#{height * size}" fill="url(#board)" stroke="#{RIM}" stroke-width="2" stroke-dasharray="10 8"/>
        SVG
      end

      # A fragment's signs, in its own frame
      def signs(piece, (sequence, damage), where)
        piece.cells.map do |row, col|
          index, turned = where.fetch([piece.row + row, piece.col + col])
          cell = piece.turned ? piece.opposite(row, col) : [row, col]
          Sign.new(*cell, sequence[index], turned ^ piece.turned, index, damage.fetch(index, []))
        end
      end

      # One fragment in the tray: its clay, its signs pressed, and its strokes as
      # hidden lines. In its own frame its box starts at BOARD, as the board does
      def fragment((width, height), signs, tray, random)
        x, y = tray.place(width, height)
        tilt = "rotate(#{tilt(width, height, random)} #{BOARD + (width / 2)} #{BOARD + (height / 2)})"
        %(  <g class="#{CLASS}" transform="translate(#{x - BOARD} #{y - BOARD}) #{tilt}">\n) \
          "#{sherd(width, height, random)}#{lacunae(signs, :worn)}#{wedges(signs)}#{hidden(signs)}" \
          "#{lacunae(signs, :lost_lines)}  </g>"
      end

      # A slight tilt, never so much that a corner reaches the next fragment
      def tilt(width, height, random)
        limit = Math.atan2(GAP / 3.0, [width, height].max) * 180 / Math::PI
        (random.rand(-1.0..1.0) * [TILT, limit].min).round(1)
      end

      # A fragment's clay: its box, every edge worn
      def sherd(width, height, random)
        worn = edges(width, height).map do |x, y|
          "#{x + random.rand(-JITTER..JITTER)},#{y + random.rand(-JITTER..JITTER)}"
        end
        %(    <polygon class="sherd" points="#{worn.join(' ')}" fill="#{CLAY}" stroke="#{RIM}" stroke-width="1.5"/>\n)
      end

      # Points every STEP or so around a fragment's box
      def edges(width, height)
        corners = [[0, 0], [width, 0], [width, height], [0, height]].map { |x, y| [BOARD + x, BOARD + y] }
        corners.zip(corners.rotate).flat_map { |a, b| along(a, b) }
      end

      # Points every STEP or so along an edge, from its first corner
      def along((ax, ay), (bx, by))
        steps = [((bx - ax).abs + (by - ay).abs) / STEP, 1].max
        (0...steps).map { |k| [ax + ((bx - ax) * k / steps), ay + ((by - ay) * k / steps)] }
      end

      # A fragment's worn patches (:worn, under the wedges) or its lost stroke
      # positions (:lost_lines), drawn as Lacunae draws a plate's ('' if it has none)
      def lacunae(signs, part)
        worn = signs.filter_map { |sign| [sign.index, sign.lost, sign.turned, sign.origin] if sign.lost.any? }
        worn.empty? ? '' : "#{Lacunae.public_send(part, worn).gsub(/^/, '  ')}\n"
      end

      # The signs pressed in wedges, seeded by their place in the reading order as
      # on an intact plate (without the strokes a lacuna took)
      def wedges(signs)
        paths = signs.flat_map do |sign|
          SVG.press(Lacunae.strokes(sign.num, sign.lost), sign.turned, sign.origin, Random.new(sign.index))
        end
        %(    <g fill="black">\n#{paths.map { |d| %(      <path d="#{d}"/>) }.join("\n")}\n    </g>\n)
      end

      # The strokes that survive, as hidden lines: what the decoder reads
      def hidden(signs)
        lines = signs.flat_map do |sign|
          x, y = sign.origin
          sign.strokes.map { |stroke| SVG.line_tag(SVG.relative(stroke, -x, -y)) }
        end
        %(    <g stroke="black" stroke-width="2" display="none">\n#{lines.join("\n")}\n    </g>\n)
      end
    end
  end
end

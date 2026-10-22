# frozen_string_literal: true

module Cistergraphia
  # The lacunae of a weathered plate, in its SVG: drawn, hidden, read back.
  #
  # Purpose:
  # - Draw where the surface is lost, as an epigraphic drawing hatches a break
  # - Keep the lost stroke positions as hidden lines, apart from the strokes,
  #   so the decoder knows where it cannot see; read them back and restore
  #
  # Design Decisions:
  # - A lacuna is a set of stroke positions that cannot be read, so it is
  #   written as hidden <line>s in their own layer (class "lacunae"): they go
  #   through the same cell finding and half turns as the strokes, and every
  #   layout, grilles included, works unchanged
  # - Lost strokes are gone from the wedges and from the hidden strokes alike:
  #   the file never carries its own answer
  # - The worn patches lie under the wedges (strokes that survive at the edge
  #   of a break stay visible), roughened with the sign's own seed so the same
  #   plate always looks the same. The hatch is made of rects: the decoder
  #   reads every <line> outside the lacunae layer
  #
  # Constraints:
  # - Game plates only (see Weathering)
  module Lacunae
    CLASS = 'lacunae'
    HATCH = '#b3a993' # the edge of a break, as in the pattern below
    # The hatch of a break, made of rects (the decoder reads every <line> outside the lacunae)
    PATTERN = '<defs><pattern id="worn" width="8" height="8" patternUnits="userSpaceOnUse" ' \
              'patternTransform="rotate(45)"><rect width="8" height="8" fill="#ece6da"/>' \
              '<rect width="2" height="8" fill="#b3a993"/></pattern></defs>'
    SEALED = 'A worn plate is a game plate: read it without a passphrase'
    NOT_SEALED = 'A sealed plate cannot wear: with one stroke lost, it would never open again'
    NOT_TWO_READERS = 'A plate for two readers cannot wear yet'

    module_function

    # [sequence, svg, damage] for a weathered game plate along a layout. A
    # keyless plate that would also restore along the other layout is drawn
    # again, as Cistergraphia.inscribe does for intact plates
    # With tally signs, the plate may lose whole signs, which their row or column gives back.
    def inscribe(message, layout: :phaistos, passphrase: nil, tally: false, random: Random.new)
      refuse(passphrase, tally, layout)
      grille = layout.is_a?(Grille)
      100.times do
        sequence, damage = weathered(message, layout, tally, random)
        next if damage.empty? # a very short message may need another draw

        next unless grille || unambiguous?(sequence, damage, layout, tally)

        return [sequence, SVG.render(sequence, layout: layout, damage: damage, tally: tally), damage]
      end
      raise Error, 'Could not draw an unambiguous plate for this message'
    end

    def refuse(passphrase, tally, layout)
      raise Error, NOT_SEALED if passphrase
      raise Error, Tally::NOT_UNDER_A_GRILLE if tally && layout.is_a?(Grille)
    end

    # [sequence, damage] for a message: with tally signs, whole signs may be lost
    def weathered(message, layout, tally, random)
      sequence = Cistergraphia.encode(message, even: layout.is_a?(Grille))
      lines = Tally.lines(Integer.sqrt(sequence.size), layout) if tally
      [sequence, Weathering.weather(sequence, random: random, lines: lines)]
    end

    # Whether the plate restores along its own layout only, checked from the
    # data (parsing the file it would make costs more than all the rest)
    def unambiguous?(sequence, damage, layout, tally)
      Layout.others(layout, Integer.sqrt(sequence.size))
            .none? { |other| Along.edition(sequence, damage, layout, other, tally) }
    end

    # The restored text of a weathered plate, in the Leiden conventions
    def decode(svg, passphrase: nil, layout: nil)
      raise Error, SEALED if passphrase

      errors = (layout ? [layout] : Layout::KEYLESS).map do |candidate|
        return Weathering::Edition.text(restored(svg, candidate))
      rescue DecodeError => e
        e
      end
      raise layout.is_a?(Grille) ? WrongGrilleError.new(Grille::WRONG_KEY) : errors.first
    end

    # Whether a plate has lacunae (a string test first: intact plates are not parsed twice)
    def weathered?(svg)
      svg.to_s.include?(%(class="#{CLASS}")) && SVG.lines(svg, layer: :lacunae).any?
    end

    # [candidate values, damaged?] of every sign, narrowed by the tally signs if the plate has them
    def restored(svg, layout)
      cells = read(svg, layout)
      tally = Tally::Plate.read(svg, layout)
      return cells unless tally

      Tally.restore(cells.map(&:first), tally, layout).zip(cells.map(&:last))
    end

    # [candidate values, damaged?] of every sign, in reading order
    def read(svg, layout)
      strokes = cells(svg, :strokes, layout)
      lost = cells(svg, :lacunae, layout)
      Layout.path(SVG.grid_size(strokes), layout).map do |row, col, turned|
        visible = strokes.fetch([row, col]) { raise DecodeError, "Missing symbol at row #{row}, column #{col}" }
        gone = Layout.upright(lost.fetch([row, col], []), row, col, turned, layout)
        [Weathering.candidates(Layout.upright(visible, row, col, turned, layout), gone), gone.any?]
      end
    end

    # A layer's lines, by grid cell
    def cells(svg, layer, layout)
      SVG.lines(svg, layer: layer).group_by { |line| Layout.cell_of(line, layout) }
    end

    # A sign's strokes, without those a lacuna took
    def strokes(num, lost)
      Glyphs.strokes(num).reject { |stroke| lost.include?(Glyphs::CANONICAL.call(stroke)) }
    end

    # The worn patches, drawn under the wedges ('' for an intact plate)
    def patches(cols, layout, damage)
      return '' if damage.empty?

      %(#{PATTERN}\n#{worn(signs(cols, layout, damage))})
    end

    # The worn patches of some signs ([index, lost strokes, turned, sign origin]
    # each), filled with the PATTERN the document defines once
    def worn(signs)
      polygons = signs.flat_map do |index, lost, turned, origin|
        random = Random.new(index)
        Outline.shapes(lost).map do |shape|
          Outline.polygon(Outline.rough(shape, random).map { |point| Outline.place(point, turned, origin) })
        end
      end
      %(  <g class="weathering" fill="url(#worn)" stroke="#{HATCH}" stroke-width="1.5">\n) +
        %(#{polygons.join("\n")}\n  </g>)
    end

    # The lost stroke positions as hidden lines: what the decoder reads
    def hidden(cols, layout, damage)
      return '' if damage.empty?

      lost_lines(signs(cols, layout, damage))
    end

    # The lost stroke positions of some signs as hidden lines, in their own layer
    def lost_lines(signs)
      lines = signs.flat_map do |_, lost, turned, (x, y)|
        lost.map { |stroke| SVG.line_tag(Layout.relative(turned ? Glyphs.turn(stroke) : stroke, -x, -y)) }
      end
      %(  <g class="#{CLASS}" stroke="black" stroke-width="2" display="none">\n#{lines.join("\n")}\n  </g>)
    end

    # [index, lost strokes, turned, sign origin] of every damaged sign
    def signs(cols, layout, damage)
      Layout.path(cols, layout).each_with_index.filter_map do |(row, col, turned), index|
        [index, damage[index], turned, Layout.origin(row, col, layout)] if damage.key?(index)
      end
    end

    # What a weathered plate's file shows of itself, for a page that must hold
    # no more than the file (the reader's): the layout it reads along, its
    # damaged signs with their lost positions and the values their surviving
    # strokes allow, and every sign's value where no lacuna leaves it open
    module Survey
      module_function

      # The keyless layout along which the plate restores, or nil
      def layout(svg)
        Layout::KEYLESS.find { |layout| edition(svg, layout) }
      end

      def edition(svg, layout)
        Weathering::Edition.text(Lacunae.restored(svg, layout))
      rescue DecodeError
        nil
      end

      # [{ index:, lost:, candidates: }] of every damaged sign in reading order:
      # its lost stroke positions (canonical, upright) and what it can still be
      def damaged(svg, layout)
        strokes = Lacunae.cells(svg, :strokes, layout)
        lost = Lacunae.cells(svg, :lacunae, layout)
        Layout.path(SVG.grid_size(strokes), layout).each_with_index.filter_map do |(row, col, turned), index|
          gone = lost[[row, col]] or next
          seen = Layout.upright(strokes.fetch([row, col]), row, col, turned, layout)
          gone = Layout.upright(gone, row, col, turned, layout).map(&Glyphs::CANONICAL)
          { index: index, lost: gone, candidates: Weathering.candidates(seen, gone) }
        end
      end

      # Every sign's value as the file shows it: nil for a sign a lacuna touched
      def values(svg, layout)
        Lacunae.read(svg, layout).map { |candidates, worn| worn ? nil : candidates.first }
      end
    end

    # A weathered plate read along another layout, from the data: what the
    # decoder would find reading its file that way (the same signs, turned
    # where the two paths disagree), without drawing or parsing the file
    module Along
      module_function

      # The edition the decoder would print, or nil if the plate does not restore that way
      def edition(sequence, damage, layout, other, tally)
        cells = cells(sequence, damage, layout, other)
        cells = Tally.restore(cells.map(&:first), Tally.signs(sequence, layout), other).zip(cells.map(&:last)) if tally
        Weathering::Edition.text(cells)
      rescue DecodeError
        nil
      end

      # [candidate values, damaged?] of every sign as the other layout reads them
      def cells(sequence, damage, layout, other)
        size = Integer.sqrt(sequence.size)
        drawn = Layout.path(size, layout).each_with_index.to_h do |(row, col, turned), index|
          [[row, col], [index, turned]]
        end
        Layout.path(size, other).map do |row, col, turned|
          index, was = drawn.fetch([row, col])
          sign(sequence[index], damage.fetch(index, []), was != turned)
        end
      end

      # One sign's [candidates, damaged?], its strokes turned half round if the other path reads it so
      def sign(num, lost, turned)
        seen, gone = [Weathering.surviving(num, lost), lost].map do |strokes|
          turned ? strokes.map { |stroke| Glyphs.turn(stroke) } : strokes
        end
        [Weathering.candidates(seen, gone), gone.any?]
      end
    end

    # The shapes of a break, drawn in a sign's upright frame and placed on the plate
    module Outline
      BAND = 7    # half width of a worn band along one stroke
      JITTER = 3  # how ragged a break's edge is

      module_function

      # The outlines to wear: a whole quadrant as its box, otherwise a band along each lost stroke
      def shapes(lost)
        lost.group_by { |stroke| Glyphs::STROKE_PLACES.fetch(stroke) }.flat_map do |place, strokes|
          next [box(place)] if strokes.size == Weathering::POSITIONS.fetch(place).size

          strokes.map { |stroke| band(*stroke) }
        end
      end

      def box(place)
        xs, ys = Weathering::POSITIONS.fetch(place).flat_map { |stroke| stroke.each_slice(2).to_a }.transpose
        (x1, x2), (y1, y2) = [xs.minmax, ys.minmax]
        [[x1 - 5, y1 - 5], [x2 + 5, y1 - 5], [x2 + 5, y2 + 5], [x1 - 5, y2 + 5]]
      end

      # A rectangle around a stroke, a little longer than it
      def band(x1, y1, x2, y2)
        dx, dy = unit(x2 - x1, y2 - y1)
        ends = [shift([x1, y1], [dx, dy], -4), shift([x2, y2], [dx, dy], 4)]
        [[0, 1], [1, 1], [1, -1], [0, -1]].map { |end_, side| shift(ends[end_], [-dy * BAND, dx * BAND], side) }
      end

      # The direction of a stroke, as a vector of length 1
      def unit(width, height)
        length = Math.hypot(width, height)
        [width / length, height / length]
      end

      def shift((x, y), (dx, dy), amount)
        [x + (dx * amount), y + (dy * amount)]
      end

      # A broken edge: each side cut in three, every point moved a little
      def rough(corners, random)
        points = corners.zip(corners.rotate).flat_map { |a, b| thirds(a, b) }
        points.map { |x, y| [x + random.rand(-JITTER..JITTER), y + random.rand(-JITTER..JITTER)] }
      end

      def thirds((ax, ay), (bx, by))
        (0..2).map { |k| [ax + ((bx - ax) * k / 3.0), ay + ((by - ay) * k / 3.0)] }
      end

      # An upright point of a sign, on the plate (turned with its sign if need be)
      def place(point, turned, (ox, oy))
        x, y = turned ? [Glyphs::WIDTH - point[0], Glyphs::HEIGHT - point[1]] : point
        [x + ox, y + oy]
      end

      def polygon(points)
        %(    <polygon points="#{points.map { |x, y| format('%<x>.1f,%<y>.1f', x: x, y: y) }.join(' ')}"/>)
      end
    end
  end
end

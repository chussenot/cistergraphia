# frozen_string_literal: true

require 'rexml/document'

module Cistergraphia
  # Lays a sequence out along a reading path (a layout) in an SVG document,
  # and reads it back. SVG is written as plain strings (numbers only, nothing to escape) and
  # parsed with REXML, so no native XML dependency is needed.
  #
  # A plate shows its signs pressed in wedges (Stylus), one path per stroke in
  # reading order, and keeps every stroke as a hidden <line>: what the decoder
  # reads. Plates drawn before the wedges (visible lines only) read the same.
  # Where each sign goes is the Layout's business; a weathered plate's lacunae, Lacunae's.
  module SVG
    HOLE_MARGIN = 8 # between a stencil's hole and the edge of its cell
    STENCIL_NAMES = { whole: 'Grille', abbot: 'Abbot’s grille', novice: 'Novice’s grille' }.freeze

    module_function

    # Renders the sequence as a standalone SVG document along a layout's path
    # (with the strokes lost to weathering taken away: damage is Weathering's).
    # The root says what else the plate is: pathless (a class), with a tablet
    # of its own (its seed, data-tablet)
    def render(sequence, layout: :phaistos, damage: {}, tally: false, pathless: false, tablet: nil)
      width, height, cols, _rows = Layout.dimensions(sequence, layout, tally: tally)
      signs = Layout.placed(sequence, cols, layout, pathless: pathless)

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}"#{%( class="#{Pathless::CLASS}") if pathless}#{%( #{Tablet::ATTRIBUTE}="#{Tablet.normalize(tablet)}") if tablet}>
          <rect width="100%" height="100%" fill="white"/>
          #{Lacunae.patches(cols, layout, damage, pathless: pathless)}
          <g fill="black">
        #{pressed(signs, layout, damage).map { |outline| %(    <path d="#{outline}"/>) }.join("\n")}
          </g>
        #{lines_layer(signs, layout, damage)}
        #{Lacunae.hidden(cols, layout, damage, pathless: pathless)}
        #{Tally::Plate.layer(sequence, cols, layout) if tally}
        </svg>
      SVG
    end

    # Every stroke pressed by the hand, as SVG path data (one wedge each), sign
    # by sign (Layout.placed: in reading order, the hand seeded by the sign's
    # place in it, so the same plate is always pressed the same way). A turned
    # sign is pressed upright, then turned with its cell, as the scribe wrote
    # it with the tablet turned
    def pressed(signs, layout, damage = {})
      signs.flat_map do |(row, col, turned), num, index, seed|
        press(Lacunae.strokes(num, damage.fetch(index, [])), turned, Layout.origin(row, col, layout), Random.new(seed))
      end
    end

    # One sign's wedges as path data, in its cell (turned half round if need be)
    def press(strokes, turned, (x, y), random)
      strokes.map do |stroke|
        Stylus.wedge(stroke, random).map do |polygon|
          Stylus.outline(turned ? polygon.map { |px, py| [Glyphs::WIDTH - px, Glyphs::HEIGHT - py] } : polygon, x, y)
        end.join
      end
    end

    # Absolute strokes of every symbol, turned where the path says so
    def strokes(signs, layout, damage = {})
      signs.flat_map do |(row, col, turned), num, index, _|
        x, y = Layout.origin(row, col, layout)
        Lacunae.strokes(num, damage.fetch(index, [])).map do |stroke|
          Layout.relative(turned ? Glyphs.turn(stroke) : stroke, -x, -y)
        end
      end
    end

    # The strokes as hidden lines: what the decoder reads (lines, not wedges)
    def lines_layer(signs, layout, damage)
      lines = strokes(signs, layout, damage).map { |line| line_tag(line) }.join("\n")
      %(  <g stroke="black" stroke-width="2" display="none">\n#{lines}\n  </g>)
    end

    def line_tag((x1, y1, x2, y2))
      %(    <line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}"/>)
    end

    # Recovers the sequence from an SVG rendered by #render with that layout.
    # strokes: the document's lines already parsed (#lines), when the same
    # plate is read along several candidate layouts
    def read(svg, layout: :phaistos, strokes: nil)
      cells = (strokes || lines(svg)).group_by { |line| Layout.cell_of(line, layout) }

      Layout.path(grid_size(cells), layout).map { |row, col, turned| read_cell(cells, [row, col], turned, layout) }
    end

    # The number in one cell, its strokes made relative to the sign and turned back upright
    def read_cell(cells, (row, col), turned, layout)
      strokes = cells.fetch([row, col]) { raise DecodeError, "Missing symbol at row #{row}, column #{col}" }
      Glyphs.read(Layout.upright(strokes, row, col, turned, layout))
    end

    # True for a plate written under a grille: only those are square
    def square?(svg)
      root = Parsed.of(svg).root
      width = root&.attributes&.[]('width').to_s
      root&.name == 'svg' && !width.empty? && width == root.attributes['height'].to_s
    end

    # The grille as a stencil to print and cut, at the scale of its n x n plate:
    # laid on the printed plate with N at the top, it shows the first quarter of
    # the signs; turned a quarter clockwise, the next
    def stencil(size, grille)
      side = (Layout::SQUARE_CELL * size) + (Layout::PADDING * 2)
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="#{side}" height="#{side}" viewBox="0 0 #{side} #{side}">
          <path class="stencil-sheet" d="M0 0H#{side}V#{side}H0Z#{stencil_holes(size, grille)}" fill="#efe6d4" fill-rule="evenodd" stroke="#2b241c" stroke-width="2"/>
          <text class="stencil-north" x="#{side / 2}" y="38" text-anchor="middle" font-family="Georgia, serif" font-size="32" fill="#a3301c">N</text>
          <text class="stencil-key" x="#{side / 2}" y="#{side - 17}" text-anchor="middle" font-family="Georgia, serif" font-size="16" fill="#62574a">#{STENCIL_NAMES.fetch(grille.part)} #{grille} · turn clockwise</text>
        </svg>
      SVG
    end

    def stencil_holes(size, grille)
      hole = Layout::SQUARE_CELL - (2 * HOLE_MARGIN)
      grille.holes(size).map do |row, col|
        x, y = Layout.cell_origin(row, col, grille)
        "M#{x + HOLE_MARGIN} #{y + HOLE_MARGIN}h#{hole}v#{hole}h-#{hole}Z"
      end.join
    end

    # Side of the square grid the cells form
    def grid_size(cells)
      raise DecodeError, 'No signs found on this plate' if cells.empty?

      size = Integer.sqrt(cells.size)
      raise DecodeError, "#{cells.size} symbols do not form a square grid" unless size**2 == cells.size

      size
    end

    # Every <line> of the document as [x1, y1, x2, y2] integers: the strokes,
    # or (layer: :lacunae) the stroke positions a weathered plate has lost, or
    # (layer: :tally) the tally signs. Frozen: the layers are read once per file
    def lines(svg, layer: :strokes)
      Layers.of(svg).fetch(layer)
    end

    # A file's lines by layer, read in one pass from its document (Parsed)
    # and kept for the file last read on this thread: a page lays a puzzle from
    # one file a dozen times (the survey, the tally, the decoder, the way)
    module Layers
      module_function

      def of(svg)
        text = svg.to_s
        kept = (Thread.current[:cistergraphia_layers] ||= {})
        kept.fetch(text) do
          kept.clear
          kept[text] = read(text)
        end
      end

      def read(text)
        root = Parsed.of(text).root
        raise DecodeError, 'Not an SVG document' unless root&.name == 'svg'

        found = { strokes: [], lacunae: [], tally: [] }
        root.each_recursive do |node|
          layer = layer_of(node)
          found[layer] << line(node) if layer
        end
        found.transform_values { |lines| lines.each(&:freeze).freeze }.freeze
      end

      # Strokes are lines in no named layer; lacunae and tally signs have their own
      def layer_of(node)
        return unless node.name == 'line'

        case node.parent.attributes['class']
        when nil then :strokes
        when Lacunae::CLASS then :lacunae
        when Tally::CLASS then :tally
        end
      end

      def line(node)
        %w[x1 y1 x2 y2].map { |attr| SVG.coordinate(node.attributes[attr]) }
      end
    end

    # A file's document, parsed once and kept for the file last parsed on this
    # thread: the cleaner, the grille's test, the lines, the fragments and the
    # way all read one file, and parsing a large plate costs a quarter of a
    # second. Read, never changed: a reader that rewrites a plate parses its own
    # (SVG.parse). One file per thread, and the app forgets it after each request
    module Parsed
      module_function

      def of(svg)
        text = svg.to_s
        kept = (Thread.current[:cistergraphia_document] ||= {})
        kept.fetch(text) do
          kept.clear
          kept[text] = SVG.parse(text)
        end
      end

      # What the thread keeps of the last file read (its document, its lines),
      # let go: after a request, nothing of a reader's plate stays in memory
      def forget
        Thread.current[:cistergraphia_document] = nil
        Thread.current[:cistergraphia_layers] = nil
      end
    end

    # (quoted: true writes the elements back with double quotes, as the library draws them)
    def parse(svg, quoted: false)
      REXML::Document.new(svg.to_s, quoted ? { attribute_quote: :quote } : {})
    rescue REXML::ParseException
      raise DecodeError, 'Unreadable SVG: not well-formed XML'
    end

    def coordinate(value)
      Float(value).round
    rescue ArgumentError, TypeError
      raise DecodeError, "Invalid line coordinate: #{value.inspect}"
    end
  end
end

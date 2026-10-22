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
    # (with the strokes lost to weathering taken away: damage is Weathering's)
    def render(sequence, layout: :phaistos, damage: {}, tally: false)
      width, height, cols, _rows = Layout.dimensions(sequence, layout, tally: tally)

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
          <rect width="100%" height="100%" fill="white"/>
          #{Lacunae.patches(cols, layout, damage)}
          <g fill="black">
        #{pressed(sequence, cols, layout, damage).map { |outline| %(    <path d="#{outline}"/>) }.join("\n")}
          </g>
          <g stroke="black" stroke-width="2" display="none">
        #{strokes(sequence, cols, layout, damage).map { |line| line_tag(line) }.join("\n")}
          </g>
        #{Lacunae.hidden(cols, layout, damage)}
        #{Tally::Plate.layer(sequence, cols, layout) if tally}
        </svg>
      SVG
    end

    # Every stroke pressed by the hand, as SVG path data (one wedge each), sign
    # by sign in reading order. A turned sign is pressed upright, then turned
    # with its cell, as the scribe wrote it with the tablet turned. The hand is
    # seeded by the sign's place in the reading order, so the same plate is
    # always pressed the same way.
    def pressed(sequence, cols, layout, damage = {})
      Layout.path(cols, layout).zip(sequence).each_with_index.flat_map do |((row, col, turned), num), index|
        press(Lacunae.strokes(num, damage.fetch(index, [])), turned, Layout.origin(row, col, layout), Random.new(index))
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

    # Absolute strokes of every symbol in reading order, turned where the path says so
    def strokes(sequence, cols, layout, damage = {})
      Layout.path(cols, layout).zip(sequence).each_with_index.flat_map do |((row, col, turned), num), index|
        x, y = Layout.origin(row, col, layout)
        Lacunae.strokes(num, damage.fetch(index, [])).map do |stroke|
          relative(turned ? Glyphs.turn(stroke) : stroke, -x, -y)
        end
      end
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
      root = parse(svg).root
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

    def relative(line, x, y)
      x1, y1, x2, y2 = line
      [x1 - x, y1 - y, x2 - x, y2 - y]
    end

    # Every <line> of the document as [x1, y1, x2, y2] integers: the strokes,
    # or (layer: :lacunae) the stroke positions a weathered plate has lost
    def lines(svg, layer: :strokes)
      root = parse(svg).root
      raise DecodeError, 'Not an SVG document' unless root&.name == 'svg'

      lines = []
      root.each_recursive do |node|
        lines << %w[x1 y1 x2 y2].map { |attr| coordinate(node.attributes[attr]) } if in_layer?(node, layer)
      end
      lines
    end

    # Strokes are lines in no named layer; lacunae and tally signs have their own
    def in_layer?(node, layer)
      node.name == 'line' && node.parent.attributes['class'] == { lacunae: Lacunae::CLASS, tally: Tally::CLASS }[layer]
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

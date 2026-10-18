# frozen_string_literal: true

require 'rexml/document'

module Cistergraphia
  # Lays a sequence out along a reading path (a layout) in an SVG document,
  # and reads it back. SVG is written as plain strings (numbers only, nothing to escape) and
  # parsed with REXML, so no native XML dependency is needed.
  module SVG
    SPACE = 20
    PADDING = 50 # Padding around the content
    CELL_WIDTH = Glyphs::WIDTH + SPACE
    CELL_HEIGHT = Glyphs::HEIGHT + SPACE
    LAYOUTS = %i[phaistos rongorongo].freeze

    module_function

    # Calculates the dimensions needed to display the sequence in a square grid
    def dimensions(sequence)
      cols = Integer.sqrt(sequence.size)
      raise EmptyMessageError, 'Cannot lay out an empty sequence' if cols.zero?

      rows = sequence.size.ceildiv(cols)
      [(CELL_WIDTH * cols) + (PADDING * 2), (CELL_HEIGHT * rows) + (PADDING * 2), cols, rows]
    end

    # [row, col, turned] of every sign, in reading order
    def path(size, layout = :phaistos)
      case layout
      when :phaistos then Cistergraphia.spiral_coordinates(size).map { |row, col| [row, col, false] }
      when :rongorongo then Cistergraphia.boustrophedon_coordinates(size)
      else raise Error, "Unknown layout #{layout.inspect}: use #{LAYOUTS.join(' or ')}"
      end
    end

    # Renders the sequence as a standalone SVG document along a layout's path
    def render(sequence, layout: :phaistos)
      width, height, cols, _rows = dimensions(sequence)

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
          <rect width="100%" height="100%" fill="white"/>
          <g stroke="black" stroke-width="2">
        #{strokes(sequence, cols, layout).map { |line| line_tag(line) }.join("\n")}
          </g>
        </svg>
      SVG
    end

    # Absolute strokes of every symbol in reading order, turned where the path says so
    def strokes(sequence, cols, layout)
      path(cols, layout).zip(sequence).flat_map do |(row, col, turned), num|
        x, y = origin(row, col)
        Glyphs.strokes(num).map { |stroke| relative(turned ? Glyphs.turn(stroke) : stroke, -x, -y) }
      end
    end

    def line_tag((x1, y1, x2, y2))
      %(    <line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}"/>)
    end

    # Recovers the sequence from an SVG rendered by #render with that layout
    def read(svg, layout: :phaistos)
      cells = lines(svg).group_by { |line| cell_of(line) }

      path(grid_size(cells), layout).map { |row, col, turned| read_cell(cells, row, col, turned) }
    end

    # The number in one cell, its strokes made relative to the cell and turned back upright
    def read_cell(cells, row, col, turned)
      strokes = cells.fetch([row, col]) { raise DecodeError, "Missing symbol at row #{row}, column #{col}" }
      local = strokes.map { |line| relative(line, *origin(row, col)) }
      Glyphs.read(turned ? local.map { |stroke| Glyphs.turn(stroke) } : local)
    end

    # Side of the square grid the cells form
    def grid_size(cells)
      raise DecodeError, 'No Cistergraphia symbols found' if cells.empty?

      size = Integer.sqrt(cells.size)
      raise DecodeError, "#{cells.size} symbols do not form a square grid" unless size**2 == cells.size

      size
    end

    # Top-left corner of a grid cell
    def origin(row, col)
      [PADDING + (CELL_WIDTH * col), PADDING + (CELL_HEIGHT * row)]
    end

    # Grid [row, col] a line belongs to, from its top-left-most point
    def cell_of(line)
      x1, y1, x2, y2 = line
      [([y1, y2].min - PADDING).div(CELL_HEIGHT), ([x1, x2].min - PADDING).div(CELL_WIDTH)]
    end

    def relative(line, x, y)
      x1, y1, x2, y2 = line
      [x1 - x, y1 - y, x2 - x, y2 - y]
    end

    # Every <line> of the document as [x1, y1, x2, y2] integers
    def lines(svg)
      root = parse(svg).root
      raise DecodeError, 'Not an SVG document' unless root&.name == 'svg'

      lines = []
      root.each_recursive do |node|
        lines << %w[x1 y1 x2 y2].map { |attr| coordinate(node.attributes[attr]) } if node.name == 'line'
      end
      lines
    end

    def parse(svg)
      REXML::Document.new(svg.to_s)
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

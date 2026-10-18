# frozen_string_literal: true

require 'json'

# View helpers for the web UI: small inline SVGs drawn from the real cipher
# geometry, so the illustrations on the page are always truthful.
module ViewHelpers
  GLYPH_VIEWBOX = '-8 -8 116 166'

  # The glyph geometry and tablet as JSON, for the live previews in app.js.
  # Generated from the library so the browser never holds a second copy of the cipher.
  def glyph_table_json
    @glyph_table_json ||= JSON.generate(
      viewBox: GLYPH_VIEWBOX,
      stem: Cistergraphia::Glyphs::STEM,
      lines: Cistergraphia::Glyphs::LINES,
      tablet: Cistergraphia::TABLET.to_h { |char, value| [char.to_s, value * 10] }
    )
  end

  # One Cistercian numeral as an inline SVG
  def glyph_svg(num, css: 'glyph', title: nil)
    lines = Cistergraphia::Glyphs.strokes(num).map { |x1, y1, x2, y2| line_tag(x1, y1, x2, y2) }.join
    label = title || num.to_s
    %(<svg class="#{css}" viewBox="#{GLYPH_VIEWBOX}" role="img" aria-label="#{label}">) +
      %(<title>#{label}</title><g>#{lines}</g></svg>)
  end

  # The snail reading order over an n x n grid: dots and the path through them
  def snail_svg(size = 4)
    points = Cistergraphia.spiral_coordinates(size).map { |row, col| [(col * 20) + 10, (row * 20) + 10] }
    %(<svg class="snail" viewBox="0 0 #{size * 20} #{size * 20}" role="img" ) +
      %(aria-label="Reading order: a clockwise spiral from the top-left corner">#{snail_marks(points)}</svg>)
  end

  def snail_marks(points)
    path = %(<polyline points="#{points.map { |x, y| "#{x},#{y}" }.join(' ')}" pathLength="1"/>)
    dots = points.map { |x, y| %(<circle cx="#{x}" cy="#{y}" r="2.2"/>) }.join
    start_x, start_y = points.first
    %(#{path}#{dots}<circle class="snail-start" cx="#{start_x}" cy="#{start_y}" r="4"/>)
  end

  def line_tag(x1, y1, x2, y2)
    %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}"/>)
  end

  # Where each sign of a plate sits, in reading (snail) order, for walking the
  # plate in app.js: [[row, col, value], ...] plus the grid geometry
  def plate_cells_json(sequence)
    size = Integer.sqrt(sequence.size)
    cells = Cistergraphia.spiral_coordinates(size).zip(sequence).map { |(row, col), value| [row, col, value] }
    JSON.generate(cells)
  end

  def plate_layout_json(sequence)
    JSON.generate(padding: Cistergraphia::SVG::PADDING, cell: [Cistergraphia::SVG::CELL_WIDTH, Cistergraphia::SVG::CELL_HEIGHT],
                  space: Cistergraphia::SVG::SPACE, size: Integer.sqrt(sequence.size))
  end

  DESCRIPTION = 'Write a message as Cistercian numerals coiled like a snail: a cipher game, ' \
                'or a passphrase-sealed secret.'

  def page_description
    @description || DESCRIPTION
  end

  def nav_class(page)
    @page == page ? 'is-current' : nil
  end
end

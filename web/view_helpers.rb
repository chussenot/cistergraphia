# frozen_string_literal: true

require 'json'

# View helpers for the web UI: small inline SVGs drawn from the real cipher
# geometry, so the illustrations on the page are always truthful.
module ViewHelpers
  GLYPH_VIEWBOX = '-8 -8 116 166'

  # Every stroke a sign can have (the stem and the twenty of the four corners),
  # pressed as a wedge: "x1,y1,x2,y2" => SVG path data
  WEDGES = [Cistergraphia::Glyphs::STEM, *Cistergraphia::Glyphs::LINES.values.flatten(1)].uniq.to_h do |stroke|
    [stroke.join(','), Cistergraphia::Stylus.press(stroke)]
  end.freeze

  # The glyph geometry, its wedges and the tablet as JSON, for the live previews in app.js.
  # Generated from the library so the browser never holds a second copy of the cipher.
  def glyph_table_json
    @glyph_table_json ||= JSON.generate(
      viewBox: GLYPH_VIEWBOX,
      stem: Cistergraphia::Glyphs::STEM,
      lines: Cistergraphia::Glyphs::LINES,
      wedges: WEDGES,
      tablet: Cistergraphia::TABLET.to_h { |char, value| [char.to_s, value * 10] }
    )
  end

  # One Cistercian numeral as an inline SVG, pressed: one wedge per stroke
  def glyph_svg(num, css: 'glyph', title: nil)
    wedges = Cistergraphia::Glyphs.strokes(num).map { |stroke| %(<path d="#{WEDGES.fetch(stroke.join(','))}"/>) }.join
    label = title || num.to_s
    %(<svg class="#{css}" viewBox="#{GLYPH_VIEWBOX}" role="img" aria-label="#{label}">) +
      %(<title>#{label}</title><g>#{wedges}</g></svg>)
  end

  ORDER_LABELS = {
    phaistos: 'Reading order: a clockwise spiral from the top-left corner',
    rongorongo: 'Reading order: rows from the bottom left, every other row running back upside down'
  }.freeze

  # A layout's reading order over an n x n grid: dots and the path through them.
  # Hollow dots are signs written upside down (the plate turns between rows).
  def snail_svg(size = 4, layout: :phaistos)
    cells = Cistergraphia::SVG.path(size, layout).map { |row, col, turned| [(col * 20) + 10, (row * 20) + 10, turned] }
    %(<svg class="snail" viewBox="0 0 #{size * 20} #{size * 20}" role="img" ) +
      %(aria-label="#{ORDER_LABELS.fetch(layout)}">#{snail_marks(cells)}</svg>)
  end

  def snail_marks(cells)
    path = %(<polyline points="#{points(cells)}" pathLength="1"/>)
    dots = cells.map { |x, y, turned| %(<circle cx="#{x}" cy="#{y}" r="2.2"#{' class="turned"' if turned}/>) }.join
    start_x, start_y = cells.first
    %(#{path}#{dots}<circle class="snail-start" cx="#{start_x}" cy="#{start_y}" r="4"/>)
  end

  # Rongorongo: reverse boustrophedon. Lines read left to right from the bottom;
  # the tablet turns 180 degrees between lines, so every other line is upside
  # down and runs the other way when the tablet is seen still.
  BOUSTROPHEDON_ROWS = [64, 48, 32, 16].freeze

  def boustrophedon_svg
    label = 'Reverse boustrophedon: read left to right from the bottom, turning the tablet half round between lines'
    tablet = %(<rect x="4" y="4" width="92" height="72" rx="6"/><g class="turning-glyphs">#{boustrophedon_ticks}</g>)
    path = %(<polyline points="#{points(boustrophedon_path)}" pathLength="1"/>)
    start = '<circle class="snail-start" cx="14" cy="64" r="3"/>'
    %(<svg class="turning" viewBox="0 0 100 80" role="img" aria-label="#{label}">#{tablet}#{path}#{start}</svg>)
  end

  def boustrophedon_path
    BOUSTROPHEDON_ROWS.each_with_index.flat_map { |y, i| i.even? ? [[14, y], [86, y]] : [[86, y], [14, y]] }
  end

  # Little signs along each line: upright on read lines, upside down on the turned ones
  def boustrophedon_ticks
    BOUSTROPHEDON_ROWS.each_with_index.flat_map do |y, i|
      (20..80).step(12).map { |x| i.even? ? %(<path d="M#{x} #{y - 2}v-7h4"/>) : %(<path d="M#{x} #{y - 9}v7h-4"/>) }
    end.join
  end

  # Phaistos Disc: a spiral read clockwise from the rim to the centre
  def disc_spiral_svg
    label = 'A spiral read clockwise from the rim to the centre'
    path = %(<polyline points="#{points(spiral_path)}" pathLength="1"/>)
    %(<svg class="turning" viewBox="0 0 100 100" role="img" aria-label="#{label}"><circle cx="50" cy="50" r="47"/>) +
      %(#{path}<circle class="snail-start" cx="50" cy="8" r="3"/></svg>)
  end

  # Three turns from radius 42 to 8, starting at the top; angles grow clockwise on screen
  def spiral_path(turns: 3)
    steps = turns * 36
    (0..steps).map { |i| polar(42 - (34.0 * i / steps), -90 + (i * 10)) }
  end

  # A point of the 100 x 100 figure, around its centre
  def polar(radius, degrees)
    angle = degrees * Math::PI / 180
    [(50 + (radius * Math.cos(angle))).round(1), (50 + (radius * Math.sin(angle))).round(1)]
  end

  def points(path)
    path.map { |x, y, *| "#{x},#{y}" }.join(' ')
  end

  # Where each sign of a plate sits, in reading order, for walking the plate in
  # app.js: [[row, col, value, turned], ...] plus the grid geometry
  def plate_cells_json(sequence, layout = :phaistos)
    path = Cistergraphia::SVG.path(Integer.sqrt(sequence.size), layout)
    JSON.generate(path.zip(sequence).map { |(row, col, turned), value| [row, col, value, turned] })
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

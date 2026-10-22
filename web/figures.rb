# frozen_string_literal: true

# The small diagrams of the reading orders (Inscribe's key, the About page):
# each layout drawn from the real reading path, beside what it comes from.
module Figures
  ORDER_LABELS = {
    phaistos: 'Reading order: a clockwise spiral from the top-left corner',
    rongorongo: 'Reading order: rows from the bottom left, every other row running back upside down',
    leap: 'Reading order: one row down and two columns across at every sign, wrapping at the edge; when the orbit ' \
          'closes, a new start one column to the right',
    furrows: 'Reading order: down the first column, up the next, from the left',
    unwinding: 'Reading order: from the centre outward, counter-clockwise, to the top-right corner',
    grille: 'Reading order: the signs under the grille’s holes, row by row, then the grille turned a quarter ' \
            'clockwise, four times'
  }.freeze

  # A layout's reading order over an n x n grid: dots and the path through them.
  # Hollow dots are signs written upside down (the plate turns between rows).
  def snail_svg(size = 4, layout: :phaistos)
    cells = Cistergraphia::Layout.path(size, layout).map { |row, col, turned| [(col * 20) + 10, (row * 20) + 10, turned] }
    %(<svg class="snail" viewBox="0 0 #{size * 20} #{size * 20}" role="img" ) +
      %(aria-label="#{ORDER_LABELS.fetch(layout)}">#{snail_marks(cells)}</svg>)
  end

  def snail_marks(cells)
    dots = cells.map { |x, y, turned| %(<circle cx="#{x}" cy="#{y}" r="2.2"#{' class="turned"' if turned}/>) }.join
    start_x, start_y = cells.first
    %(#{snail_lines(cells)}#{dots}<circle class="snail-start" cx="#{start_x}" cy="#{start_y}" r="4"/>)
  end

  # The line through the cells, broken where a step wraps across the grid (the leap)
  def snail_lines(cells)
    runs = cells.slice_when { |(x1, y1), (x2, y2)| Math.hypot(x2 - x1, y2 - y1) > 50 }
    runs.map { |run| %(<polyline points="#{points(run)}" pathLength="1"/>) }.join
  end

  # Rongorongo: reverse boustrophedon. Lines read left to right from the bottom;
  # the tablet turns 180 degrees between lines, so every other line is upside
  # down and runs the other way when the tablet is seen still.
  BOUSTROPHEDON_ROWS = [64, 48, 32, 16].freeze

  # Cardano's grille: an ordinary letter, words as strokes ([x, length] by line),
  # and the openings ([line, word]) through which its secret words were written
  CARDANO_LETTER = [[[12, 16], [32, 10], [46, 22], [72, 16]], [[12, 24], [40, 14], [58, 30]],
                    [[12, 10], [26, 20], [50, 14], [68, 20]], [[12, 30], [46, 18], [68, 20]],
                    [[12, 18], [34, 26], [64, 14]]].freeze
  CARDANO_OPENINGS = [[0, 2], [2, 1], [3, 2], [4, 0]].freeze

  def cardano_svg
    label = 'Cardano’s grille: an ordinary letter, with openings over the words that carry the secret'
    sheet = %(<rect x="4" y="4" width="92" height="72" rx="6"/>)
    %(<svg class="turning" viewBox="0 0 100 80" role="img" aria-label="#{label}">#{sheet}) +
      %(<g class="turning-glyphs">#{cardano_words}</g>#{cardano_openings}</svg>)
  end

  def cardano_words
    CARDANO_LETTER.each_with_index.flat_map do |line, row|
      line.map { |x, length| %(<path d="M#{x} #{16 + (row * 12)}h#{length}"/>) }
    end.join
  end

  def cardano_openings
    CARDANO_OPENINGS.map do |row, word|
      x, length = CARDANO_LETTER[row][word]
      %(<rect class="aperture" x="#{x - 2}" y="#{11 + (row * 12)}" width="#{length + 4}" height="10" rx="1.5"/>)
    end.join
  end

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

  GRILLE_EXAMPLE = Cistergraphia::Grille.new(Cistergraphia::Grille::EXAMPLE)

  # A grille over a 4 x 4 grid: its holes at N, and the turn at which each
  # other cell comes under a hole
  def grille_order_svg
    cells = (0..3).flat_map { |turn| GRILLE_EXAMPLE.holes(4, turn).map { |cell| grille_cell(cell, turn) } }
    label = ORDER_LABELS.fetch(:grille)
    %(<svg class="grille-order" viewBox="0 0 80 80" role="img" aria-label="#{label}">#{cells.join}</svg>)
  end

  def grille_cell((row, col), turn)
    x = col * 20
    y = row * 20
    rect = %(<rect x="#{x + 1.5}" y="#{y + 1.5}" width="17" height="17" rx="2"/>)
    letter = %(<text x="#{x + 10}" y="#{y + 13.5}">#{Cistergraphia::Grille::TURNS[turn]}</text>)
    %(<g class="grille-cell#{' grille-hole' if turn.zero?}">#{rect}#{letter}</g>)
  end
end

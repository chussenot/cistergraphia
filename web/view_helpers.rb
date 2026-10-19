# frozen_string_literal: true

require 'json'

# View helpers for the web UI: signs drawn from the real cipher geometry, so the
# illustrations on the page are always truthful, and the plate's data for app.js.
# The diagrams of the reading orders are in Figures.
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

  # Where each sign of a plate sits, in reading order, for walking the plate in
  # app.js: [[row, col, value, turned], ...] plus the grid geometry. A sign a
  # lacuna took part of has no value (null): the page must not hold the answer
  def plate_cells_json(sequence, layout = :phaistos, damage = {})
    path = Cistergraphia::Layout.path(Integer.sqrt(sequence.size), layout)
    JSON.generate(path.zip(sequence).each_with_index.map do |((row, col, turned), value), index|
      [row, col, damage.key?(index) ? nil : value, turned]
    end)
  end

  # A Leiden edition as HTML: [r] restored, [b/l] doubtful, the rest as read
  def leiden_html(text)
    text.split(/(\[[^\]]*\])/).reject(&:empty?).map do |part|
      next Rack::Utils.escape_html(part) unless part.start_with?('[')

      css = part.include?('/') ? 'leiden-doubt' : 'leiden-restored'
      %(<span class="#{css}">#{Rack::Utils.escape_html(part)}</span>)
    end.join
  end

  # The grid's geometry for walking it: where a cell's box starts (offset) is
  # half a gap before an upright sign, and the square cell itself under a grille,
  # where the sign is centred
  def plate_layout_json(sequence, layout = :phaistos)
    grille = layout.is_a?(Cistergraphia::Grille)
    JSON.generate(padding: Cistergraphia::Layout::PADDING, cell: Cistergraphia::Layout.cell(layout),
                  offset: grille ? 0 : -Cistergraphia::Layout::SPACE / 2, size: Integer.sqrt(sequence.size),
                  grille: grille)
  end

  DESCRIPTION = 'Write a message as Cistercian numerals coiled like a snail: a cipher game, ' \
                'or a passphrase-sealed secret.'

  def page_description
    @description || DESCRIPTION
  end

  LAYOUT_NAMES = { phaistos: 'Phaistos', rongorongo: 'Rongorongo' }.freeze

  def layout_name(layout)
    return LAYOUT_NAMES.fetch(layout) unless layout.is_a?(Cistergraphia::Grille)

    layout.part == :pair ? 'Grille, two readers' : 'Grille'
  end

  STENCIL_LABELS = { whole: 'the grille', abbot: 'the abbot’s grille', novice: 'the novice’s grille' }.freeze

  # The grilles of a plate, each with its stencil and its reading path: the
  # grille, or the abbot's and the novice's
  def plate_grilles
    grilles = @layout.part == :pair ? [@layout.as(:abbot), @layout.novice] : [@layout]
    size = Integer.sqrt(@symbols)
    grilles.map do |grille|
      { part: grille.part, label: STENCIL_LABELS.fetch(grille.part), key: grille.to_s,
        stencil: Cistergraphia::SVG.stencil(size, grille), path: JSON.generate(grille.path(size)) }
    end
  end

  def grille?
    @layout.is_a?(Cistergraphia::Grille)
  end

  # The grille is the layout on the form: chosen, or sent back with an error
  def grille_chosen?
    @layout.is_a?(Cistergraphia::Grille) || !@grille_error.nil?
  end

  def nav_class(page)
    @page == page ? 'is-current' : nil
  end
end

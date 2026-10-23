# frozen_string_literal: true

module Cistergraphia
  module Lacunae
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

      # Every worn cell of a pathless plate, in grid order, read upright and
      # turned half round: [row, col, upright, turned], each reading what the
      # file shows of the sign that way ({ lost:, candidates: }, the lost
      # positions canonical) or nil where its strokes read as no sign so
      # turned. What a bench needs to lay any of the five ways over the grid
      def worn_cells(svg)
        strokes = Lacunae.cells(svg, :strokes, :phaistos)
        Lacunae.cells(svg, :lacunae, :phaistos).sort.map do |(row, col), gone|
          seen = strokes.fetch([row, col]) { raise DecodeError, "Missing symbol at row #{row}, column #{col}" }
          [row, col, *[false, true].map { |turned| worn_reading(seen, gone, row, col, turned) }]
        end
      end

      def worn_reading(seen, gone, row, col, turned)
        seen, gone = [seen, gone].map { |lines| Layout.upright(lines, row, col, turned, :phaistos) }
        gone = gone.map(&Glyphs::CANONICAL)
        { lost: gone, candidates: Weathering.candidates(seen, gone) }
      rescue DecodeError
        nil
      end
    end
  end
end

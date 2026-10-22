# frozen_string_literal: true

require 'json'

# A broken plate's fragments, for rejoining them on the page (app.js): what
# the file shows of each fragment, never where it goes. Mixed into the views.
module TrayHelpers
  # The board's geometry, both reading paths, the tablet, and every fragment
  # in file order: its size and each sign read upright and turned half round,
  # row by row, as the fragment lies in the tray: [upright, turned, worn], the
  # readings as candidate values (one for an intact sign, what the strokes
  # allow for a worn one: what the file shows, never what was lost)
  def fragments_json(fragments, size)
    JSON.generate(
      cell: Cistergraphia::Layout.cell(:phaistos), board: Cistergraphia::Fragments::BOARD,
      gap: Cistergraphia::Fragments::Tray::GAP, size: size,
      paths: Cistergraphia::Layout::KEYLESS.to_h { |layout| [layout, Cistergraphia::Layout.path(size, layout)] },
      tablet: Cistergraphia::CHARACTERS, null: Cistergraphia::EVIL_MARKER,
      fragments: fragments.map do |fragment|
        { rows: fragment.rows, cols: fragment.cols, signs: fragment.cells.map { |cell| fragment.readings.fetch(cell) } }
      end
    )
  end

  # "12 lacunae"
  def lacunae_count(count)
    "#{count} #{count == 1 ? 'lacuna' : 'lacunae'}"
  end

  # "3 fragments"
  def fragments_count(count)
    count == 1 ? '1 fragment' : "#{count} fragments"
  end
end

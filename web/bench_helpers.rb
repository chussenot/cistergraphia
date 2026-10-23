# frozen_string_literal: true

require 'json'

# The restoration bench under a weathered plate (see app.js, initBench): what
# the page needs to let a reader press lost digits back in, and the bench's
# first state, drawn by the server exactly as the script draws it.
#
# The page only ever holds what the file shows: where each lacuna is, its lost
# stroke positions, the digits its surviving strokes allow, the digits of its
# sign that are not lost, and the tally signs. Never a lost value. On a
# pathless plate, the same per cell and either way up, never along the way.
module BenchHelpers
  PLACE_NAMES = { 1 => 'units', 10 => 'tens', 100 => 'hundreds', 1000 => 'thousands' }.freeze

  def place_name(place)
    PLACE_NAMES.fetch(place)
  end

  # One entry per damaged place of a sign (a sign wholly lost has four), in
  # reading order, from the plate's data (the scribe's page)
  def lacunae(sequence, layout, damage)
    path = Cistergraphia::Layout.path(Integer.sqrt(sequence.size), layout)
    damage.sort.flat_map { |index, lost| sign_entries(path, layout, index, lost, options(sequence[index], lost)) }
  end

  # The same entries from the plate's file alone (the reader's page): the
  # survey's lost positions and candidates are what the file shows
  def lacunae_in(svg, layout, values)
    path = Cistergraphia::Layout.path(Integer.sqrt(values.size), layout)
    Cistergraphia::Lacunae::Survey.damaged(svg, layout).flat_map do |sign|
      sign_entries(path, layout, sign[:index], sign[:lost], sign[:candidates])
    end
  end

  # The same entries from a plate rejoined (Fragments::Whole): its lacunae and
  # what each worn sign may hold are what its fragments show
  def lacunae_from(values, layout, damage, candidates)
    path = Cistergraphia::Layout.path(Integer.sqrt(values.size), layout)
    damage.sort.flat_map { |index, lost| sign_entries(path, layout, index, lost, candidates.fetch(index)) }
  end

  # A pathless worn plate's worn cells (the reader's page): each in grid order
  # with its lacunae read upright and turned half round (nil where its strokes
  # read as no sign so turned), so the bench can lay any of the five ways over
  # the grid and index them along it. Never a sign's place in the reading order
  def worn_cells(svg)
    Cistergraphia::Lacunae::Survey.worn_cells(svg).map do |row, col, upright, turned|
      { row: row, col: col, upright: cell_entries(upright), turned: cell_entries(turned) }
    end
  end

  def cell_entries(reading)
    reading && by_place(reading[:candidates], reading[:lost])
  end

  # How many lacunae a pathless plate's bench will show along any way: one per
  # damaged place of each worn cell (the same number either way up)
  def pathless_lacunae(worn)
    worn.sum { |cell| (cell[:upright] || cell[:turned]).size }
  end

  def sign_entries(path, layout, index, lost, options)
    row, col, turned = path[index]
    x, y = Cistergraphia::Layout.origin(row, col, layout)
    sign = { sign: index, x: x, y: y, turned: turned }
    by_place(options, lost).map { |entry| sign.merge(entry) }
  end

  # Each damaged place of a sign: its lost strokes, the digits it can still
  # hold (options: the values the sign can be), the sign's digits that survive
  # (0 in its damaged places) and those places
  def by_place(options, lost)
    places = lost.group_by { |stroke| Cistergraphia::Glyphs::STROKE_PLACES.fetch(stroke) }
    shared = { known: without(options.first, places.keys), open: places.keys.sort }
    places.sort.reverse.map do |place, strokes|
      { place: place, lost: strokes.map { |stroke| stroke.join(',') }, digits: digits_at(options, place) }.merge(shared)
    end
  end

  # The values a damaged sign can be, from its surviving strokes alone
  def options(value, lost)
    Cistergraphia::Weathering.candidates(Cistergraphia::Weathering.surviving(value, lost), lost)
  end

  # A value with these places' digits taken out
  def without(value, places)
    value - places.sum { |place| (value / place % 10) * place }
  end

  def digits_at(values, place)
    values.map { |value| value / place % 10 }.uniq.sort
  end

  # A lacuna's pair as the bench first shows it: "1?34 + 6234 = ?", a partner
  # lacuna as open as this one (the page never holds a lost digit)
  def bench_sum(values, entries, lacuna)
    sign = lacuna[:sign]
    first = sign - (sign % 2)
    shown = [first, first + 1].map do |index|
      worn = entries.find { |entry| entry[:sign] == index }
      worn ? open_digits(worn) : format('%04d', values.fetch(index))
    end
    "#{shown.join(' + ')} = ?"
  end

  # A damaged sign's digits as far as they can be seen: '?' in its open places
  def open_digits(lacuna)
    format('%04d', lacuna[:known]).tap do |digits|
      lacuna[:open].each { |place| digits[3 - Math.log10(place).round] = '?' }
    end
  end

  # The bench's first verdict: a null pair (an intact 9999 after a lost first sign) needs no digit
  def bench_verdict(values, lacuna)
    null = lacuna[:sign].even? && values[lacuna[:sign] + 1] == Cistergraphia::EVIL_MARKER
    null ? 'A null pair: any digit.' : 'Press a digit to balance it.'
  end

  # The tallies of a lacuna's row and column, in its place, as the bench first
  # shows them: open, since the lacuna itself is
  def bench_tallies(lacuna)
    "Tallies, #{place_name(lacuna[:place])}: row ?, column ?"
  end

  # The bench's edition before anything is restored, as app.js redraws it:
  # null pairs (an intact 9999) left out, [.] for a pair a lacuna took part
  # of, letters for the rest
  def bench_edition(values, damage)
    values.each_slice(2).with_index.filter_map do |(first, second), pair|
      next if second == Cistergraphia::EVIL_MARKER && !damage.key?((2 * pair) + 1)
      next '[.]' if damage.key?(2 * pair) || damage.key?((2 * pair) + 1)

      Cistergraphia::CHARACTERS[first + second]
    end.join
  end
end

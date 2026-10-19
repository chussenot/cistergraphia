# frozen_string_literal: true

# Whole signs lost on an n x n plate: how many would tally signs restore, a
# row sum at the end of each row and a column sum under each column, as on a
# khipu's higher cords? (Not built yet: this measures whether to build it.)
#
#   ruby experiments/weathering/tally.rb
#
# Restoring is peeling: a row (or column) with exactly one lost sign, its sum
# intact, gives that sign back; that can leave another line with one gap, and
# so on. Pure arithmetic on cell positions, no library needed.

TRIALS = 2000
random = Random.new(1500)

# The lines a cell belongs to: its row, and its column when columns are summed
def lines_of((row, col), columns)
  columns ? [[:row, row], [:col, col]] : [[:row, row]]
end

def restored?(lost, columns:)
  lost = lost.dup
  until lost.empty?
    gaps = lost.flat_map { |cell| lines_of(cell, columns) }.tally
    peelable = lost.select { |cell| lines_of(cell, columns).any? { |line| gaps[line] == 1 } }
    return false if peelable.empty?

    lost -= peelable
  end
  true
end

def cells(size)
  (0...size).to_a.product((0...size).to_a)
end

# k cells around a random centre: a broken corner, not scattered wear
def cluster(size, count, random)
  r0 = random.rand(size)
  c0 = random.rand(size)
  cells(size).sort_by { |r, c| ((r - r0)**2) + ((c - c0)**2) }.first(count)
end

def share(trials)
  format('%<pct>5.1f%%', pct: 100.0 * (1..TRIALS).count { trials.call } / TRIALS)
end

[12, 20].each do |size|
  puts "#{size} x #{size} plate (#{size * size} signs + #{(2 * size) + 1} tally signs), #{TRIALS} trials each"
  [1, 2, 4, 8, 12, 16, 24, 32].each do |count|
    rows = share(-> { restored?(cells(size).sample(count, random: random), columns: false) })
    both = share(-> { restored?(cells(size).sample(count, random: random), columns: true) })
    crack = share(-> { restored?(cluster(size, count, random), columns: true) })
    puts "  #{count.to_s.rjust(2)} signs lost: rows only #{rows}   rows + columns #{both}   " \
         "rows + columns, clustered #{crack}"
  end
end

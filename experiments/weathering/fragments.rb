# frozen_string_literal: true

# Broken plates: do the sums alone rejoin them, and how fast?
#
#   bundle exec ruby experiments/weathering/fragments.rb [PLATES]
#
# For random messages at four plate sizes, breaks each plate as the
# generator does (Cistergraphia::Fragments::Breaking) and counts:
# - how many arrangements the shapes allow (every tiling of the board, each
#   fragment turned or not): what a reader faces without the sums
# - how many of them balance along either keyless layout, on the snail (as
#   the generator draws) and, for comparison, along the rows (Rongorongo)
# - how often a first break rejoins one way only (else the generator draws again)
# - how long the decoder's search takes

require_relative '../../lib/cistergraphia'

PLATES = Integer(ARGV.first || 200)
WORDS = %w[ora et labora the brothers will gather in chapter house after compline abbey vespers
           cloister arches well relics bell matins lauds scriptorium].freeze

Fragments = Cistergraphia::Fragments
random = Random.new(1098)
srand(1098)

def message(letters, random)
  words = []
  words << WORDS.sample(random: random) while words.join(' ').size < letters
  words.join(' ')[0, letters]
end

# [shapes allow, balance on the snail, balance along the rows, seconds] for one broken plate
def measure(sequence, pieces, random)
  snail, rows = %i[phaistos rongorongo].map { |layout| along(layout, sequence, pieces, random) }
  [snail[:shapes], snail[:found], rows[:found], snail[:seconds]]
end

# The plate drawn along a layout and broken: what its fragments allow, and what balances
def along(layout, sequence, pieces, random)
  fragments = Fragments.read(Fragments::Tray.render(sequence, layout, pieces.map(&:dup), random))
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  found = Fragments::Join.all(fragments, Cistergraphia::Layout::KEYLESS).size
  { found: found, seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
    shapes: Fragments::Join.tilings(fragments, Integer.sqrt(sequence.size)).size * (2**fragments.size) }
end

def share(count, total) = format('%<pct>5.1f%%', pct: 100.0 * count / total)

puts "#{PLATES} plates per size, seed 1098"
puts 'side  letters  pieces 2/3/4   arrangements (median, max)  ' \
     'one way on the snail   along the rows: one way   search (mean, max)'
[[4, 7], [8, 30], [14, 95], [32, 500]].each do |side, letters|
  rows = Array.new(PLATES) do
    sequence = Cistergraphia.encode(message(letters, random))
    pieces = Fragments::Breaking.cut(Integer.sqrt(sequence.size), random)
    [pieces.size, *measure(sequence, pieces, random)]
  end
  pieces = rows.map(&:first).tally
  shapes = rows.map { |row| row[1] }.sort
  times = rows.map(&:last)
  puts format('%<side>4d  %<letters>7d  %<two>4d/%<three>d/%<four>d   %<median>12d, %<max>5d        ' \
              '%<snail>s               %<rows>s                 %<mean>.3fs, %<slowest>.3fs',
              side: side, letters: letters, two: pieces.fetch(2, 0), three: pieces.fetch(3, 0),
              four: pieces.fetch(4, 0), median: shapes[shapes.size / 2], max: shapes.last,
              snail: share(rows.count { |row| row[2] == 1 }, PLATES),
              rows: share(rows.count { |row| row[3] == 1 }, PLATES),
              mean: times.sum / times.size, slowest: times.max)
end

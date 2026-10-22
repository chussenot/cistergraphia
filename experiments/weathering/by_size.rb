# frozen_string_literal: true

# Worn plates by size: how thin is a small one, and would a heavier share of
# damage on small plates help? The first measured playtest a script can do
# (a reader's time cannot be measured here: see docs/playtest.md).
#
#   bundle exec ruby experiments/weathering/by_size.rb [PLATES]
#
# For each plate side, PLATES random messages are weathered as the generator
# does (Weathering.weather): how many lacunae, how many of them the balance
# alone restores, how many leave a doubt for the words, and how many plates
# are a lesson rather than a puzzle (no doubt at all, or one lacuna): one pair
# in two on a small plate, one in three above. Then the small sides with one
# pair in three throughout, as the generator laid it before the scaling.

require_relative '../../lib/cistergraphia'

W = Cistergraphia::Weathering
PLATES = Integer(ARGV.first || 200)
WORDS = %w[ora et labora the brothers will gather in chapter house after compline abbey vespers
           cloister arches well relics bell matins lauds scriptorium meet me at dawn by old gate].freeze
SIDES = [4, 6, 8, 10, 14].freeze
random = Random.new(1098)

# A game message whose plate has this side
def message_for(side, random)
  letters = (side * side / 2) - 1
  loop do
    message = Array.new(letters) { WORDS.sample(random: random) }.join(' ')[0, letters].strip
    return message if Integer.sqrt(Cistergraphia.encode(message).size) == side
  end
end

# Letters a lacuna's pair can balance as
def letters(sequence, index, lost)
  W.outcomes(sequence, index - (index % 2), { index => lost }).size
end

# [lacunae, doubts, letters in doubt (sum over doubts)] for one plate's damage
def measure(sequence, damage)
  widths = damage.map { |index, lost| letters(sequence, index, lost) }
  [damage.size, widths.count { |n| n > 1 }, widths.select { |n| n > 1 }.sum]
end

def share(count, total) = format('%<pct>5.1f%%', pct: 100.0 * count / total)

HEADING = 'side  pairs  lacunae  one in  restored by balance  doubts/plate   no doubt (a lesson)   one lacuna or none'
ROW = '%<side>4d  %<pairs>5d  %<lacunae>7.1f  %<one_in>7.1f  %<restored>s   %<doubts>7.2f   %<no_doubt>s   %<thin>s'

# The table for these sides, PLATES plates each
run = lambda do |sides|
  puts HEADING
  sides.each do |side|
    rows = Array.new(PLATES) do
      sequence = Cistergraphia.encode(message_for(side, random))
      measure(sequence, W.weather(sequence, random: random))
    end
    pairs = side * side / 2
    lacunae = rows.sum(&:first)
    doubts = rows.sum { |row| row[1] }
    puts format(ROW, side: side, pairs: pairs, lacunae: lacunae.fdiv(PLATES), one_in: pairs * PLATES.fdiv(lacunae),
                     restored: share(lacunae - doubts, lacunae), doubts: doubts.fdiv(PLATES),
                     no_doubt: share(rows.count { |row| row[1].zero? }, PLATES),
                     thin: share(rows.count { |row| row[0] <= 1 }, PLATES))
  end
end

puts "#{PLATES} plates per side, seed 1098"
puts "\n1. As the generator lays it: one pair in #{W::SHARE} (one in #{W::SMALL_SHARE} under #{W::SMALL_PLATE} pairs)"
run.call(SIDES)

puts "\n2. The small plates with one pair in #{W::SHARE} throughout, as before the scaling"
W.send(:remove_const, :SMALL_SHARE)
W.const_set(:SMALL_SHARE, W::SHARE)
run.call(SIDES.take(2))

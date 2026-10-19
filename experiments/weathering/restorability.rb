# frozen_string_literal: true

# How much damage does the pair checksum repair? Monte Carlo on real game
# plates, with the library's own restorer (Cistergraphia::Weathering).
#
#   bundle exec ruby experiments/weathering/restorability.rb [TRIALS]
#
# Part 1 damages signs at random and counts the letters that still balance:
# "restored" means exactly one. Part 2 reports what the generator lays on
# purpose (Lacunae.inscribe): how many lacunae, and how many leave a doubt.

require_relative '../../lib/cistergraphia'

W = Cistergraphia::Weathering
TRIALS = Integer(ARGV.fetch(0, 3000))
MESSAGES = File.readlines(File.join(__dir__, '../cryptanalysis/messages.txt'), chomp: true).reject(&:empty?)
PLACES = W::POSITIONS.keys
random = Random.new(1098)

def report(name, counts)
  restored = 100.0 * counts.count(1) / counts.size
  mean = counts.sum.to_f / counts.size
  puts "  #{name.ljust(44)} restored #{format('%<pct>5.1f', pct: restored)}%  " \
       "letters that balance: mean #{format('%<mean>.2f', mean: mean)}, max #{counts.max}"
end

# Letters a pair can balance as, once these lacunae are laid on it
def letters(sequence, damage)
  start = damage.keys.min - (damage.keys.min % 2)
  W.outcomes(sequence, start, damage).size
end

damage_kinds = {
  'one quadrant lost' => ->(r) { [[r.rand(2), W::POSITIONS.fetch(PLACES.sample(random: r))]] },
  **PLACES.to_h { |place| ["  ...the #{place}s quadrant", ->(r) { [[r.rand(2), W::POSITIONS.fetch(place)]] }] },
  **(1..3).to_h do |k|
    ["#{k} of 5 stroke positions lost", lambda { |r|
      [[r.rand(2), W::POSITIONS.fetch(PLACES.sample(random: r)).sample(k, random: r)]]
    }]
  end,
  'two quadrants of one sign lost' => lambda { |r|
    [[r.rand(2), PLACES.sample(2, random: r).flat_map do |p|
      W::POSITIONS.fetch(p)
    end]]
  },
  'a quadrant lost in each sign of a pair' => lambda { |r|
    [0, 1].map do |side|
      [side, W::POSITIONS.fetch(PLACES.sample(random: r))]
    end
  },
  'whole sign lost (all four quadrants)' => ->(r) { [[r.rand(2), W::POSITIONS.values.flatten(1)]] }
}

puts "1. Random damage, #{TRIALS} sites per row (messages.txt, game plates)"
damage_kinds.each do |name, lay|
  counts = Array.new(TRIALS) do
    sequence = Cistergraphia.encode(MESSAGES.sample(random: random))
    start = 2 * random.rand(sequence.size / 2)
    damage = lay.call(random).to_h { |side, lost| [start + side, lost] }
    letters(sequence, damage)
  end
  report(name, counts)
end

puts "\n2. What the generator lays (Lacunae.inscribe), #{TRIALS / 10} plates"
lacunae = doubts = pairs = 0
widths = Hash.new(0)
(TRIALS / 10).times do
  sequence, _, damage = Cistergraphia::Lacunae.inscribe(MESSAGES.sample(random: random), random: random)
  pairs += sequence.size / 2
  damage.each_key do |index|
    n = letters(sequence, { index => damage[index] })
    lacunae += 1
    doubts += 1 if n > 1
    widths[n] += 1
  end
end
puts "  #{lacunae} lacunae on #{pairs} pairs (one pair in #{(pairs.to_f / lacunae).round(1)})"
puts "  restored by the balance alone: #{(100.0 * (lacunae - doubts) / lacunae).round(1)}%; " \
     "left to the words: #{(100.0 * doubts / lacunae).round(1)}%"
puts "  letters that balance, per lacuna: #{widths.sort.map { |n, c| "#{n}: #{c}" }.join(', ')}"

puts "\n3. With tally signs (Lacunae.inscribe tally: true), #{TRIALS / 20} plates"
lacunae = wholes = pairs = settled = 0
(TRIALS / 20).times do
  sequence, svg, damage = Cistergraphia::Lacunae.inscribe(MESSAGES.sample(random: random), tally: true, random: random)
  pairs += sequence.size / 2
  lacunae += damage.size
  wholes += damage.count { |_, lost| lost.size == W::POSITIONS.values.flatten(1).size }
  settled += 1 unless Cistergraphia.decode(svg).include?('/')
end
puts "  #{lacunae} lacunae on #{pairs} pairs (one pair in #{(pairs.to_f / lacunae).round(1)}), " \
     "#{wholes} of them whole signs (#{(100.0 * wholes / lacunae).round(1)}%)"
puts "  editions with no doubt left: #{settled} of #{TRIALS / 20}"

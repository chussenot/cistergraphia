# frozen_string_literal: true

# Line coverage of the library, the web helpers and the app under the Ruby
# suite, with Ruby's own Coverage module (no gem), and a floor:
#   bundle exec rake test:coverage      (COVERAGE_FLOOR=97 by default)
# The floor is not a target to chase but a tripwire: it fails when a change
# arrives without its test. Prints one line per file and the total; writes the
# total to the CI job summary when there is one.

require 'coverage'

ROOT = File.expand_path('..', __dir__)
FLOOR = Float(ENV.fetch('COVERAGE_FLOOR', '97'))
MEASURED = ['lib', 'web', 'app.rb'].map { |path| File.join(ROOT, path) }.freeze

Coverage.start(lines: true)
$LOAD_PATH.unshift File.join(ROOT, 'test')
Dir[File.join(ROOT, 'test', '*_test.rb')].each { |file| require file }

def covered(lines)
  known = lines.compact
  [known.count(&:positive?), known.size]
end

def report(rows)
  rows.each do |path, (hit, known)|
    puts format('%<file>-40s %<share>5.1f%%  (%<hit>d/%<known>d)',
                file: path.delete_prefix("#{ROOT}/"), share: 100.0 * hit / [known, 1].max, hit: hit, known: known)
  end
end

def summarise(line)
  puts line
  File.open(ENV.fetch('GITHUB_STEP_SUMMARY'), 'a') { |f| f.puts(line) } if ENV['GITHUB_STEP_SUMMARY']
end

Minitest.after_run do
  rows = Coverage.result.select { |path, _| MEASURED.any? { |root| path.start_with?(root) } }
                 .sort.to_h { |path, data| [path, covered(data[:lines])] }
  report(rows)
  hit, known = rows.values.transpose.map(&:sum)
  total = 100.0 * hit / known
  summarise(format('Coverage %<total>.1f%% of %<known>d lines in lib, web and app.rb (floor %<floor>.0f%%)',
                   total: total, known: known, floor: FLOOR))
  exit(1) if total < FLOOR
end

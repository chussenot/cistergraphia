# frozen_string_literal: true

# The behaviour suite (run: bundle exec rake ui:play): the reader who does the
# work gets the message. Boots the app, writes one plate per rung with the
# answers the page must never hold (the worn plate's values, where each
# fragment of the broken plate goes), and runs test/ui/play.js against it: the
# desk, the bench, the board, Lectio, the record, the preview, the grille,
# the sounds, accessibility and the budgets.
#
# Needs Node, Playwright and axe-core (see test/ui/harness.rb):
#   npm install --no-save playwright axe-core && npx playwright install chromium
# BROWSER=firefox|webkit runs it in another engine (installed the same way).

require 'json'
require_relative 'harness'

MESSAGE = 'Meet me at the old abbey after vespers'

UiHarness.require_node_modules('playwright', 'axe-core')

# Where each fragment of a broken plate goes ([index, row, col, turned], in
# file order): the one rejoining whose pairs all balance, as the decoder finds it
def rejoining(svg)
  fragments = Cistergraphia::Fragments.read(svg)
  Cistergraphia::Fragments::Join.all(fragments, Cistergraphia::Layout::KEYLESS).first.places
end

# Whether a pair reads along a way: both signs read, and they add to a letter (or the second is the null mark)
def reads?(first, second)
  return false if first.nil? || second.nil?

  second == Cistergraphia::EVIL_MARKER || Cistergraphia::CHARACTERS.key?(first + second)
end

# way => the first pair (1-based) that does not read along it, nil where every pair does
def breaks(svg)
  grid = Cistergraphia::Pathless.grid(svg).to_h { |row, col, upright, turned| [[row, col], [upright, turned]] }
  side = Integer.sqrt(grid.size)
  Cistergraphia::Layout::KEYLESS.to_h do |way|
    values = Cistergraphia::Layout.path(side, way).map { |row, col, turned| grid[[row, col]][turned ? 1 : 0] }
    broke = values.each_slice(2).find_index { |first, second| !reads?(first, second) }
    [way, broke.nil? ? nil : broke + 1]
  end
end

Dir.mktmpdir do |dir|
  answers = { message: Cistergraphia.normalize(MESSAGE) }
  File.write(File.join(dir, 'intact.svg'), Cistergraphia.inscribe(MESSAGE).last)
  File.write(File.join(dir, 'rongorongo.svg'), Cistergraphia.inscribe(MESSAGE, layout: :rongorongo).last)
  values, worn, = Cistergraphia::Lacunae.inscribe(MESSAGE, random: Random.new(5))
  File.write(File.join(dir, 'worn.svg'), worn)
  answers[:worn] = values
  _, broken, = Cistergraphia::Fragments.inscribe(MESSAGE, random: Random.new(3))
  File.write(File.join(dir, 'broken.svg'), broken)
  answers[:broken] = rejoining(broken)
  # A pathless plate along the leap (the splits drawn from a fixed seed), with
  # where each way breaks: the first pair that does not read along it
  srand(11)
  _, pathless = Cistergraphia.inscribe(MESSAGE, layout: :leap, pathless: true)
  File.write(File.join(dir, 'pathless.svg'), pathless)
  answers[:pathless] = { way: 'leap', breaks: breaks(pathless) }
  File.write(File.join(dir, 'answers.json'), JSON.generate(answers))

  ok = UiHarness.serve(dir) { |base_url| UiHarness.run_script('play.js', base_url, dir) }
  exit(ok ? 0 : 1)
end

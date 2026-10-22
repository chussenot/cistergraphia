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
  File.write(File.join(dir, 'answers.json'), JSON.generate(answers))

  ok = UiHarness.serve(dir) { |base_url| UiHarness.run_script('play.js', base_url, dir) }
  exit(ok ? 0 : 1)
end

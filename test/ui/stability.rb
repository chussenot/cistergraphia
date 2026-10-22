# frozen_string_literal: true

# Layout stability check (run: bundle exec rake ui:stability): boots the app on
# a free port, writes a plate to upload, and runs test/ui/stability.js against
# it. Exits non-zero if anything on a page moves under the reader.
#
# Needs Node and Playwright with its Chromium (see test/ui/harness.rb).

require_relative 'harness'

MESSAGE = 'Meet me at the old abbey after vespers, under the cloister arches by the well'

UiHarness.require_node_modules('playwright')

Dir.mktmpdir do |dir|
  # A long name: the read page must cut it, not wrap it
  plate = File.join(dir, 'a-plate-with-a-rather-long-name-from-the-abbey-of-citeaux.svg')
  File.write(plate, Cistergraphia.inscribe('ora et labora', layout: :rongorongo).last)
  # The same weathered plate for every run (its edition's length depends on its lacunae)
  File.write(plate.sub(/\.svg\z/, '-weathered.svg'), Cistergraphia::Lacunae.inscribe(MESSAGE)[1])
  # And the same broken plate: brought to Read, it opens as the board
  File.write(plate.sub(/\.svg\z/, '-broken.svg'), Cistergraphia::Fragments.inscribe(MESSAGE, random: Random.new(3))[1])
  # And the same ruined plate: the board, then (rejoined=1) the bench on the plate rejoined
  File.write(plate.sub(/\.svg\z/, '-ruined.svg'),
             Cistergraphia::Fragments.inscribe(MESSAGE, weathered: true, random: Random.new(3))[1])
  # And one with tally signs (the library's and the CLI's, not the form's): the bench checks them
  File.write(plate.sub(/\.svg\z/, '-tallied.svg'), Cistergraphia::Lacunae.inscribe(MESSAGE, tally: true)[1])

  ok = UiHarness.serve(dir) { |base_url| UiHarness.run_script('stability.js', base_url, plate) }
  exit(ok ? 0 : 1)
end

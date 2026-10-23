# frozen_string_literal: true

# The end-to-end suite (run: bundle exec rake ui:e2e): every choice the form
# offers, written as a person writes it, and the plate it makes followed to
# its reader. Boots the app and runs test/ui/e2e.js against it: each plate
# must be drawn whole on its page (every stroke inked, every lacuna hatched),
# each refusal must say why with the message kept, and each file must open on
# Read as its puzzle and decipher back to the message.
#
# Needs Node and Playwright (see test/ui/harness.rb). BROWSER=firefox|webkit
# runs it in another engine; E2E_ONLY=worn (a word of the case names) runs a part.

require 'tmpdir'
require_relative 'harness'

UiHarness.require_node_modules('playwright')

Dir.mktmpdir do |dir|
  ok = UiHarness.serve(dir) { |base_url| UiHarness.run_script('e2e.js', base_url, dir) }
  exit(ok ? 0 : 1)
end

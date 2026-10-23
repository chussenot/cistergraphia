# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
end

task default: :test

namespace :test do
  desc 'The sounds of silence: the pure part of public/js/sound.js (needs Node)'
  task :sound do
    sh 'node', '--test', 'test/sound_test.js'
  end

  desc 'The Ruby suite under Coverage, with a floor (COVERAGE_FLOOR=97): lib, web and app.rb'
  task :coverage do
    ruby 'test/coverage.rb'
  end
end

desc 'Everything that runs locally in minutes: the suite with coverage, the Node tests, rubocop'
task quality: ['test:coverage', 'test:sound'] do
  sh 'bundle', 'exec', 'rubocop'
  puts "\nFor a change to the pages, also: bundle exec rake ui:stability (nothing moves) " \
       'and bundle exec rake ui:play (the reader gets the message). See docs/quality.md.'
end

namespace :og do
  desc 'Render the social preview images (public/og.png, docs/social-preview.png); needs Chromium'
  task :image do
    ruby 'web/og/render.rb'
  end
end

namespace :ui do
  desc 'Check that nothing on a page moves under the reader (needs Node, Playwright and Chromium)'
  task :stability do
    ruby 'test/ui/stability.rb'
  end

  desc 'The behaviour suite: the reader who does the work gets the message (needs Node, Playwright, axe-core)'
  task :play do
    ruby 'test/ui/play.rb'
  end

  desc 'End to end: every choice of the form, its plate drawn whole, read back on Read (needs Node, Playwright)'
  task :e2e do
    ruby 'test/ui/e2e.rb'
  end
end

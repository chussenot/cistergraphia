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

# The day's chapter's content checks (docs/operations.md). Slow (a minute and
# a half): CI runs them on a change to the chapter, and every Monday
namespace :chapter do
  def chapter_loaded
    require_relative 'lib/cistergraphia'
    require_relative 'web/plate_file'
    require_relative 'web/chapter'
  end

  desc "Every text of the day's chapter under every rung, then the next DAYS days (90), drawn and read back"
  task :check, [:days] do |_task, args|
    chapter_loaded
    troubles = Chapter::Check.check(days: Integer(args[:days] || 90))
    troubles.each { |trouble| warn trouble }
    abort "#{troubles.size} chapter(s) would not read" unless troubles.empty?
    puts "Every text reads under every rung, and the next #{args[:days] || 90} days are set."
  end

  desc 'Days of new readings left before the order starts again; fails under RUNWAY (14)'
  task :runway do
    chapter_loaded
    left = Chapter.runway
    floor = Integer(ENV.fetch('RUNWAY', 14))
    puts "#{Chapter::READINGS.size} readings; #{left} days of new readings left after today."
    abort "Under #{floor} days: append readings to web/chapters.yml (docs/operations.md)" if left < floor
  end
end

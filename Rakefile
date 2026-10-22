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
end

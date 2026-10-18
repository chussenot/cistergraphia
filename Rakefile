# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
end

task default: :test

namespace :og do
  desc 'Render the social preview images (public/og.png, docs/social-preview.png); needs Chromium'
  task :image do
    ruby 'web/og/render.rb'
  end
end

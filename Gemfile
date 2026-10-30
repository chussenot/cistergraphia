# frozen_string_literal: true

source 'https://rubygems.org'

gem 'erubi' # ERB engine with HTML auto-escaping (escape_html: true)
gem 'json', '>= 2.19.2' # The notebook's answers; below 2.19.2, CVE-2026-33210 (the image's base ships 2.18.0)
gem 'puma'
gem 'rack', '~> 3.2'
gem 'rackup', '~> 2.3'
gem 'rexml' # Pure-Ruby XML parser, only used to decode SVGs
gem 'sinatra', '~> 4.2'

group :development do
  gem 'rubocop', require: false
  gem 'sinatra-contrib' # Sinatra::Reloader for automatic reloading
end

group :test do
  gem 'minitest'
  gem 'rack-test'
  gem 'rake'
end

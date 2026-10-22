# frozen_string_literal: true

# Layout stability check (run: bundle exec rake ui:stability): boots the app on
# a free port, writes a plate to upload, and runs test/ui/stability.js against
# it. Exits non-zero if anything on a page moves under the reader.
#
# Needs Node and Playwright with its Chromium:
#   npm install --no-save playwright && npx playwright install chromium
# CHROME=/path/to/chrome uses another Chromium; BASE_URL=http://... checks a
# server that is already running instead of booting one.

require 'net/http'
require 'socket'
require 'tmpdir'
require_relative '../../lib/cistergraphia'

ROOT = File.expand_path('../..', __dir__)
MESSAGE = 'Meet me at the old abbey after vespers, under the cloister arches by the well'

def free_port
  server = TCPServer.new('127.0.0.1', 0)
  server.addr[1]
ensure
  server&.close
end

def up?(url)
  Net::HTTP.get_response(URI(url)).is_a?(Net::HTTPSuccess)
rescue SystemCallError, IOError
  false
end

# Until the app answers; fails fast, with its log, if it dies or never answers
def wait_for(url, pid, log, timeout: 30)
  deadline = Time.now + timeout
  until up?(url)
    gone = Process.wait(pid, Process::WNOHANG)
    abort "The app did not start at #{url}:\n#{File.read(log)}" if gone || Time.now > deadline
    sleep 0.2
  end
end

# Node finds Playwright in ./node_modules, or among the global modules
def node_env
  paths = [ENV.fetch('NODE_PATH', nil), `npm root -g 2>#{File::NULL}`.strip].reject { |path| path.to_s.empty? }
  { 'NODE_PATH' => paths.join(File::PATH_SEPARATOR) }
end

def playwright?
  system(node_env, 'node', '-e', "require('playwright')", chdir: ROOT, out: File::NULL, err: File::NULL)
end

def check(base_url, plate)
  system(node_env, 'node', File.join(__dir__, 'stability.js'), base_url, plate, *ENV.fetch('CHROME', nil), chdir: ROOT)
end

# The app in production mode (as deployed: templates compiled once) on a free port
def start_server(port, log)
  Process.spawn({ 'RACK_ENV' => 'production' }, 'bundle', 'exec', 'puma', '-b', "tcp://127.0.0.1:#{port}",
                'config.ru', chdir: ROOT, out: log, err: log)
end

def serve(dir)
  base_url = "http://127.0.0.1:#{free_port}"
  log = File.join(dir, 'server.log')
  pid = start_server(URI(base_url).port, log)
  wait_for(base_url, pid, log)
  yield base_url
ensure
  stop(pid)
end

def stop(pid)
  return unless pid

  Process.kill('TERM', pid)
  Process.wait(pid)
rescue Errno::ESRCH, Errno::ECHILD
  nil # already gone
end

unless playwright?
  abort 'Playwright not found. Install it with: npm install --no-save playwright && npx playwright install chromium'
end

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

  ok = if ENV['BASE_URL']
         check(ENV.fetch('BASE_URL'), plate)
       else
         serve(dir) { |base_url| check(base_url, plate) }
       end
  exit(ok ? 0 : 1)
end

# frozen_string_literal: true

# What the browser suites share (test/ui/stability.rb, test/ui/play.rb): the
# app booted in production mode on a free port, and Node with Playwright found.
#
# Needs Node and Playwright with its Chromium:
#   npm install --no-save playwright && npx playwright install chromium
# CHROME=/path/to/chrome uses another Chromium; BASE_URL=http://... checks a
# server that is already running instead of booting one.

require 'net/http'
require 'socket'
require 'tmpdir'
require_relative '../../lib/cistergraphia'

module UiHarness
  ROOT = File.expand_path('../..', __dir__)

  module_function

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

  def node_module?(name)
    system(node_env, 'node', '-e', "require('#{name}')", chdir: ROOT, out: File::NULL, err: File::NULL)
  end

  def require_node_modules(*names)
    missing = names.reject { |name| node_module?(name) }
    return if missing.empty?

    abort "Node modules not found: #{missing.join(', ')}. Install them with: " \
          "npm install --no-save #{missing.join(' ')} && npx playwright install chromium"
  end

  # The script run against the app, with the Chromium CHROME names if any
  def run_script(script, base_url, *)
    system(node_env, 'node', File.join(__dir__, script), base_url, *, *ENV.fetch('CHROME', nil), chdir: ROOT)
  end

  # The app in production mode (as deployed: templates compiled once) on a free port
  def start_server(port, log)
    Process.spawn({ 'RACK_ENV' => 'production' }, 'bundle', 'exec', 'puma', '-b', "tcp://127.0.0.1:#{port}",
                  'config.ru', chdir: ROOT, out: log, err: log)
  end

  # The app served for the block, or (BASE_URL) one already running
  def serve(dir)
    return yield ENV.fetch('BASE_URL') if ENV['BASE_URL']

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
end

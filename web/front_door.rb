# frozen_string_literal: true

# The front door's key (infra/cloudflare.tf, docs/serving.md): served behind
# Cloudflare, the app answers only requests that come through it. The Worker
# adds a header with a key the service holds in a secret; a request without
# it, at the service's own run.app address, is refused before anything of it
# is read. Without a key in the environment (no domain, a laptop, the suites)
# every door is open.
#
# Constraints:
# - /up stays open: Cloud Run's probes come from inside, without the key
# - The comparison takes the same time whatever the key: no letter is leaked
#   by how fast a wrong one is refused
class FrontDoor
  HEADER = 'HTTP_X_FRONT_DOOR_KEY'
  OPEN = ['/up'].freeze
  REFUSED = [403, { 'content-type' => 'text/plain; charset=utf-8', 'cache-control' => 'no-store' },
             ["Not through the front door.\n"]].freeze

  def initialize(app, key = ENV.fetch('FRONT_DOOR_KEY', nil))
    @app = app
    @key = key.to_s.empty? ? nil : key
  end

  def call(env)
    return @app.call(env) if @key.nil? || OPEN.include?(env['PATH_INFO'])

    given = env[HEADER].to_s
    return REFUSED unless given.bytesize == @key.bytesize && Rack::Utils.secure_compare(given, @key)

    @app.call(env)
  end
end

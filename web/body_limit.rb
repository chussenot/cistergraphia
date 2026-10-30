# frozen_string_literal: true

# No request body larger than a plate can be (docs/serving.md). The app
# refuses a plate over MAX_SVG_BYTES, but only once Rack has read and parsed
# the whole form; this refuses it by its Content-Length first, before a byte
# of it is parsed, as the server's own limit (Cloud Run allows 32 MB) is far
# above what any plate needs.
#
# Constraints:
# - A body with no Content-Length (chunked) passes: the app's limit still
#   holds; only the early refusal is lost
class BodyLimit
  REFUSED = [413, { 'content-type' => 'text/plain; charset=utf-8', 'cache-control' => 'no-store' },
             ["The request is larger than any plate.\n"]].freeze

  def initialize(app, limit)
    @app = app
    @limit = limit
  end

  def call(env)
    length = env['CONTENT_LENGTH'].to_i
    return REFUSED if length > @limit

    @app.call(env)
  end
end

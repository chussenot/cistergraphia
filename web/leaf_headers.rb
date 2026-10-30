# frozen_string_literal: true

# What every leaf is sent with (app.rb, before each request): the headers
# that keep a reader's browser to the site's own scripts and styles, to no
# referrer, to HTTPS once it has seen it; and how long a page may be kept.
# Mixed into the app's routes.
module LeafHeaders
  LEAVES = %w[/ /decode /about].freeze # the same for every reader: a front door may keep them a while
  LEAF_MAX_AGE = 300
  STRICT_TRANSPORT = 'max-age=31536000; includeSubDomains' # once over HTTPS, always: a passphrase is in the request

  private

  def leaf_headers
    headers 'Content-Security-Policy' => CistergraphiaApp::CONTENT_SECURITY_POLICY,
            'Referrer-Policy' => 'no-referrer',
            'X-Content-Type-Options' => 'nosniff',
            'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()'
    headers 'Strict-Transport-Security' => STRICT_TRANSPORT if request.ssl?
    cache_control :no_store if request.post? # a message or a passphrase is in it
    cache_control :public, max_age: LEAF_MAX_AGE if LEAVES.include?(request.path_info)
  end
end

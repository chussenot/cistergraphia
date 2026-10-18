# frozen_string_literal: true

# Cistergraphia Web Application
# ============================
#
# Purpose:
# - Provides a web interface for the Cistergraphia cipher system
# - Handles message encryption (SVG generation) and decryption (SVG upload)
# - Game mode without a passphrase, secret mode (AES-256-GCM) with one
#
# Design Decisions:
# - Modular Sinatra app (sinatra/base), no classic top-level DSL
# - Cipher and SVG rendering live in lib/, shared with the CLI
# - ERB output is HTML-escaped by default; raw output must use <%== %>
# - All CSS, JS and fonts are first-party static files (public/), so a strict
#   Content-Security-Policy applies and no third party sees who uses the app
# - Responses carrying a message or passphrase are never cached
# - The UI design is documented in docs/design.md
#
# Constraints:
# - Characters missing from the cipher table are treated as separators
# - Output is always a perfect square grid
# - SVG dimensions based on content size

require 'sinatra/base'
require_relative 'lib/cistergraphia'
require_relative 'web/view_helpers'

class CistergraphiaApp < Sinatra::Base
  MAX_MESSAGE_LENGTH = 500 # ~1000 symbols, a 32x32 grid
  MAX_SVG_BYTES = 1024 * 1024 # The SVG of a MAX_MESSAGE_LENGTH message is well below this
  CONTENT_SECURITY_POLICY = [
    "default-src 'self'", "img-src 'self' data: blob:", "object-src 'none'", "base-uri 'none'",
    "form-action 'self'", "frame-ancestors 'none'"
  ].join('; ')

  helpers ViewHelpers

  configure do
    set :root, __dir__
    set :erb, escape_html: true
    set :static_cache_control, [:public, { max_age: 3600 }]
    enable :logging
  end

  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
    also_reload File.join(__dir__, 'lib/**/*.rb')
    also_reload File.join(__dir__, 'web/**/*.rb')
  end

  before do
    headers 'Content-Security-Policy' => CONTENT_SECURITY_POLICY,
            'Referrer-Policy' => 'no-referrer',
            'X-Content-Type-Options' => 'nosniff',
            'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()'
    cache_control :no_store if request.post?
  end

  error Cistergraphia::Error do
    status 400
    @error_message = env['sinatra.error'].message
    erb :error
  end

  # Never echo internal exception details back to the browser
  error do
    @error_message = 'Something unexpected happened, please try again.'
    erb :error
  end

  not_found do
    @error_message = 'This page is not in the index.'
    erb :error
  end

  get '/' do
    @page = :inscribe
    erb :index
  end

  post '/generate' do
    @page = :inscribe
    @message = params[:message].to_s
    halt_with 413, "Message is limited to #{MAX_MESSAGE_LENGTH} characters" if @message.length > MAX_MESSAGE_LENGTH

    @secret = !passphrase.nil?
    sequence = Cistergraphia.encode(@message, passphrase: passphrase)
    @svg_content = Cistergraphia.to_svg(sequence)
    @sequence = sequence
    @symbols = sequence.size
    @normalized = Cistergraphia.normalize(@message)
    erb :result
  end

  get '/decode' do
    @page = :read
    erb :decode
  end

  get '/about' do
    @page = :about
    @title = 'About the ciphers'
    @description = 'The ciphers of the Cistercian monks: their history, how to read a sign, ' \
                   'and the tablet behind Cistergraphia.'
    erb :about
  end

  post '/decode' do
    @page = :read
    @message = Cistergraphia.decode(submitted_svg, passphrase: passphrase)
    @secret = !passphrase.nil?
    erb :decoded
  rescue Cistergraphia::DecodeError => e
    raise if passphrase

    raise Cistergraphia::DecodeError, "#{e.message}. If this image was made in secret mode, enter its passphrase."
  end

  private

  # The mode switch wins when present; otherwise a non-blank passphrase means secret mode
  def passphrase
    return nil if params[:mode] == 'game'

    value = params[:passphrase].to_s
    return value unless value.empty?
    raise Cistergraphia::Error, 'Secret mode needs a passphrase' if params[:mode] == 'secret'

    nil
  end

  # SVG from the file upload when one was chosen, otherwise from the textarea
  def submitted_svg
    svg = uploaded_svg.to_s
    svg = params[:svg].to_s if svg.empty?
    halt_with 413, "SVG is limited to #{MAX_SVG_BYTES / 1024} KB" if svg.bytesize > MAX_SVG_BYTES
    svg
  end

  # Reads one byte past the limit so oversized uploads are detected without loading them whole
  def uploaded_svg
    upload = params[:file]
    upload[:tempfile].read(MAX_SVG_BYTES + 1) if upload.is_a?(Hash) && upload[:tempfile]
  end

  def halt_with(status, message)
    @error_message = message
    halt status, erb(:error)
  end
end

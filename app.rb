# frozen_string_literal: true

# Cistergraphia Web Application
# ============================
#
# Purpose:
# - Provides a web interface for the Cistergraphia cipher system
# - Handles message encryption (SVG generation) and decryption (SVG upload)
# - Game mode without a passphrase, secret mode (AES-256-GCM) with one
# - Three layouts (reading paths): Phaistos (the snail, default), Rongorongo,
#   or a turning Grille with its key (a new one unless one is given); decoding
#   detects the first two, and a grille's plate asks for its key
# - A game plate can be weathered (some strokes lost); decoding one restores
#   what the pairs decide, as an edition in the Leiden conventions
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
require_relative 'web/bench_helpers'
require_relative 'web/form_params'
require_relative 'web/figures'

class CistergraphiaApp < Sinatra::Base
  MAX_MESSAGE_LENGTH = 500 # ~1000 symbols, a 32x32 grid
  MAX_PAIR_LENGTH = 250 # each message of a plate with two readers: the largest, sealed, is ~1.4 MB
  MAX_SVG_BYTES = 2 * 1024 * 1024 # The largest plate (500 four-byte characters, sealed) is ~1.4 MB
  CONTENT_SECURITY_POLICY = [
    "default-src 'self'", "img-src 'self' data: blob:", "object-src 'none'", "base-uri 'none'",
    "form-action 'self'", "frame-ancestors 'none'"
  ].join('; ')

  helpers ViewHelpers, BenchHelpers, Figures, FormParams

  configure do
    set :root, __dir__
    set :erb, escape_html: true
    set :static_cache_control, [:public, { max_age: 3600 }]
    # The app's error pages, in every environment: Sinatra would otherwise show
    # its backtrace page in development for what is only a reader's mistake
    # (Cistergraphia::Error). Backtraces of real bugs still go to the log.
    set :show_exceptions, :after_handler
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
    @layout = chosen_layout
    # A passphrase that cannot seal, or a grille key that is not one: back to
    # the form, with what was written
    @passphrase_error = Cistergraphia::Secret.passphrase_problem(passphrase) if @secret
    @decoy = decoy
    @weathered = weathered?
    @tally = tally?
    halt 422, erb(:index) if [@passphrase_error, @grille_error, @decoy_error, @weathered_error, @tally_error].any?
    @sequence, @svg_content, grille = inscribe_plate
    @layout = grille.as(:pair) if @decoy
    @symbols = @sequence.size
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
    reading = read_plate
    @message, @decoy, @reader = reading.to_a
    @secret = !passphrase.nil?
    erb :decoded
  rescue Cistergraphia::GrilleKeyNeededError => e
    raise Cistergraphia::DecodeError, "#{e.message}. Enter it under “Grille key”, with the passphrase if it was sealed."
  rescue Cistergraphia::DecodeError => e
    raise if passphrase || submitted_grille

    raise Cistergraphia::DecodeError, "#{e.message}. If this image was made in secret mode, enter its passphrase."
  end

  private

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

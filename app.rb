# frozen_string_literal: true

# Cistergraphia Web Application
# ============================
#
# Purpose:
# - Provides a web interface for the Cistergraphia cipher system
# - Handles message encryption (SVG generation) and decryption (SVG upload)
#
# Design Decisions:
# - Modular Sinatra app (sinatra/base), no classic top-level DSL
# - Cipher and SVG rendering live in lib/, shared with the CLI
# - ERB output is HTML-escaped by default; raw output must use <%== %>
# - Development mode with auto-reloading
#
# Constraints:
# - Characters missing from the cipher table are treated as separators
# - Output is always a perfect square grid
# - SVG dimensions based on content size

require 'sinatra/base'
require_relative 'lib/cistergraphia'

class CistergraphiaApp < Sinatra::Base
  MAX_MESSAGE_LENGTH = 500 # ~1000 symbols, a 32x32 grid
  MAX_SVG_BYTES = 1024 * 1024 # The SVG of a MAX_MESSAGE_LENGTH message is well below this

  configure do
    set :root, __dir__
    set :erb, escape_html: true
    enable :logging
  end

  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
    also_reload File.join(__dir__, 'lib/**/*.rb')
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

  get '/' do
    erb :index
  end

  post '/generate' do
    @message = params[:message].to_s
    halt_with 413, "Message is limited to #{MAX_MESSAGE_LENGTH} characters" if @message.length > MAX_MESSAGE_LENGTH

    @svg_content = Cistergraphia.to_svg(Cistergraphia.encode(@message))
    @normalized = Cistergraphia.normalize(@message)
    erb :result
  end

  get '/decode' do
    erb :decode
  end

  post '/decode' do
    @message = Cistergraphia.decode(submitted_svg)
    erb :decoded
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

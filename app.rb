# frozen_string_literal: true

# Cistergraphia Web Application
# ============================
#
# Purpose:
# - Provides a web interface for the Cistergraphia cipher system
# - Handles message encryption and SVG generation
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

  error Cistergraphia::EmptyMessageError do
    status 400
    @error_message = env['sinatra.error'].message
    erb :error
  end

  # Never echo internal exception details back to the browser
  error do
    @error_message = 'Unexpected error while generating the cipher.'
    erb :error
  end

  get '/' do
    erb :index
  end

  post '/generate' do
    @message = params[:message].to_s
    @svg_content = Cistergraphia.to_svg(Cistergraphia.encode(@message))
    erb :result
  end
end

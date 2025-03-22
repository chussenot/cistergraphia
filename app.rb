require 'sinatra'
require 'sinatra/reloader' if development?
require 'nokogiri'
require_relative 'lib/cistergraphia'

class CistergraphiaApp < Sinatra::Base
  configure do
    set :root, File.dirname(__FILE__)
    set :views, Proc.new { File.join(root, "views") }
    enable :logging
  end

  configure :development do
    register Sinatra::Reloader
    # Also reload the lib files when changed
    also_reload './lib/**/*.rb'
  end

  # Add error handling
  error do
    erb :error
  end

  get '/' do
    erb :index
  end

  post '/generate' do
    begin
      @message = params[:message]
      halt 400, 'Message is required' if @message.nil? || @message.empty?
      
      sequence = Cistergraphia.cister(@message)
      Cistergraphia.inject_evil_symbols(sequence) until Cistergraphia.perfect_square?(sequence.size)

      @svg_content = generate_svg(sequence)
      erb :result
    rescue => e
      logger.error "Error generating cipher: #{e.message}"
      halt 500, "Error generating cipher: #{e.message}"
    end
  end

  private

  def generate_svg(sequence)
    y = Cistergraphia::PADDING
    width, height, cols, _rows = Cistergraphia.calculate_dimensions(sequence)

    builder = Nokogiri::XML::Builder.new do |doc|
      doc.svg(
        'xmlns' => 'http://www.w3.org/2000/svg',
        'version' => '1.1',
        'width' => width,
        'height' => height,
        'viewBox' => "0 0 #{width} #{height}",
        'style' => 'background-color: white'
      ) do
        doc.rect('width' => '100%', 'height' => '100%', 'fill' => 'white')

        sequence.map { |s| Cistergraphia.digits(s) }
                .each_slice(cols) do |slice|
                  slice.each_with_index { |s, i| Cistergraphia.symbol(doc, s, i, y) }
                  y += Cistergraphia::SYMBOL_HEIGHT + Cistergraphia::SPACE
                end
      end
    end
    builder.to_xml
  end
end 
require 'sinatra'
require 'sinatra/reloader' if development?
require 'nokogiri'
require_relative 'lib/cistergraphia'

class CistergraphiaApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    erb :index
  end

  post '/generate' do
    @message = params[:message]
    sequence = Cistergraphia.cister(@message)
    Cistergraphia.inject_evil_symbols(sequence) until Cistergraphia.perfect_square?(sequence.size)

    @svg_content = generate_svg(sequence)
    erb :result
  end

  private

  def generate_svg(sequence)
    y = 0
    builder = Nokogiri::XML::Builder.new do |doc|
      doc.svg(
        'xmlns' => 'http://www.w3.org/2000/svg',
        'version' => '1.1',
        'width' => 100 * sequence.size,
        'height' => 100 * (Math.sqrt(sequence.size) + 1),
        'style' => 'background-color: white'
      ) do
        doc.rect(
          'width' => '100%',
          'height' => '100%',
          'fill' => 'white'
        )
        sequence.map { |s| Cistergraphia.digits(s) }
                .each_slice(Math.sqrt(sequence.size).to_i) do |slice|
                  y += Cistergraphia::SPACE + 100
                  slice.each_with_index { |s, i| Cistergraphia.symbol(doc, s, i, y) }
                end
      end
    end
    builder.to_xml
  end
end 
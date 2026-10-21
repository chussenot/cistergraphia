# frozen_string_literal: true

require 'rexml/document'

# A plate brought to Read, redrawn for the page from the file it came in: the
# elements and attributes a plate is made of, nothing else. The reader's page
# shows the file itself (the fragments move, the lacunae are hatched), and a
# file posted from anywhere must not bring a script, a link or a style with it.
module PlateFile
  ELEMENTS = %w[svg defs pattern g rect polygon path line].freeze
  ATTRIBUTES = %w[version width height viewBox class id fill stroke stroke-width stroke-dasharray stroke-linecap
                  stroke-linejoin x y x1 y1 x2 y2 points d transform display opacity patternUnits
                  patternTransform].freeze
  VALUE = /\A[\w\s#().,%-]*\z/ # a number, a word, a colour, a list of points, a transform: never markup or a URL
  PAINT = /\Aurl\(#[\w-]+\)\z/ # a pattern of the file's own (fill="url(#worn)")
  XMLNS = 'http://www.w3.org/2000/svg'
  QUOTED = { attribute_quote: :quote }.freeze # as the library writes them, and tests for them

  module_function

  # The file as the page shows it; nil when it is not a plate at all
  def clean(svg)
    root = REXML::Document.new(svg.to_s).root
    return unless root&.name == 'svg'

    copy = REXML::Document.new
    element(root, copy).add_attribute('xmlns', XMLNS)
    copy.to_s
  rescue REXML::ParseException
    nil
  end

  # An element with its kept attributes and children; one not a plate's is
  # left out with everything inside it
  def element(node, parent)
    copy = REXML::Element.new(node.name, parent, QUOTED)
    node.attributes.each { |name, value| copy.add_attribute(name, value) if keep?(name, value) }
    node.elements.each { |child| element(child, copy) if ELEMENTS.include?(child.name) }
    copy
  end

  def keep?(name, value)
    return false unless ATTRIBUTES.include?(name)
    return value.match?(PAINT) if value.include?('url(')

    value.match?(VALUE)
  end
end

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
                  patternTransform data-tablet].freeze # data-tablet: the seed of a plate's own tablet
  VALUE = /\A[\w\s#().,%-]*\z/ # a number, a word, a colour, a list of points, a transform: never markup or a URL
  PAINT = /\Aurl\(#[\w-]+\)\z/ # a pattern of the file's own (fill="url(#worn)")
  XMLNS = 'http://www.w3.org/2000/svg'

  module_function

  # The file as the page shows it; nil when it is not a plate at all. Its
  # document is the one every reader of the request reads (SVG::Parsed)
  def clean(svg)
    root = Cistergraphia::SVG::Parsed.of(svg).root
    return unless root&.name == 'svg'

    write(root, +'', xmlns: true)
  rescue Cistergraphia::DecodeError
    nil
  end

  # An element with its kept attributes and children, written out as REXML
  # would write a copy (attributes by name, double quotes, empty elements
  # closed), without building one: a large plate has ten thousand elements,
  # and the copy cost more than the parse. One not a plate's is left out with
  # everything inside it; text is never kept
  def write(node, out, xmlns: false)
    out << '<' << node.name << attributes(node, xmlns)
    children = kept_children(node)
    return out << '/>' if children.empty?

    children.each_with_object(out << '>') { |child, written| write(child, written) } << "</#{node.name}>"
  end

  # The child elements a plate is made of (children, not elements: REXML's
  # elements walk through XPath, and cost half the cleaning)
  def kept_children(node)
    node.children.select { |child| child.is_a?(REXML::Element) && ELEMENTS.include?(child.name) }
  end

  # The kept attributes, by name as REXML writes them
  def attributes(node, xmlns)
    kept = node.attributes.each.select { |name, value| keep?(name, value) }
    kept << ['xmlns', XMLNS] if xmlns
    kept.sort_by(&:first).map { |name, value| %( #{name}="#{escape(value)}") }.join
  end

  # A kept value holds no markup (VALUE, PAINT); escaped all the same, as REXML does
  def escape(value)
    value.gsub('&', '&amp;').gsub('<', '&lt;').gsub('"', '&quot;')
  end

  def keep?(name, value)
    return false unless ATTRIBUTES.include?(name)
    return value.match?(PAINT) if value.include?('url(')

    value.match?(VALUE)
  end
end

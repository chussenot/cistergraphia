# frozen_string_literal: true

require 'test_helper'

# Three shortcuts must read exactly what their long way reads: the ambiguity
# of a new plate from its sequence (not its file), the fragments of a new
# broken plate from the signs they were drawn from (not the tray), and a file's
# lines by streaming it (not by building its document)
class FromDataTest < Minitest::Test
  C = Cistergraphia
  SHORT = %w[ab to me we ox go it hi].freeze
  KEYLESS = C::Layout::KEYLESS

  def test_a_new_plate_is_ambiguous_from_its_sequence_exactly_when_its_file_is
    ambiguous = (0...1500).count do |seed|
      layout = KEYLESS[seed % KEYLESS.size]
      sequence = C.encode(SHORT[seed % SHORT.size], random: Random.new(seed))
      from_file = unambiguous_in_file?(sequence, layout, pathless: seed.odd? && layout != :phaistos)

      assert_equal from_file, C::Along.alone?(sequence, layout), "seed #{seed} along #{layout}"
      !from_file
    end
    assert_operator ambiguous, :>, 5, 'the sample holds ambiguous plates to tell apart'
  end

  def test_a_broken_plate_is_drawn_from_the_fragments_its_file_gives_back
    ['Meet me at the old abbey after vespers', 'ora et labora et ora',
     'the brothers will gather in the chapter house after compline'].product((0...30).to_a) do |message, seed|
      svg, fragments = broken(message, Random.new(seed), worn: seed.odd?)

      assert_equal C::Fragments.read(svg), fragments, "#{message.inspect}, seed #{seed}"
      C::SVG::Parsed.forget
    end
  end

  def test_a_plate_streamed_reads_as_its_document
    plates.each do |name, svg|
      streamed = C::SVG::Stream.read(svg)
      C::SVG::Parsed.forget
      whole = C::SVG::Layers.from(C::SVG::Parsed.of(svg).root)
      C::SVG::Parsed.forget

      refute_nil streamed, "#{name} is read by streaming"
      assert_equal whole, streamed, name
    end
  end

  # Whatever a file is, the library answers as it did when it built the
  # document first: the same readings, or the same refusal
  def test_any_file_is_answered_as_its_document_answers
    odd_files.each do |svg|
      assert_equal answers { C::SVG::Layers.from(C::SVG::Parsed.of(svg).root) }, answers { C::SVG::Layers.read(svg) },
                   svg.inspect
    end
  end

  private

  def unambiguous_in_file?(sequence, layout, pathless:)
    C.unambiguous?(C.to_svg(sequence, layout: layout, pathless: pathless), layout)
  ensure
    C::SVG::Parsed.forget
  end

  # [the tray's file, its fragments as drawn], as Fragments.inscribe draws them
  def broken(message, random, worn:)
    sequence = C.encode(message, random: random)
    damage = worn ? C::Weathering.weather(sequence, random: random) : {}
    pieces = C::Fragments::Breaking.cut(Integer.sqrt(sequence.size), random)
    C::Fragments.drawn(sequence, :phaistos, pieces, random, damage)
  end

  def answers
    C::SVG::Parsed.forget
    yield
  rescue C::Error => e
    [e.class, e.message]
  ensure
    C::SVG::Parsed.forget
  end

  def plates
    key = C::Grille.new('K7Q2M-ZXB4P')
    message = 'Meet me at the old abbey after vespers'
    {
      intact: C.inscribe(message, random: Random.new(1))[1],
      rongorongo: C.inscribe(message, layout: :rongorongo, random: Random.new(1))[1],
      grille: C.inscribe(message, layout: key, random: Random.new(1))[1],
      pathless_own_tablet: C.inscribe(message, layout: :leap, pathless: true, tablet: 'ABCDEFGH23',
                                               random: Random.new(1))[1],
      worn_tallied: C::Lacunae.inscribe(message, tally: true, random: Random.new(1))[1],
      sealed: C.inscribe(message, passphrase: 'monastery gate')[1]
    }
  end

  def odd_files
    line = '<line x1="50" y1="50" x2="50" y2="200"/>'
    ['', ' ', 'not xml', '<svg/>', '<html/>', '<svg/><svg/>', '<svg>', '<svg><g></svg>', '</svg>',
     "<svg>#{line}</svg>", "<svg><g class=\"lacunae\">#{line}</g></svg>", "<svg><g class=\"other\">#{line}</g></svg>",
     line, "<svg>#{line}</svg><g/>", '<svg>text</svg>', '<svg width="10" height="10"/>',
     '<?xml version="1.0"?><!-- a note --><svg width="3" height="3"/>',
     '<svg><line x1="5.5" y1=" 7 " x2="1e2" y2="-0.5"/></svg>',
     '<svg><line x1="a" y1="0" x2="0" y2="0"/></svg>', '<svg><line y1="0" x2="0" y2="0"/></svg>',
     '<svg><line x1="&#49;0" y1="0" x2="0" y2="0"/></svg>', '<svg><svg:line x1="1" y1="0" x2="0" y2="0"/></svg>',
     '<svg xmlns:a="u"><line a:x1="9" x1="1" y1="0" x2="0" y2="0"/></svg>',
     '<!DOCTYPE svg [<!ENTITY t "50">]><svg><line x1="&t;" y1="0" x2="0" y2="0"/></svg>',
     '<svg><line x1="1" y1="0" x2="0" y2="0" x1="2"/></svg>', '<svg><![CDATA[x]]></svg>',
     "<svg width=\"1\nx\" height=\"1\nx\"/>", '<svg><line x1="1" y1="0" x2="0" y2="0"></svg>',
     C::SVG.stencil(4, C::Grille.new('K7Q2M-ZXB4P'))]
  end
end

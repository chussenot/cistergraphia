# frozen_string_literal: true

module Cistergraphia
  # The reader's notebook for a plate with a tablet of its own: one entry per
  # sum of a pair, and the scribe's confirmations.
  #
  # Purpose:
  # - What the notebook lists: every sum the plate's pairs make (null pairs
  #   aside: their mark is public), how often, and how each was spelled
  # - What the scribe confirms: entries written against sums, three at a time
  #
  # Design Decisions:
  # - The reader maps sums, never signs: the split has already grouped every
  #   pair that adds to one value, so an entry is a sum
  # - The scribe confirms only when at least AT_ONCE entries hold at once, and
  #   then says which; otherwise "nothing holds yet", never how many. When
  #   fewer than AT_ONCE sums are left out of ink, the scribe confirms them
  #   as soon as all of them hold (Return of the Obra Dinn's late twos)
  # - The scribe reads the plate's tablet from its seed, as the decoder does:
  #   the reader's page never holds the tablet
  #
  # Constraints:
  # - Intact plates with a tablet of their own, along the keyless way the
  #   pair test finds, shown or withheld (on a pathless plate the reader finds
  #   it first, at the desk: the scribe reads it as the decoder does)
  module Notebook
    AT_ONCE = 3
    SPELLINGS = 3 # spellings shown per entry
    NO_TABLET = 'This plate has no tablet of its own: the shared one reads it'

    module_function

    # The sequence of a plate along the keyless way whose pairs all land on a
    # value of the tablet (the same set under any tablet), or nil
    def read(svg)
      strokes = SVG.lines(svg)
      Layout::KEYLESS.each do |way|
        sequence = SVG.read(svg, layout: way, strokes: strokes)
        Cistergraphia.decipher(sequence)
        return sequence
      rescue DecodeError
        next
      end
      nil
    end

    # Every pair that reads, as [first, second, sum], in reading order: null
    # pairs (a second sign of EVIL_MARKER) are left out
    def pairs(sequence)
      sequence.each_slice(2).filter_map { |a, b| [a, b, a + b] unless b == EVIL_MARKER }
    end

    # One entry per sum: { sum:, seen:, spellings: [[a, b], ...] }, the most
    # seen first (the space, nearly always), then by sum
    def entries(sequence)
      listed = pairs(sequence).group_by(&:last).map do |sum, spelled|
        { sum: sum, seen: spelled.size, spellings: spelled.map { |a, b, _| [a, b] }.uniq }
      end
      listed.sort_by { |entry| [-entry[:seen], entry[:sum]] }
    end

    # The entries that hold, { sum => character }, of those written in pencil
    # ({ sum => character }), the sums already in ink set aside: all that
    # hold when at least AT_ONCE do, or when the sums left out of ink are
    # fewer than AT_ONCE and every one of them holds; otherwise none
    def held(svg, pencil, inked = [])
      tablet, sums = plate(svg)
      open = sums - inked
      right = pencil.slice(*open).select { |sum, char| tablet[sum] == char }
      confirmed?(right, open) ? right : {}
    end

    # [value => character, every sum] of a plate with a tablet of its own
    def plate(svg)
      seed = Tablet.seed_of(svg) or raise Error, NO_TABLET
      sequence = read(svg) or raise DecodeError, 'No way reads this plate'
      [Tablet.characters(seed), entries(sequence).map { |entry| entry[:sum] }]
    end

    # Three at a time, or the last ones together
    def confirmed?(right, open)
      right.size >= AT_ONCE || (open.size < AT_ONCE && open.all? { |sum| right.key?(sum) })
    end
  end
end

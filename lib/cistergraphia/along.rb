# frozen_string_literal: true

module Cistergraphia
  # A new plate read along the other layouts, from its sequence: what the
  # decoder would read in its file along each other way, found without
  # drawing the file (as Lacunae::Along does for a weathered plate).
  #
  # Purpose:
  # - Tell, before a plate is drawn, whether it would also read as letters
  #   along another layout (Cistergraphia.inscribe draws it again if so)
  #
  # Design Decisions:
  # - The other way reads the same signs, turned half round where the two
  #   paths disagree on a cell: exactly what reading the file back finds
  #   (Cistergraphia.unambiguous?, kept as the reference the tests hold this to)
  # - Drawing a plate takes nothing from the random, so a plate is drawn
  #   once, when it is kept: drawing every candidate to read it back cost
  #   four times the rest of inscribing it
  module Along
    module_function

    # True when the sequence reads as letters along its own layout only
    def alone?(sequence, layout)
      Layout.others(layout, Integer.sqrt(sequence.size)).none? do |other|
        Cistergraphia.decipher(reread(sequence, layout, other))
      rescue DecodeError
        false
      end
    end

    # A sequence laid along one layout, read along another
    def reread(sequence, layout, other)
      size = Integer.sqrt(sequence.size)
      drawn = Layout.path(size, layout).each_with_index.to_h do |(row, col, turned), index|
        [[row, col], [index, turned]]
      end
      Layout.path(size, other).map do |row, col, turned|
        index, was = drawn.fetch([row, col])
        was == turned ? sequence[index] : Glyphs.turned(sequence[index])
      end
    end
  end
end

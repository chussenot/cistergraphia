# frozen_string_literal: true

module Cistergraphia
  # Weathered plates: game plates that have lost some strokes, and the
  # restoration of what is lost by the pair checksum.
  #
  # Purpose:
  # - Lay lacunae on a plate (whole quadrants, or some of a quadrant's five
  #   stroke positions) so that it stays solvable
  # - Restore a weathered plate: every pair must balance (sum to a tablet
  #   value, or end with 9999), and the edition says what the balance decides
  #
  # Design Decisions:
  # - Damage is placed on purpose, not at random: a lacuna is kept only if the
  #   balance restores it, or narrows it to at most MAX_DOUBT letters, never a
  #   space, and at most one doubtful letter per word. The reader's sense of
  #   the language settles the doubts; the server needs no word list
  # - One lacuna per pair at most, about one pair in SHARE: the stem always
  #   survives, so every sign keeps its place on the grid
  # - The edition follows the Leiden conventions of epigraphy: [r] restored,
  #   [b/l] restored with a doubt the balance cannot settle
  # - Damage is { sequence index => lost strokes }, strokes canonical and
  #   upright, relative to the sign: the same for every layout
  #
  # Constraints:
  # - Game plates only: a sealed plate that loses one stroke no longer opens
  module Weathering
    SHARE = 3        # about one pair in three loses something
    MAX_DOUBT = 3    # letters a doubtful lacuna may leave
    NULL = ''        # what a null pair (noise, 9999) reads as

    # Each quadrant's five stroke positions: the strokes of 1, 2, 3, 4 and 6
    POSITIONS = Glyphs::PLACES.keys.to_h do |place|
      [place, [1, 2, 3, 4, 6].map { |digit| Glyphs::CANONICAL.call(Glyphs::LINES.fetch(digit * place).first) }]
    end.freeze

    # Place => digit => its strokes (canonical, sorted); 0 has none
    DIGIT_STROKES = Glyphs::DIGITS.transform_values { |glyphs| glyphs.invert.merge(0 => []) }.freeze

    module_function

    # Lacunae for a game sequence: { index => lost strokes }
    def weather(sequence, random: Random.new)
      starts = (0...sequence.size).step(2).to_a
      target = [starts.size / SHARE, 1].max
      words = words_of(sequence)
      doubted = Set.new
      starts.shuffle(random: random).each_with_object({}) do |start, damage|
        break damage if damage.size >= target

        index, lost = try_lacuna(sequence, start, [words, doubted], random)
        damage[index] = lost if index
      end
    end

    # [index, lost strokes] on one sign of the pair at start, or nil when that
    # lacuna would not be fair (doubts are counted in doubted, by word)
    def try_lacuna(sequence, start, (words, doubted), random)
      index = start + random.rand(2)
      lost = lacuna(random)
      letters = outcomes(sequence, start, { index => lost })
      return unless fair?(letters, words[start], doubted)

      doubted << words[start] if letters.size > 1
      [index, lost]
    end

    # A whole quadrant, or one to three of its stroke positions
    def lacuna(random)
      positions = POSITIONS.fetch(POSITIONS.keys.sample(random: random))
      random.rand(2).zero? ? positions : positions.sample(1 + random.rand(3), random: random)
    end

    # Whether a lacuna leaving these letters is fair to the reader
    def fair?(letters, word, doubted)
      return true if letters.size == 1
      return false if letters.size > MAX_DOUBT || letters.intersect?([' ', NULL])

      !word.nil? && !doubted.include?(word)
    end

    # Pair start => the number of the word its letter belongs to (nil for spaces and null pairs)
    def words_of(sequence)
      word = 0
      sequence.each_slice(2).with_index.to_h do |(a, b), pair|
        letter = balance(a, b)
        word += 1 if letter == ' '
        [pair * 2, letter.to_s.match?(/\A[a-z]\z/) ? word : nil]
      end
    end

    # What a pair can read as, with some of its strokes lost
    def outcomes(sequence, start, damage)
      firsts, seconds = [start, start + 1].map do |index|
        lost = damage.fetch(index, [])
        candidates(surviving(sequence[index], lost), lost)
      end
      readings(firsts, seconds)
    end

    # Every letter (or NULL) a pair can balance as, given each sign's candidate values
    def readings(firsts, seconds)
      firsts.product(seconds).filter_map { |a, b| balance(a, b) }.uniq.sort
    end

    # A tablet letter, NULL for a null pair, or nil when the pair does not balance
    def balance(first, second)
      second == EVIL_MARKER ? NULL : CHARACTERS[first + second]
    end

    # The strokes of a number that a lacuna leaves (the stem always survives)
    def surviving(num, lost)
      Glyphs.strokes(num).map(&Glyphs::CANONICAL) - lost
    end

    # Every number a sign can be: its visible strokes, whatever the lost positions held
    def candidates(visible, lost)
      seen = by_place(without_stem(visible))
      gone = by_place(lost.map(&Glyphs::CANONICAL))
      DIGIT_STROKES.keys.map { |place| digits(place, seen[place].sort, gone[place]).map { |d| d * place } }
                   .reduce([0]) { |sums, values| sums.product(values).map(&:sum) }
    end

    def without_stem(strokes)
      strokes = strokes.map(&Glyphs::CANONICAL)
      raise DecodeError, 'Symbol without a stem' unless strokes.delete(Glyphs::CANONICAL.call(Glyphs::STEM))

      strokes
    end

    def by_place(strokes)
      grouped = strokes.group_by { |stroke| Glyphs::STROKE_PLACES.fetch(stroke) { raise DecodeError, "Unknown stroke #{stroke}" } }
      Hash.new { |_, _| [] }.merge(grouped)
    end

    # The digits a quadrant can hold, given what is seen and what is lost of it
    def digits(place, seen, gone)
      found = DIGIT_STROKES.fetch(place).select { |_, strokes| (strokes - gone).sort == seen }.keys
      raise DecodeError, 'Unknown glyph' if found.empty?

      found
    end

    # The restored text: every pair weighed, in the Leiden conventions
    module Edition
      # One letter: what the balance allows, and how it was read. A restored
      # space is printed plain: word division is the editor's in any edition
      Token = Struct.new(:letters, :kind) do
        def to_s
          case kind
          when :read then letters.first
          when :restored then letters == [' '] ? ' ' : "[#{letters.first}]"
          else "[#{letters.join('/')}]"
          end
        end
      end

      module_function

      # The edition as text, from [candidate values, damaged?] of every sign in reading order
      def text(cells)
        letters = tokens(cells)
        raise DecodeError, 'No enciphered characters found' if letters.empty?

        letters.join
      end

      def tokens(cells)
        raise DecodeError, 'Sequence has an odd number of values' if cells.size.odd?

        cells.each_slice(2).filter_map do |(firsts, hurt_a), (seconds, hurt_b)|
          letters = Weathering.readings(firsts, seconds)
          raise DecodeError, 'A pair does not balance' if letters.empty?
          next if letters == [NULL]

          Token.new(letters, kind(letters, hurt_a || hurt_b))
        end
      end

      def kind(letters, damaged)
        return :read unless damaged

        letters.size == 1 ? :restored : :doubt
      end
    end
  end
end

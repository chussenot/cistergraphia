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
    SHARE = 3 # about one pair in three loses something
    TALLIED_SHARE = 2 # one pair in two, with tally signs to restore whole signs
    MAX_DOUBT = 3    # letters a doubtful lacuna may leave
    NULL = ''        # what a null pair (noise, 9999) reads as

    # Each quadrant's five stroke positions: the strokes of 1, 2, 3, 4 and 6
    POSITIONS = Glyphs::PLACES.keys.to_h do |place|
      [place, [1, 2, 3, 4, 6].map { |digit| Glyphs::CANONICAL.call(Glyphs::LINES.fetch(digit * place).first) }]
    end.freeze

    # Place => digit => its strokes (canonical, sorted); 0 has none
    DIGIT_STROKES = Glyphs::DIGITS.transform_values { |glyphs| glyphs.invert.merge(0 => []) }.freeze

    module_function

    # Lacunae for a game sequence: { index => lost strokes }. With lines (the
    # grid row and column of every sign, on a plate with tally signs), whole
    # signs may be lost too, and more pairs are damaged
    def weather(sequence, random: Random.new, lines: nil)
      starts = (0...sequence.size).step(2).to_a
      target = target_for(starts.size, lines)
      judge = [words_of(sequence), Set.new, lines && Cords.new(lines)]
      starts.shuffle(random: random).each_with_object({}) do |start, damage|
        break damage if damage.size >= target

        index, lost = try_whole_or_lacuna(sequence, start, judge, random)
        damage[index] = lost if index
      end
    end

    # How many pairs to damage
    def target_for(pairs, lines)
      [pairs / (lines ? TALLIED_SHARE : SHARE), 1].max
    end

    def try_whole_or_lacuna(sequence, start, (words, doubted, cords), random)
      cords&.try_whole(start, random) || try_lacuna(sequence, start, [words, doubted], random, cords)
    end

    # [index, lost strokes] on one sign of the pair at start, or nil when that
    # lacuna would not be fair (doubts are counted in doubted, by word)
    def try_lacuna(sequence, start, (words, doubted), random, cords = nil)
      index = start + random.rand(2)
      lost = lacuna(random)
      letters = outcomes(sequence, start, { index => lost })
      return unless fair?(letters, words[start], doubted) && (cords.nil? || cords.free?(index))

      cords&.count(index)
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

    # Every letter (or NULL) a pair can balance as, given each sign's candidate
    # values. Linear in the candidates (a sign wholly lost has 10,000), never
    # their product: each tablet value is looked up, not every pair of values
    def readings(firsts, seconds)
      return [] if firsts.empty?

      others = seconds.to_set
      letters = CHARACTERS.select { |sum, _| firsts.any? { |a| others.include?(sum - a) } }.values
      (others.include?(EVIL_MARKER) ? letters + [NULL] : letters).sort
    end

    # A tablet letter, NULL for a null pair, or nil when the pair does not balance
    def balance(first, second)
      second == EVIL_MARKER ? NULL : CHARACTERS[first + second]
    end

    # Whether a value can balance with one of its partner's candidates (a set):
    # a null pair (the second is 9999), or a sum on the tablet
    def balances?(value, partners, first:)
      return true if first ? partners.include?(EVIL_MARKER) : value == EVIL_MARKER

      CHARACTERS.each_key.any? { |sum| partners.include?(sum - value) }
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

    # Where whole signs may be lost, on a plate with tally signs: a whole sign is
    # given back exactly by a row (or column) tally when it is that line's only
    # lacuna. So a whole sign needs a line with no lacuna yet, and that line is
    # then kept clear: no later lacuna may enter it. Other lacunae need only be
    # fair by their pair, as without tallies (tallies only ever narrow)
    class Cords
      WHOLE = POSITIONS.values.flatten(1).freeze

      def initialize(lines)
        @lines = lines
        @count = Hash.new(0)
        @reserved = Set.new
      end

      # [index, every stroke position] when a whole sign of this pair can go, half the time
      def try_whole(start, random)
        return unless random.rand(2).zero?

        index = start + random.rand(2)
        clear = @lines[index].find { |line| @count[line].zero? }
        return unless clear && free?(index)

        count(index)
        @reserved << clear
        [index, WHOLE]
      end

      # Whether a lacuna may go on this sign: none of its lines is kept clear
      def free?(index)
        @lines[index].none? { |line| @reserved.include?(line) }
      end

      def count(index)
        @lines[index].each { |line| @count[line] += 1 }
      end
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

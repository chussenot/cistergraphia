# frozen_string_literal: true

require 'test_helper'

class NotebookTest < Minitest::Test
  C = Cistergraphia
  Notebook = Cistergraphia::Notebook
  SEED = 'K7Q2M-ZXB4P'
  MESSAGE = 'Meet me at the old abbey after vespers'

  def setup
    @sequence, @svg = C.inscribe(MESSAGE, layout: :furrows, tablet: SEED)
    @tablet = C::Tablet.characters(SEED)
    @sums = Notebook.entries(@sequence).map { |entry| entry[:sum] }
  end

  def right(sums)
    sums.to_h { |sum| [sum, @tablet[sum]] }
  end

  def test_the_notebook_lists_every_sum_once_the_most_seen_first_with_its_spellings
    entries = Notebook.entries(@sequence)
    letters = C.normalize(MESSAGE).chars

    assert_equal letters.uniq.size, entries.size, 'one entry per letter of the message'
    assert_equal letters.size, entries.sum { |entry| entry[:seen] }, 'every pair that reads, null pairs aside'
    seen = entries.map { |entry| entry[:seen] }

    assert_equal seen.sort.reverse, seen
    entries.each do |entry|
      assert(entry[:spellings].all? { |a, b| a + b == entry[:sum] })
    end
    assert_equal @sequence, Notebook.read(@svg), 'the way is found by the pair test, under any tablet'
  end

  def test_the_scribe_confirms_three_at_a_time_and_says_nothing_of_fewer
    assert_empty Notebook.held(@svg, right(@sums.first(2))), 'two right: nothing holds yet'
    wrong = { @sums[3] => (('a'..'z').to_a - [@tablet[@sums[3]]]).first }

    assert_equal right(@sums.first(3)), Notebook.held(@svg, right(@sums.first(3)).merge(wrong)),
                 'three right hold, the wrong one stays in pencil'
    assert_empty Notebook.held(@svg, right(@sums.first(2)).merge(wrong)), 'two right and a wrong one: nothing'
  end

  def test_the_last_ones_are_confirmed_together_when_fewer_than_three_are_left
    inked = @sums.first(@sums.size - 2)
    last = @sums.last(2)

    assert_equal right(last), Notebook.held(@svg, right(last), inked)
    assert_empty Notebook.held(@svg, right(last.first(1)), inked), 'one of the last two is not enough'
    assert_empty Notebook.held(@svg, right(@sums.first(3)), @sums.first(3)), 'entries already in ink count for nothing'
  end

  def test_a_plate_on_the_shared_tablet_has_no_notebook
    _, shared = C.inscribe(MESSAGE)
    error = assert_raises(C::Error) { Notebook.held(shared, {}) }

    assert_equal Notebook::NO_TABLET, error.message
  end
end

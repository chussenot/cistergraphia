# frozen_string_literal: true

require 'test_helper'
require 'rack/test'
require_relative '../app'

# The day's chapter (web/chapter.rb): its texts, its week, the same plate for
# every reader, and its pages. Every text under every rung is rake chapter:check's
# (a minute and a half); here, the next two weeks.
class ChapterTest < Minitest::Test
  include Rack::Test::Methods

  def app
    CistergraphiaApp
  end

  def at(date)
    previous = ENV.fetch('CHAPTER_DATE', nil)
    ENV['CHAPTER_DATE'] = date.iso8601
    yield
  ensure
    ENV['CHAPTER_DATE'] = previous
  end

  def test_every_text_is_what_its_plate_carries_and_long_enough_for_a_tablet_of_its_own
    (Chapter::READINGS + Chapter::FEASTS.values).each do |reading|
      text = reading.fetch('text')
      assert_match(/\A[A-Za-z]+( [A-Za-z]+)+\z/, text, 'letters and single spaces: the plate shows what it carries')
      assert_operator text.split.size, :>=, Cistergraphia::Tablet::SHORT, text
      assert_operator text.size, :<=, 50, "#{text}: a 10 × 10 plate at most"
      refute_empty reading.fetch('source').strip
    end
    texts = Chapter::READINGS.map { |reading| reading['text'].downcase }
    assert_equal texts.uniq, texts, 'a reading appears once in the order'
  end

  def test_feasts_are_days_of_the_year_with_a_name
    Chapter::FEASTS.each do |day, feast|
      month, date = day.split('-').map { |part| Integer(part, 10) }
      assert Date.valid_date?(2028, month, date), day # a leap year: 02-29 would be a day
      refute_empty feast.fetch('name')
    end
  end

  def test_the_first_chapter_is_a_monday_and_the_week_climbs_to_the_expert_plate
    assert_predicate Chapter::FIRST, :monday?
    rungs = (0..6).map { |i| Chapter.set(Chapter::FIRST + i).rung }
    assert_equal %i[intact worn pathless broken tablet ruined expert], rungs
    assert_equal :phaistos, Chapter.set(Chapter::FIRST).layout
    assert_equal 8, Chapter.set(Chapter::FIRST + 7).number
  end

  def test_the_reading_order_runs_from_the_top_and_starts_again_past_the_last
    first = Chapter.set(Chapter::FIRST)
    assert_equal Chapter::READINGS.first['text'], first.text
    again = Chapter::FIRST + Chapter::READINGS.size
    again += 1 while Chapter::FEASTS.key?(again.strftime('%m-%d'))
    index = (again - Chapter::FIRST).to_i % Chapter::READINGS.size
    assert_equal Chapter::READINGS[index]['text'], Chapter.set(again).text
  end

  def test_a_feast_sets_its_own_line_and_keeps_the_weekdays_rung
    bernard = Date.new(2027, 8, 20)
    day = Chapter.set(bernard)
    assert_equal 'Saint Bernard of Clairvaux', day.feast
    assert_equal Chapter::FEASTS['08-20']['text'], day.text
    assert_equal Chapter::WEEK.fetch(bernard.wday).first, day.rung
    assert_nil Chapter.set(bernard + 1).feast
  end

  def test_there_is_no_chapter_before_the_first_nor_ahead_of_today
    at(Chapter::FIRST + 3) do
      assert_nil Chapter.of(Chapter::FIRST - 1)
      assert_nil Chapter.of(Chapter::FIRST + 4)
      assert_equal 4, Chapter.of(Chapter::FIRST + 3).number
    end
  end

  def test_a_day_draws_the_same_plate_every_time_and_another_day_another
    day = Chapter.set(Chapter::FIRST + 1)
    assert_equal Chapter.draw(day), Chapter.draw(day)
    refute_equal Chapter.draw(day), Chapter.draw(Chapter.set(Chapter::FIRST + 8))
  end

  def test_the_next_two_weeks_each_read_back_as_their_text
    from = [Date.today, Chapter::FIRST].max
    troubles = (0...14).filter_map { |i| Chapter.trouble(Chapter.set(from + i)) }
    assert_empty troubles
  end

  def test_the_check_tries_a_text_under_every_rung_and_names_what_would_not_read
    assert_empty Chapter.check(days: 1, from: Chapter::FIRST, texts: Chapter::READINGS.first(1))
    short = Chapter::Day.new(number: 3, date: Chapter::FIRST, rung: :broken, layout: :phaistos, text: 'ab')
    assert_match(/\AChapter 3, 2026-10-26 \(broken, phaistos\): ab: Too short a message to break/,
                 Chapter.trouble(short))
  end

  def test_an_edition_holds_a_text_letter_by_letter_or_among_a_brackets
    assert Chapter.holds?('h[e]ll[o/p]', 'hello')
    assert Chapter.holds?('a[ ]b', 'a b')
    refute Chapter.holds?('h[a/i]llo', 'hello')
    refute Chapter.holds?('hell', 'hello')
  end

  def test_the_runway_counts_the_days_of_new_readings_left
    assert_equal Chapter::READINGS.size - 1, Chapter.runway(Chapter::FIRST)
    assert_equal(-1, Chapter.runway(Chapter::FIRST + Chapter::READINGS.size))
  end

  def test_the_day_turns_at_midnight_utc
    assert_equal 1, Chapter.seconds_left(Time.utc(2026, 10, 26, 23, 59, 59))
    assert_equal 86_400, Chapter.seconds_left(Time.utc(2026, 10, 26))
  end

  def test_the_chapter_opens_as_the_reader_s_game_with_its_day_and_never_its_text
    at(Chapter::FIRST + 6) do
      get '/chapter'

      assert_predicate last_response, :ok?
      body = last_response.body
      assert_includes body, 'data-play="expert"'
      assert_includes body, 'data-chapter="2026-11-01"'
      assert_includes body, 'Chapter 7'
      refute_includes body.downcase, Chapter.of(Chapter::FIRST + 6).text.downcase
      assert_match(%r{<p class="chapter-source" data-chapter-source hidden>From [^<]+\.</p>}, body)
    end
  end

  def test_today_s_chapter_may_be_kept_until_the_day_turns_and_links_back_never_ahead
    at(Chapter::FIRST + 6) do
      get '/chapter'

      assert_includes last_response.headers['Cache-Control'], 'public'
      assert_includes last_response.body, 'href="/chapter/2026-10-31"' # the day before
      refute_includes last_response.body, 'href="/chapter/2026-11-02"' # not yet written
    end
  end

  def test_each_rung_of_the_week_opens_its_furniture
    at(Chapter::FIRST + 6) do
      { 0 => 'data-desk', 1 => 'data-bench', 3 => 'data-fragments', 4 => 'data-notebook' }.each do |offset, mark|
        get "/chapter/#{(Chapter::FIRST + offset).iso8601}"

        assert_predicate last_response, :ok?
        assert_includes last_response.body, mark, "day #{offset + 1}"
      end
    end
  end

  def test_a_ruined_chapter_s_board_asks_the_chapter_for_its_bench
    at(Chapter::FIRST + 5) do
      get '/chapter/2026-10-31'

      assert_includes last_response.body, 'action="/chapter/2026-10-31" class="rejoin-restore"'
      post '/chapter/2026-10-31', rejoined: '1'

      assert_predicate last_response, :ok?
      assert_includes last_response.body, 'Ruined, rejoined: worn'
      assert_includes last_response.body, 'data-chapter="2026-10-31"'
    end
  end

  def test_a_chapter_not_written_or_not_a_date_is_said_so
    at(Chapter::FIRST) do
      get '/chapter/2026-10-27'
      assert_equal 404, last_response.status
      assert_includes last_response.body, 'not yet written'

      get '/chapter/2026-10-25'
      assert_includes last_response.body, 'The chapters begin on 26 October 2026'

      get '/chapter/2026-02-30'
      assert_includes last_response.body, 'not a date the abbey keeps'
    end
  end

  def test_read_invites_the_reader_with_no_plate_to_the_chapter_and_the_nav_leads_there
    get '/decode'

    assert_includes last_response.body, '<a href="/chapter">read the day’s chapter</a>'
    assert_includes last_response.body, 'href="/chapter" class="">Chapter</a>'
  end
end

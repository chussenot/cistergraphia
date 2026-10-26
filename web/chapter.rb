# frozen_string_literal: true

require 'date'
require 'digest'
require 'yaml'

# The day's chapter: one plate the abbey sets each day, the same for every
# reader, as the chapter house heard one chapter of the Rule a day.
#
# Design Decisions:
# - Nothing is stored: a day's plate is drawn from a Random seeded by its date,
#   so every server, every restart and every reader draws the same plate
# - The week climbs the ladder (WEEK): Monday is the gentlest, Sunday the
#   expert plate. A reader learns the cadence once
# - The texts are a reading order (web/chapters.yml): chapter n reads the nth
#   line, and new lines are appended, so the chapters already read keep their
#   text. Past the last line the order starts again: the chapter never stops,
#   it repeats. Feasts are fixed dates that set their own line
# - The day turns at midnight UTC, the same instant for everyone: a chapter is
#   the same plate wherever it is shared
# - The page is the same for every reader, so it is kept in memory once
#   drawn and laid (CACHE days): drawing a plate and laying its bench or board
#   cost a tenth of a second to half a second, and the day's chapter is the
#   page every reader asks for
#
# Constraints:
# - No chapter before FIRST, and none ahead of today: the archive runs back,
#   never forward
# - A plate is the same as long as the code that draws it: a change to the
#   drawing (or a Ruby whose Random deals otherwise) redraws today's plate too.
#   Ship such changes at the turn of the day (docs/operations.md)
module Chapter
  FIRST = Date.new(2026, 10, 26) # chapter 1, a Monday
  # Date#wday => [rung, layout]: :any draws one of the five keyless ways for the
  # day; broken plates follow the snail
  WEEK = {
    1 => %i[intact phaistos],
    2 => %i[worn any],
    3 => %i[pathless any],
    4 => %i[broken phaistos],
    5 => %i[tablet any],
    6 => %i[ruined phaistos],
    0 => %i[expert any]
  }.freeze
  TEXTS = YAML.safe_load_file(File.join(__dir__, 'chapters.yml')).freeze
  READINGS = TEXTS.fetch('readings').freeze
  FEASTS = TEXTS.fetch('feasts').freeze
  CACHE = 16 # pages kept in memory: today and the days just before, with room for the day after

  Day = Struct.new(:number, :date, :rung, :layout, :text, :source, :feast, keyword_init: true) do
    def path
      "/chapter/#{date.iso8601}"
    end
  end

  @kept = {}
  @lock = Mutex.new

  module_function

  # Today's date, as the chapter counts it. CHAPTER_DATE (2026-11-01) sets
  # another: a rehearsal of a day to come, on a staging server or in the suites
  def today
    parse(ENV.fetch('CHAPTER_DATE', nil)) || Time.now.utc.to_date
  end

  # The chapter of a date, or nil when there is none (before the first, or
  # not yet written)
  def of(date)
    set(date) unless date < FIRST || date > today
  end

  # The chapter a date sets, written or not (the checks look ahead)
  def set(date)
    index = (date - FIRST).to_i
    feast = FEASTS[date.strftime('%m-%d')]
    reading = feast || READINGS[index % READINGS.size]
    rung, layout = WEEK.fetch(date.wday)
    Day.new(number: index + 1, date: date, rung: rung, layout: way(layout, date), text: reading.fetch('text'),
            source: reading.fetch('source'), feast: feast&.fetch('name'))
  end

  # Days of new readings left after today, before the order starts again:
  # negative once it has (the chapters then repeat)
  def runway(date = today)
    READINGS.size - (date - FIRST).to_i - 1
  end

  # What would not do, as lines to print: every text under every rung (a
  # text that cannot make a plate of some rung would fail on its day), then
  # the days ahead as they are set, each drawn and deciphered back to its text
  def check(days:, from: [today, FIRST].max, texts: READINGS + FEASTS.values)
    ahead = (0...days).map { |i| set(from + i) }
    (trials(texts, from) + ahead).filter_map { |day| trouble(day) }
  end

  # Every text under every rung, each on a day of its own (its own seed)
  def trials(texts, from)
    texts.product(WEEK.values).each_with_index.map do |(reading, (rung, layout)), i|
      date = from + i
      Day.new(number: 0, date: date, rung: rung, layout: way(layout, date), text: reading.fetch('text'))
    end
  end

  # Why a chapter's plate does not read back as its text, or nil
  def trouble(day)
    label = "#{day.number.positive? ? "Chapter #{day.number}, #{day.date}" : 'A trial'} (#{day.rung}, " \
            "#{day.layout}): #{day.text}"
    edition = Cistergraphia.decode(draw(day))
    "#{label}: reads #{edition}" unless holds?(edition, Cistergraphia.normalize(day.text))
  rescue Cistergraphia::Error => e
    "#{label}: #{e.message}"
  end

  # Whether an edition holds a text: each letter as it stands, or among a
  # bracket's ([r] restored, [b/l] for the words to decide)
  def holds?(edition, text)
    readings = edition.scan(/\[([^\]]*)\]|([^\[])/).map { |bracket, plain| plain ? [plain] : bracket.split('/', -1) }
    readings.size == text.size && readings.zip(text.chars).all? { |options, char| options.include?(char) }
  end

  # A date written as the chapter's address (2026-10-26), or nil
  def parse(text)
    Date.strptime(text, '%Y-%m-%d') if text
  rescue Date::Error
    nil
  end

  # The day's plate, as the page shows it (PlateFile.clean, as a file brought
  # to Read)
  def plate(day)
    PlateFile.clean(draw(day))
  end

  # What a block makes for a key, made once and kept while it is asked for:
  # the oldest kept goes first. One page is made at a time, so a crowd at the
  # turn of the day draws the new plate once
  def kept(key)
    @lock.synchronize do
      @kept[key] = @kept.delete(key) || yield # asked for again: kept longest
      @kept.shift while @kept.size > CACHE
      @kept[key]
    end
  end

  # The plate a chapter is: the day's seed decides the splits, the wear, the
  # breaks and a tablet of its own; nothing else does
  def draw(day)
    random = seeded(day.date)
    case day.rung
    when :worn then Cistergraphia::Lacunae.inscribe(day.text, layout: day.layout, random: random)[1]
    when :broken, :ruined
      Cistergraphia::Fragments.inscribe(day.text, weathered: day.rung == :ruined, random: random)[1]
    else whole(day, random)
    end
  end

  # An intact plate: pathless, with a tablet of its own, both (the expert
  # plate) or neither
  def whole(day, random)
    pathless = %i[pathless expert].include?(day.rung)
    tablet = seed(random) if %i[tablet expert].include?(day.rung)
    Cistergraphia.inscribe(day.text, layout: day.layout, pathless: pathless, tablet: tablet, random: random)[1]
  end

  # The day's layout: the week's, or one of the five ways, drawn from the date
  def way(layout, date)
    return layout unless layout == :any

    keyless = Cistergraphia::Layout::KEYLESS
    keyless[seeded(date, 'way').rand(keyless.size)]
  end

  # A tablet's seed, drawn from the day's random (Tablet.generate draws at random)
  def seed(random)
    alphabet = Cistergraphia::Tablet::ALPHABET
    Array.new(Cistergraphia::Tablet::LENGTH) { alphabet[random.rand(alphabet.size)] }.join
  end

  def seeded(date, purpose = 'plate')
    Random.new(Digest::SHA256.hexdigest("cistergraphia chapter #{purpose} #{date.iso8601}").to_i(16))
  end

  # Seconds until the day turns: how long today's chapter may be kept
  def seconds_left(now = Time.now.utc)
    tomorrow = now.utc.to_date + 1
    (Time.utc(tomorrow.year, tomorrow.month, tomorrow.day).to_i - now.to_i).clamp(1, 86_400)
  end
end

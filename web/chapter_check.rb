# frozen_string_literal: true

module Chapter
  # Whether the day's chapter will read, before its day: every text under
  # every rung, and the days ahead as they are set, each drawn and deciphered
  # back to its text (rake chapter:check, docs/operations.md)
  module Check
    module_function

    # What would not do, as lines to print: every text under every rung (a
    # text that cannot make a plate of some rung would fail on its day), then
    # the days ahead as they are set, each drawn and deciphered back to its text
    def check(days:, from: [Chapter.today, FIRST].max, texts: READINGS + FEASTS.values)
      ahead = (0...days).map { |i| Chapter.set(from + i) }
      (trials(texts, from) + ahead).filter_map { |day| trouble(day) }
    end

    # Every text under every rung, each on a day of its own (its own seed)
    def trials(texts, from)
      texts.product(WEEK.values).each_with_index.map do |(reading, (rung, layout)), i|
        date = from + i
        Day.new(number: 0, date: date, rung: rung, layout: Chapter.way(layout, date), text: reading.fetch('text'))
      end
    end

    # Why a chapter's plate does not read back as its text, or nil
    def trouble(day)
      label = "#{day.number.positive? ? "Chapter #{day.number}, #{day.date}" : 'A trial'} (#{day.rung}, " \
              "#{day.layout}): #{day.text}"
      edition = Cistergraphia.decode(Chapter.draw(day))
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
  end
end

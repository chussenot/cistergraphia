# frozen_string_literal: true

# The day's chapter's page (web/chapter.rb): the abbey's plate of the day,
# laid as any game plate brought to Read (ReaderGame) and kept once laid.
# Mixed into the app's routes, beside ReaderGame.
module ChapterPage
  private

  # The day's chapter, laid as any game plate brought to Read: the page knows
  # the day, the rung and the source, never the text. It is the same for every
  # reader, so it is kept (Chapter.kept) by what changes it: the day, the
  # board's rejoined=1, today (the link to the day after) and the address it
  # is served at (the page's own link)
  def chapter_page(date)
    day = date && Chapter.of(date)
    halt_with 404, not_a_chapter(date) unless day

    Chapter.kept([day.date, params[:rejoined] == '1', Chapter.today, request.base_url]) do
      lay_chapter(day)
      erb :play
    end
  end

  def lay_chapter(day)
    @page = :chapter
    @chapter = day
    @title = "Chapter #{day.number}"
    @description = "The day's chapter: one plate the abbey sets each day, the same for every reader."
    @svg_content = Chapter.plate(day)
    read_marks(@svg_content)
    lay(@svg_content)
  end

  def not_a_chapter(date)
    return 'This is not a date the abbey keeps. A chapter’s address is its day: /chapter/2026-10-26.' unless date
    return 'This chapter is not yet written: it is set on its day, at midnight UTC.' if date > Chapter.today

    "The chapters begin on #{Chapter::FIRST.strftime('%-d %B %Y')}."
  end
end

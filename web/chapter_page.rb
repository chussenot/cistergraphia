# frozen_string_literal: true

# The day's chapter's page (web/chapter.rb): the abbey's plate of the day,
# laid as any game plate brought to Read (ReaderGame) and kept once laid.
# Mixed into the app's routes, beside ReaderGame.
module ChapterPage
  private

  # The day's chapter, laid as any game plate brought to Read: the page knows
  # the day, the rung and the source, never the text. It is the same for every
  # reader, so it is kept (Chapter.kept) by what changes it: the address, the
  # board's rejoined=1 and today (the link to the day after). Nothing else a
  # request carries lays it (a grille key, a passphrase), and the host it was
  # asked of is written in per request: a page kept is never another's
  def chapter_page(date)
    day = date && Chapter.of(date)
    halt_with 404, not_a_chapter(date) unless day

    params.select! { |name, _| name == 'rejoined' }
    kept_page(day).gsub(Chapter::BASE_URL, Rack::Utils.escape_html(request.base_url))
  end

  def kept_page(day)
    Chapter.kept([request.path, params[:rejoined] == '1', Chapter.today]) do
      lay_chapter(day)
      @base_url = Chapter::BASE_URL
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

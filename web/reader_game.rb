# frozen_string_literal: true

# The reader's game: a weathered or broken game plate brought to Read opens as
# its puzzle, the bench to restore it or the board to rejoin it, built from the
# file alone (never from a message the page would then hold). Mixed into the
# app's routes, beside FormParams.
module ReaderGame
  private

  # Whether the plate brought to Read opens as its puzzle rather than its
  # reading: a weathered or broken game plate, unless the decoder is asked for
  # (decipher=1, or a passphrase). The puzzle is built from the file alone
  def playable?(svg)
    return false if passphrase || params[:decipher] == '1'

    @weathered = Cistergraphia::Lacunae.weathered?(svg)
    @broken = Cistergraphia::Fragments.broken?(svg)
    @svg_content = PlateFile.clean(svg)
    return false unless @svg_content

    laid = if @broken then lay_board(svg)
           elsif @weathered then lay_bench(svg)
           else lay_desk(svg)
           end
    !laid.nil?
  end

  # The reading desk: an intact game plate, along the layout that reads it as
  # letters (or the grille given; a grille plate without its key is for the
  # decoder to ask for). A sealed plate reads as no letters: not a game
  def lay_desk(svg)
    Cistergraphia::Grille.check(svg, submitted_grille)
    @layout = submitted_grille || Cistergraphia::Layout::KEYLESS.find { |layout| letters(svg, layout) }
    return unless @layout && (@values = letters(svg, @layout))

    @desk = true
    @size = Integer.sqrt(@values.size)
  end

  # The plate's values along a layout when every pair reads as a letter, else nil
  def letters(svg, layout)
    sequence = Cistergraphia::SVG.read(svg, layout: layout)
    Cistergraphia.decipher(sequence)
    sequence
  rescue Cistergraphia::DecodeError
    nil
  end

  # The board: the fragments in the order the file lists them
  def lay_board(svg)
    @fragments = Cistergraphia::Fragments.read(svg)
    @size = Cistergraphia::Fragments::Join.side(@fragments)
  end

  # The bench: along the layout the survey finds, or the grille given, when
  # it reads the plate. A grille plate without its key is not a game yet; a
  # wrong key is for the decoder to explain
  def lay_bench(svg)
    survey = Cistergraphia::Lacunae::Survey
    @layout = submitted_grille || survey.layout(svg)
    return unless @layout && survey.edition(svg, @layout)

    @values = survey.values(svg, @layout)
    @damage = survey.damaged(svg, @layout).to_h { |sign| [sign[:index], sign[:lost]] }
    @entries = lacunae_in(svg, @layout, @values)
    @tally = Cistergraphia::Tally::Plate.read(svg, @layout)
    @size = Integer.sqrt(@values.size)
  end
end

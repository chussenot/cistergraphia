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
    @svg_content = PlateFile.clean(svg) if @broken || @weathered
    return false unless @svg_content

    !(@broken ? lay_board(svg) : lay_bench(svg)).nil?
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

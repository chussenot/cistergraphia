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

    parse_whole(svg)
    read_marks(svg)
    return false if two_to_find?

    @svg_content = PlateFile.clean(svg)
    return false unless @svg_content

    !lay(svg).nil?
  end

  # The puzzle redraws the file from its document (PlateFile.clean), so the
  # document is parsed first: the readers that come before it (the marks, the
  # survey) then read it too, and the file is parsed once, not streamed then
  # parsed (SVG::Layers). A file that does not parse is refused where it is read
  def parse_whole(svg)
    Cistergraphia::SVG::Parsed.of(svg)
  rescue Cistergraphia::DecodeError
    nil
  end

  # A plate with its own tablet is a game only intact: the bench and the board
  # speak in letters. Pathless, it is the expert plate: the way, then the tablet
  def two_to_find?
    @own && (@weathered || @broken)
  end

  # What the file says of the plate: worn, broken, pathless, with its own tablet
  def read_marks(svg)
    @weathered = Cistergraphia::Lacunae.weathered?(svg)
    @broken = Cistergraphia::Fragments.broken?(svg)
    @pathless = Cistergraphia::Pathless.pathless?(svg)
    @own = !Cistergraphia::Tablet.seed_of(svg).nil?
  end

  # The puzzle the plate opens as: the board for a broken plate (the bench on
  # it rejoined, when asked), the bench for a worn one, the desk for an intact one
  def lay(svg)
    return lay_rejoined(svg) if @broken && @weathered && params[:rejoined] == '1'
    return lay_board(svg) if @broken

    @weathered ? lay_bench(svg) : lay_desk(svg)
  end

  # The bench on a ruined plate rejoined (rejoined=1, from the board once it
  # is whole): the plate drawn from its own fragments moved into place, its
  # lacunae from the file alone. The file carried on is still the broken one
  def lay_rejoined(svg)
    whole = Cistergraphia::Fragments.rejoined(svg)
    @layout = whole.layout
    @values = whole.signs
    @damage = whole.damage
    @entries = lacunae_from(whole.signs, @layout, @damage, whole.candidates)
    @plate_svg = PlateFile.clean(whole.svg)
    @rejoined = true
    @broken = false
    @size = Integer.sqrt(@values.size)
  end

  # The reading desk: an intact game plate, along the layout that reads it as
  # letters (or the grille given; a grille plate without its key is for the
  # decoder to ask for). A sealed plate reads as no letters: not a game
  def lay_desk(svg)
    Cistergraphia::Grille.check(svg, submitted_grille)
    @layout = submitted_grille || Cistergraphia::Layout::KEYLESS.find { |layout| letters(svg, layout) }
    return unless @layout && (@values = letters(svg, @layout))

    @size = Integer.sqrt(@values.size)
    lay_desk_variant(svg)
    @desk = true
  end

  # A pathless plate lays its ways itself; a plate with its own tablet opens
  # the notebook, on its sums when its way is shown. Pathless too (the expert
  # plate), the notebook waits shut: its sums would tell the way, so the page
  # lists them once the reader has found it
  def lay_desk_variant(svg)
    lay_pathless(svg) if @pathless && !submitted_grille
    @expert = @own && @pathless
    @notebook = @expert ? [] : Cistergraphia::Notebook.entries(@values) if @own
  end

  # The scribe's answer to the notebook: the pencilled entries that hold, as
  # { sum => character } (strings, for JSON), three at a time (Notebook.held)
  def scribe_answer(svg)
    pencil, inked = notebook_sent
    Cistergraphia::Notebook.held(svg, pencil, inked).transform_keys(&:to_s)
  end

  # [{ sum => character } pencilled, [sum] inked], from the page's JSON
  def notebook_sent
    pencil = JSON.parse(params[:pencil].to_s).to_h { |sum, char| [Integer(sum), char.to_s] }
    [pencil, JSON.parse(params[:inked].to_s).map { |sum| Integer(sum) }]
  rescue JSON::ParserError, ArgumentError, TypeError, NoMethodError
    raise Cistergraphia::Error, 'The notebook could not be read: ask again'
  end

  # A pathless plate: the page gets every cell's readings in grid order and
  # not the way, nor the values along it; the desk lays the five ways itself
  def lay_pathless(svg)
    @grid = Cistergraphia::Pathless.grid(svg)
    @layout = :phaistos # the figure's geometry; the plate walk starts row by row
    @values = @grid.map { |_, _, upright, _| upright || 0 }
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
    @layout = submitted_grille || survey.layout(svg) # a keyless layout is found by its edition: not read twice
    return unless @layout && (!submitted_grille || survey.edition(svg, @layout))

    @values = survey.values(svg, @layout)
    @size = Integer.sqrt(@values.size)
    @tally = Cistergraphia::Tally::Plate.read(svg, @layout)
    @pathless ? lay_pathless_bench(svg) : lay_lacunae(svg, survey)
  end

  # The lacunae along the layout, as the file shows them
  def lay_lacunae(svg, survey)
    @damage = survey.damaged(svg, @layout).to_h { |sign| [sign[:index], sign[:lost]] }
    @entries = lacunae_in(svg, @layout, @values)
  end

  # A pathless worn plate (never under a grille: Pathless.check): the page
  # gets the grid (every cell's readings, none for a worn cell) and what each
  # worn cell may hold read either way, never the way nor a lacuna's place
  # along it; the bench lays the five ways itself
  def lay_pathless_bench(svg)
    lay_pathless(svg)
    @worn = worn_cells(svg)
    @entries = []
    @damage = {}
  end
end

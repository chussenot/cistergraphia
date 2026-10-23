# frozen_string_literal: true

# What the forms ask for, read from the request: the mode (by its passphrase)
# and the layout (a grille by its key). Mixed into the app's routes.
module FormParams
  # The ladder: each rung's name, and whether its plate is weathered and broken
  RUNGS = { 'intact' => 'Intact', 'worn' => 'Worn', 'broken' => 'Broken', 'ruined' => 'Ruined' }.freeze
  CONDITIONS = { 'intact' => [false, false], 'worn' => [true, false], 'broken' => [false, true],
                 'ruined' => [true, true] }.freeze

  private

  # The mode switch wins when present; otherwise a non-blank passphrase means
  # secret mode. Secret mode with a blank one gives '' (for the form to explain).
  def passphrase
    return nil if params[:mode] == 'game'

    value = params[:passphrase].to_s
    value.empty? && params[:mode] != 'secret' ? nil : value
  end

  # Phaistos unless another layout is asked for. A grille takes the key given
  # (a grille shared before) or a new one; a key that is not one is kept for
  # the form to explain (@grille_error) and the plate is not made
  def chosen_layout
    case params[:layout]
    when 'rongorongo', 'leap', 'furrows', 'unwinding' then params[:layout].to_sym
    when 'grille' then grille_from(params[:grille]) || Cistergraphia::Grille.generate
    else :phaistos
    end
  end

  def grille_from(key)
    return if key.to_s.strip.empty?

    Cistergraphia::Grille.new(key)
  rescue Cistergraphia::Error => e
    @grille_key = key
    @grille_error = e.message
    :phaistos
  end

  # The grille to read with, when its key is given
  def submitted_grille
    key = params[:grille].to_s
    Cistergraphia::Grille.new(key) unless key.strip.empty?
  end

  # The novice's message, under a grille: nil without one. Too long a pair
  # (@decoy_error) goes back to the form
  def decoy
    text = params[:decoy].to_s.strip
    return if text.empty? || !@layout.is_a?(Cistergraphia::Grille)

    limit = CistergraphiaApp::MAX_PAIR_LENGTH
    too_long = [@message, text].any? { |message| message.length > limit }
    @decoy_error = "With two readers, each message is limited to #{limit} characters" if too_long
    text
  end

  # The plate's condition: a rung of the ladder (intact unless another is
  # asked for), as [weathered, broken]. Tally signs are the library's and the
  # CLI's, not the form's
  def read_conditions
    @condition = RUNGS.key?(params[:condition]) ? params[:condition] : 'intact'
    @weathered, @broken = CONDITIONS.fetch(@condition)
    @condition_error = condition_problem
    @pathless = params[:path] == 'withheld'
    @path_error = path_problem if @pathless
  end

  # What cannot be pathless, in the library's words (@path_error goes back
  # to the form): a sealed plate, a grille plate, a broken one
  def path_problem
    return Cistergraphia::Pathless::NOT_SEALED if passphrase
    return Cistergraphia::Pathless::NOT_UNDER_A_GRILLE if @layout.is_a?(Cistergraphia::Grille)

    Cistergraphia::Pathless::NOT_BROKEN if @broken
  end

  # What cannot be, in the library's words (@condition_error goes back to the
  # form): a sealed plate never weathers, two readers' plates not yet, and a
  # broken plate follows the snail
  def condition_problem
    return if @condition == 'intact'
    return broken_problem if @broken
    return Cistergraphia::Lacunae::NOT_SEALED if passphrase

    Cistergraphia::Lacunae::NOT_TWO_READERS if @decoy
  end

  def broken_problem
    return Cistergraphia::Fragments::NOT_SEALED if passphrase
    return Cistergraphia::Fragments::NOT_UNDER_A_GRILLE if @layout.is_a?(Cistergraphia::Grille)

    Cistergraphia::Fragments::NOT_ALONG_THE_ROWS unless @layout == :phaistos
  end

  # What sends the form back, to explain
  def form_errors
    [@passphrase_error, @grille_error, @decoy_error, @condition_error, @path_error]
  end

  # The rung sent back with an error: invalid, and focused when its error is
  # the form's first (as the other fields are), so it is never missed
  def condition_invalid(rung)
    return '' unless @condition_error && rung == @condition

    form_errors.compact.first == @condition_error ? ' aria-invalid="true" autofocus' : ' aria-invalid="true"'
  end

  # [sequence, svg, grille]: a plate for one reader, or for two (the grille is
  # the abbot's). A weathered plate's lacunae go to @damage, a broken plate's
  # fragments to @pieces
  def inscribe_plate
    return damaged_plate if @broken || @weathered
    unless @decoy
      return Cistergraphia.inscribe(@message, passphrase: passphrase, layout: @layout, pathless: @pathless) + [@layout]
    end

    given = @layout unless params[:grille].to_s.strip.empty? # a shared key is kept; a new one may be redrawn
    Cistergraphia::TwoReaders.inscribe(@message, @decoy, passphrase: passphrase, grille: given)
  end

  # A broken or a weathered game plate: [sequence, svg, layout]. A broken
  # plate's fragments are read back from its file, as the reader's page reads them
  def damaged_plate
    if @broken
      sequence, svg, @pieces, damage = Cistergraphia::Fragments.inscribe(@message, layout: @layout,
                                                                                   weathered: @weathered)
      @damage = damage unless damage.empty?
      @fragments = Cistergraphia::Fragments.read(svg)
    else
      sequence, svg, @damage = Cistergraphia::Lacunae.inscribe(@message, layout: @layout, pathless: @pathless)
    end
    [sequence, svg, @layout]
  end

  # What the plate says: under a grille, what its key reads (both messages for
  # an abbot's key); otherwise the message along the layout the decoder finds
  def read_plate(svg)
    @weathered = Cistergraphia::Lacunae.weathered?(svg)
    @broken = Cistergraphia::Fragments.broken?(svg)
    grille = submitted_grille
    return Cistergraphia::TwoReaders.read(svg, grille, passphrase: passphrase) if grille

    Cistergraphia::TwoReaders::Reading.new(Cistergraphia.decode(svg, passphrase: passphrase), nil, nil)
  end
end

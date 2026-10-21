# frozen_string_literal: true

# What the forms ask for, read from the request: the mode (by its passphrase)
# and the layout (a grille by its key). Mixed into the app's routes.
module FormParams
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
    when 'rongorongo' then :rongorongo
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

  # The plate's condition asked for: weathered, with tally signs, or broken
  # (in that order: what may break depends on the others)
  def read_conditions
    @weathered = weathered?
    @tally = tally?
    @broken = broken?
  end

  # A weathered plate asked for: game mode only, one reader only. What cannot
  # weather (@weathered_error) goes back to the form
  def weathered?
    return false unless params[:weathered] == '1'

    @weathered_error = Cistergraphia::Lacunae::NOT_SEALED if passphrase
    @weathered_error = Cistergraphia::Lacunae::NOT_TWO_READERS if @decoy
    true
  end

  # Tally signs asked for: game mode only, not under a grille. What cannot
  # carry them (@tally_error) goes back to the form
  def tally?
    return false unless params[:tally] == '1'

    @tally_error = Cistergraphia::Tally::NOT_SEALED if passphrase
    @tally_error = Cistergraphia::Tally::NOT_UNDER_A_GRILLE if @layout.is_a?(Cistergraphia::Grille)
    true
  end

  # A broken plate asked for: game mode only, along the snail, weathered or
  # not, without tally signs. What cannot break (@broken_error) goes back to the form
  def broken?
    return false unless params[:broken] == '1'

    @broken_error = broken_problem
    true
  end

  def broken_problem
    return Cistergraphia::Fragments::NOT_SEALED if passphrase
    return Cistergraphia::Fragments::NOT_TALLIED if @tally
    return Cistergraphia::Fragments::NOT_UNDER_A_GRILLE if @layout.is_a?(Cistergraphia::Grille)

    Cistergraphia::Fragments::NOT_ALONG_THE_ROWS unless @layout == :phaistos
  end

  # What sends the form back, to explain
  def form_errors
    [@passphrase_error, @grille_error, @decoy_error, @weathered_error, @tally_error, @broken_error]
  end

  # The conditions share one note: the error it shows, as [checkbox name, message], or nil
  def condition_error
    { weathered: @weathered_error, tally: @tally_error, broken: @broken_error }.find { |_, error| error }
  end

  # A condition checkbox sent back with an error: invalid, and focused when its
  # error is the form's first (as the other fields are), so it is never missed
  def condition_invalid(name, error)
    return '' unless error

    first = condition_error&.first == name && form_errors.compact.first == error
    first ? ' aria-invalid="true" autofocus' : ' aria-invalid="true"'
  end

  # [sequence, svg, grille]: a plate for one reader, or for two (the grille is
  # the abbot's). A weathered plate's lacunae go to @damage, a broken plate's
  # fragments to @pieces
  def inscribe_plate
    return damaged_plate if @broken || @weathered
    unless @decoy
      return Cistergraphia.inscribe(@message, passphrase: passphrase, layout: @layout, tally: @tally) + [@layout]
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
      sequence, svg, @damage = Cistergraphia::Lacunae.inscribe(@message, layout: @layout, tally: @tally)
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

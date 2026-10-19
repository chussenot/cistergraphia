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

  # [sequence, svg, grille]: a plate for one reader, or for two (the grille is the abbot's)
  def inscribe_plate
    return Cistergraphia.inscribe(@message, passphrase: passphrase, layout: @layout) + [@layout] unless @decoy

    given = @layout unless params[:grille].to_s.strip.empty? # a shared key is kept; a new one may be redrawn
    Cistergraphia::TwoReaders.inscribe(@message, @decoy, passphrase: passphrase, grille: given)
  end

  # What the plate says: under a grille, what its key reads (both messages for
  # an abbot's key); otherwise the message along the layout the decoder finds
  def read_plate
    svg = submitted_svg
    grille = submitted_grille
    return Cistergraphia::TwoReaders.read(svg, grille, passphrase: passphrase) if grille

    Cistergraphia::TwoReaders::Reading.new(Cistergraphia.decode(svg, passphrase: passphrase), nil, nil)
  end
end

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
end

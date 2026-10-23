# frozen_string_literal: true

# What a plate asked for on the form cannot be, in the library's words: each
# answer goes back to the form beside its choice (@tablet_error, @path_error,
# @condition_error). Mixed into the app's routes with FormParams, whose
# read_conditions asks them.
module Refusals
  private

  # What cannot have a tablet of its own, in the library's words (@tablet_error
  # goes back to the form): a sealed plate, a grille plate, a damaged one. A
  # pathless one may (the expert plate: the way first, then the tablet)
  def tablet_problem
    return Cistergraphia::Tablet::NOT_SEALED if passphrase
    return Cistergraphia::Tablet::NOT_UNDER_A_GRILLE if @layout.is_a?(Cistergraphia::Grille)

    Cistergraphia::Tablet::NOT_DAMAGED if @weathered || @broken
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
end

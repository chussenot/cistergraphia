# frozen_string_literal: true

module Cistergraphia
  # Two readers, one plate. A grille's key (the abbot's) splits the plate's
  # orbits with a second grille drawn from it (the novice's, see
  # Grille#novice): the abbot's grille reads one message, the novice's another.
  # The abbot's key gives the novice's, so the abbot reads both; the novice's
  # key reads only its own.
  #
  # Each message fills its share of the plate and is padded within it: evil
  # pairs in the game, random signs when sealed (one passphrase for both).
  #
  # Not deniability: the novice's grille visibly leaves about half the plate
  # unread, and a game plate's grilles fall to the known-scheme attack in
  # experiments/cryptanalysis. Two readers with different rights, no more.
  module TwoReaders
    # What a key reads: the plate's message (reader :whole for an ordinary
    # grille plate), or the abbot's with the novice's (:abbot), or the novice's alone
    Reading = Struct.new(:message, :decoy, :reader)
    ATTEMPTS = 20 # keys tried per plate size before a larger plate

    module_function

    # [sequence, svg, the abbot's grille] for a message and a decoy. A given
    # grille keeps its key and the plate grows until both fit; otherwise new
    # keys are drawn first, then the plate grows
    def inscribe(message, decoy, passphrase: nil, grille: nil)
      messages = [unpadded(message, passphrase), unpadded(decoy, passphrase)]
      size = even_side(messages.sum(&:size))
      loop do
        (grille ? [grille] : Array.new(ATTEMPTS) { Grille.generate }).each do |abbot|
          sequence = fill(abbot, size, *messages, sealed: !passphrase.nil?)
          return [sequence, SVG.render(sequence, layout: abbot.as(:pair)), abbot] if sequence
        end
        size += 2
      end
    end

    # What a key reads on a plate
    def read(svg, grille, passphrase: nil)
      Reading.new(Cistergraphia.decode(svg, passphrase: passphrase, layout: grille), nil, :whole)
    rescue DecodeError => e
      abbot = attempt(svg, grille.as(:abbot), passphrase)
      return Reading.new(abbot, attempt(svg, grille.novice, passphrase), :abbot) if abbot

      novice = attempt(svg, grille.as(:novice), passphrase)
      novice ? Reading.new(novice, nil, :novice) : raise(e)
    end

    def attempt(svg, grille, passphrase)
      sequence = SVG.read(svg, layout: grille)
      passphrase ? Secret.decrypt(sequence, passphrase) : Cistergraphia.decipher(sequence)
    rescue DecodeError
      nil
    end

    # A message's signs before padding: pairs in the game, the sealed frame in secret
    def unpadded(message, passphrase)
      passphrase ? Secret.seal_to_digits(message, passphrase) : Cistergraphia.cister(message)
    end

    # The smallest even side whose square holds `count` signs
    def even_side(count)
      side = [Integer.sqrt(count), 2].max
      side += 1 while side * side < count || side.odd?
      side
    end

    # Both messages along their grilles, each padded to its share; nil when one does not fit
    def fill(abbot, size, real, fake, sealed:)
      shares = [abbot.as(:abbot).path(size).size, abbot.novice.path(size).size]
      return unless real.size <= shares[0] && fake.size <= shares[1]

      pad(real, shares[0], sealed) + pad(fake, shares[1], sealed)
    end

    def pad(sequence, size, sealed)
      sequence = sequence.dup
      return sequence + Array.new(size - sequence.size) { SecureRandom.random_number(Secret::BASE) } if sealed

      Cistergraphia.inject_evil_symbols(sequence) while sequence.size < size
      sequence
    end
  end
end

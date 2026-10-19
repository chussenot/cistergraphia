# frozen_string_literal: true

module Cistergraphia
  # Two readers, one plate. A grille's key (the abbot's) splits the plate's
  # orbits with a second grille drawn from it (the novice's, see
  # Grille#novice): the abbot's grille reads one message, the novice's another.
  # The abbot's key gives the novice's, so the abbot reads both; the novice's
  # key reads only its own.
  #
  # Each message fills its share of the plate and is padded within it: evil
  # pairs in the game, random signs when sealed. Sealed, the novice's message
  # takes the passphrase, the abbot's the passphrase with the abbot's key: the
  # novice's key says which cells are the abbot's, and with the passphrase
  # alone a novice could try the abbot's holes cell by cell.
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

    # [sequence, svg, the abbot's grille] for a message and a decoy
    def inscribe(message, decoy, passphrase: nil, grille: nil)
      fake = unpadded(decoy, passphrase)
      real = Cistergraphia.cister(message) unless passphrase # sealed once the abbot's key is known
      needs = [real ? real.size : Secret.max_sealed_size(message), fake.size]
      abbot, size = place(needs, grille)
      real ||= unpadded(message, abbots_passphrase(passphrase, abbot))
      sequence = fill(abbot, size, real, fake, sealed: !passphrase.nil?)
      [sequence, SVG.render(sequence, layout: abbot.as(:pair)), abbot]
    end

    # The passphrase the abbot's message is sealed with
    def abbots_passphrase(passphrase, abbot)
      "#{passphrase} #{abbot.code}"
    end

    # What a key reads on a plate
    def read(svg, grille, passphrase: nil)
      Reading.new(Cistergraphia.decode(svg, passphrase: passphrase, layout: grille), nil, :whole)
    rescue DecodeError => e
      abbot = attempt(svg, grille.as(:abbot), passphrase && abbots_passphrase(passphrase, grille))
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

    # [the abbot's grille, the plate's side] where both messages fit their
    # shares. A given grille keeps its key and the plate grows; otherwise new
    # keys are drawn first, then the plate grows
    def place(needs, grille)
      size = even_side(needs.sum)
      loop do
        (grille ? [grille] : Array.new(ATTEMPTS) { Grille.generate }).each do |abbot|
          return [abbot, size] if shares(abbot, size).zip(needs).all? { |share, need| need <= share }
        end
        size += 2
      end
    end

    def shares(abbot, size)
      [abbot.as(:abbot).path(size).size, abbot.novice.path(size).size]
    end

    # Both messages along their grilles, each padded to its share
    def fill(abbot, size, real, fake, sealed:)
      share, novices = shares(abbot, size)
      pad(real, share, sealed) + pad(fake, novices, sealed)
    end

    def pad(sequence, size, sealed)
      sequence = sequence.dup
      return sequence + Array.new(size - sequence.size) { SecureRandom.random_number(Secret::BASE) } if sealed

      Cistergraphia.inject_evil_symbols(sequence) while sequence.size < size
      sequence
    end
  end
end

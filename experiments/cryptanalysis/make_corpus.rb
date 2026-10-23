# frozen_string_literal: true

# Generates a ciphertext corpus for the cryptanalysis experiment.
#
#   ruby make_corpus.rb MESSAGES_FILE OUT_DIR game|secret [grille|shared-grille|WAY] [pathless]
#                       [own-tablet|shared-own-tablet]
#
# Writes c01.svg, c02.svg, ... (one per line of MESSAGES_FILE) and
# answers.json (what a perfect attack recovers: the normalized text in game
# mode, the exact text in secret mode). The secret-mode passphrase is random
# and thrown away: the attacker never has it. With `grille`, each plate is
# written under its own random grille, whose key is thrown away too; with
# `shared-grille`, every plate under the same one. WAY is one of the keyless
# layouts (phaistos, the default, rongorongo, leap, furrows, unwinding);
# `pathless` writes the plates with their way withheld (game mode only);
# `own-tablet` gives every plate a tablet of its own, its seed stripped from
# the file so the attacker has only the signs; `shared-own-tablet` one such
# tablet for the whole corpus (game mode only).

require 'json'
require 'securerandom'
require_relative '../../lib/cistergraphia'

messages_file, out_dir, mode, layout, *marks = ARGV
ways = Cistergraphia::Layout::KEYLESS.map(&:to_s)
unless out_dir && %w[game secret].include?(mode) && [nil, 'grille', 'shared-grille', *ways].include?(layout) &&
       (marks - %w[pathless own-tablet shared-own-tablet]).empty?
  abort 'usage: make_corpus.rb MESSAGES_FILE OUT_DIR game|secret [grille|shared-grille|WAY] [pathless] ' \
        '[own-tablet|shared-own-tablet]'
end
path = marks.include?('pathless')
own = marks.include?('own-tablet') || marks.include?('shared-own-tablet')
shared_tablet = Cistergraphia::Tablet.generate if marks.include?('shared-own-tablet')

passphrase = SecureRandom.base64(24) if mode == 'secret'
grilled = %w[grille shared-grille].include?(layout)
shared = Cistergraphia::Grille.generate if layout == 'shared-grille'
way = ways.include?(layout) ? layout.to_sym : :phaistos
answers = {}
File.readlines(messages_file, chomp: true).reject(&:empty?).each_with_index do |message, i|
  name = format('c%02d.svg', i + 1)
  grille = shared || (Cistergraphia::Grille.generate if grilled)
  tablet = shared_tablet || (Cistergraphia::Tablet.generate if own)
  _sequence, svg = Cistergraphia.inscribe(message, passphrase: passphrase, layout: grille || way, pathless: path,
                                                   tablet: tablet)
  svg = svg.sub(/ #{Cistergraphia::Tablet::ATTRIBUTE}="[^"]*"/, '') if own # the seed is thrown away
  File.write(File.join(out_dir, name), svg)
  answers[name] = passphrase ? message : Cistergraphia.normalize(message)
end
File.write(File.join(out_dir, 'answers.json'), JSON.pretty_generate(answers))
along = if grilled then " under #{shared ? 'one grille' : 'grilles'}"
        elsif path then " along the #{way}, pathless"
        else " along the #{way}"
        end
along += shared_tablet ? ', all on one tablet of their own' : ', each with its own tablet' if own
puts "#{answers.size} #{mode} ciphertexts#{along} in #{out_dir}"

# frozen_string_literal: true

# Generates a ciphertext corpus for the cryptanalysis experiment.
#
#   ruby make_corpus.rb MESSAGES_FILE OUT_DIR game|secret [grille|shared-grille]
#
# Writes c01.svg, c02.svg, ... (one per line of MESSAGES_FILE) and
# answers.json (what a perfect attack recovers: the normalized text in game
# mode, the exact text in secret mode). The secret-mode passphrase is random
# and thrown away: the attacker never has it. With `grille`, each plate is
# written under its own random grille, whose key is thrown away too; with
# `shared-grille`, every plate under the same one.

require 'json'
require 'securerandom'
require_relative '../../lib/cistergraphia'

messages_file, out_dir, mode, layout = ARGV
unless out_dir && %w[game secret].include?(mode) && [nil, 'grille', 'shared-grille'].include?(layout)
  abort 'usage: make_corpus.rb MESSAGES_FILE OUT_DIR game|secret [grille|shared-grille]'
end

passphrase = SecureRandom.base64(24) if mode == 'secret'
shared = Cistergraphia::Grille.generate if layout == 'shared-grille'
answers = {}
File.readlines(messages_file, chomp: true).reject(&:empty?).each_with_index do |message, i|
  name = format('c%02d.svg', i + 1)
  grille = shared || (Cistergraphia::Grille.generate if layout)
  _sequence, svg = Cistergraphia.inscribe(message, passphrase: passphrase, layout: grille || :phaistos)
  File.write(File.join(out_dir, name), svg)
  answers[name] = passphrase ? message : Cistergraphia.normalize(message)
end
File.write(File.join(out_dir, 'answers.json'), JSON.pretty_generate(answers))
puts "#{answers.size} #{mode} ciphertexts#{" under #{shared ? 'one grille' : 'grilles'}" if layout} in #{out_dir}"

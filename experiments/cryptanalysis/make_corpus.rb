# frozen_string_literal: true

# Generates a ciphertext corpus for the cryptanalysis experiment.
#
#   ruby make_corpus.rb MESSAGES_FILE OUT_DIR game|secret
#
# Writes c01.svg, c02.svg, ... (one per line of MESSAGES_FILE) and
# answers.json (what a perfect attack recovers: the normalized text in game
# mode, the exact text in secret mode). The secret-mode passphrase is random
# and thrown away: the attacker never has it.

require 'json'
require 'securerandom'
require_relative '../../lib/cistergraphia'

messages_file, out_dir, mode = ARGV
abort 'usage: make_corpus.rb MESSAGES_FILE OUT_DIR game|secret' unless out_dir && %w[game secret].include?(mode)

passphrase = SecureRandom.base64(24) if mode == 'secret'
answers = {}
File.readlines(messages_file, chomp: true).reject(&:empty?).each_with_index do |message, i|
  name = format('c%02d.svg', i + 1)
  File.write(File.join(out_dir, name), Cistergraphia.to_svg(Cistergraphia.encode(message, passphrase: passphrase)))
  answers[name] = passphrase ? message : Cistergraphia.normalize(message)
end
File.write(File.join(out_dir, 'answers.json'), JSON.pretty_generate(answers))
puts "#{answers.size} #{mode} ciphertexts in #{out_dir}"

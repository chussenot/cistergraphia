#!/usr/bin/env bash
# Runs the scripted ciphertext-only attacks against both modes, with and
# without a grille.
#
#   experiments/cryptanalysis/run.sh           # print the results
#   experiments/cryptanalysis/run.sh --check   # also fail unless the game is
#                                              # broken and secret mode is not
#
# Under a grille the game check asks for 80%, not 90%: the search for the
# grille has a step limit, and one plate in a few dozen needs more than it.
#
# Needs: Ruby + bundle install, Python 3, word lists (apt install wamerican wfrench).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/game" "$work/secret" "$work/game-grille" "$work/secret-grille"

game_check=() grille_check=() secret_check=()
if [[ "${1:-}" == "--check" ]]; then
  game_check=(--check-min-accuracy 0.9)
  grille_check=(--check-min-accuracy 0.8)
  secret_check=(--check-max-accuracy 0.1)
fi

bundle exec ruby "$here/make_corpus.rb" "$here/messages.txt" "$work/game" game
bundle exec ruby "$here/make_corpus.rb" "$here/messages.txt" "$work/secret" secret
bundle exec ruby "$here/make_corpus.rb" "$here/messages.txt" "$work/game-grille" game grille
bundle exec ruby "$here/make_corpus.rb" "$here/messages.txt" "$work/secret-grille" secret grille

echo; echo "##### GAME MODE (no passphrase) #####"
python3 -I "$here/crack.py" "$work/game" --answers "$work/game/answers.json" --subsets 1 3 10 "${game_check[@]}"

echo; echo "##### SECRET MODE (passphrase, AES-256-GCM) #####"
python3 -I "$here/crack.py" "$work/secret" --answers "$work/secret/answers.json" "${secret_check[@]}"

echo; echo "##### GAME MODE UNDER A GRILLE (each plate its own key; the attacker knows the scheme) #####"
python3 -I "$here/crack_grille.py" "$work/game-grille" --answers "$work/game-grille/answers.json" "${grille_check[@]}"

echo; echo "##### SECRET MODE UNDER A GRILLE #####"
python3 -I "$here/crack_grille.py" "$work/secret-grille" --answers "$work/secret-grille/answers.json" "${secret_check[@]}"

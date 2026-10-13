#!/usr/bin/env bash
# Runs the scripted ciphertext-only attack against both modes.
#
#   experiments/cryptanalysis/run.sh           # print the results
#   experiments/cryptanalysis/run.sh --check   # also fail unless the game is
#                                              # broken and secret mode is not
#
# Needs: Ruby + bundle install, Python 3, word lists (apt install wamerican wfrench).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/game" "$work/secret"

game_check=() secret_check=()
if [[ "${1:-}" == "--check" ]]; then
  game_check=(--check-min-accuracy 0.9)
  secret_check=(--check-max-accuracy 0.1)
fi

bundle exec ruby "$here/make_corpus.rb" "$here/messages.txt" "$work/game" game
bundle exec ruby "$here/make_corpus.rb" "$here/messages.txt" "$work/secret" secret

echo; echo "##### GAME MODE (no passphrase) #####"
python3 -I "$here/crack.py" "$work/game" --answers "$work/game/answers.json" --subsets 1 3 10 "${game_check[@]}"

echo; echo "##### SECRET MODE (passphrase, AES-256-GCM) #####"
python3 -I "$here/crack.py" "$work/secret" --answers "$work/secret/answers.json" "${secret_check[@]}"

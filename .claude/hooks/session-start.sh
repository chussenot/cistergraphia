#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: makes tests, lint, the CLI
# (PNG export) and the cryptanalysis experiment work from the first command.
# Idempotent and non-interactive; the container is cached after it runs.
set -euo pipefail

# Only in Claude Code cloud sessions; local machines manage their own setup
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

# --- System packages -----------------------------------------------------------
# librsvg2-bin: rsvg-convert, the CLI's SVG -> PNG converter (see README)
# wamerican, wfrench: word lists for experiments/cryptanalysis/crack.py
# pngquant, optipng: compress the documentation screenshots
packages=(librsvg2-bin wamerican wfrench pngquant optipng)
missing=()
for pkg in "${packages[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ "${#missing[@]}" -gt 0 ]; then
  sudo=""
  [ "$(id -u)" -ne 0 ] && sudo="sudo"
  export DEBIAN_FRONTEND=noninteractive
  $sudo apt-get update -qq
  $sudo apt-get install -y -qq --no-install-recommends "${missing[@]}" >/dev/null
  echo "Installed: ${missing[*]}"
fi

# --- Ruby gems -----------------------------------------------------------------
BUNDLE_SILENCE_ROOT_WARNING=1 bundle install --quiet

# --- Session environment ---------------------------------------------------------
# The gem executables (rake, rubocop, rackup) live in Ruby's gem bindir, which is
# not on this container's PATH. A UTF-8 locale keeps Ruby from reading source and
# input as US-ASCII.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  gem_bindir="$(ruby -e 'print Gem.bindir')"
  {
    echo "export PATH=\"${gem_bindir}:\$PATH\""
    echo 'export LANG=C.UTF-8'
    echo 'export LC_ALL=C.UTF-8'
  } >> "$CLAUDE_ENV_FILE"
fi

echo "Cistergraphia session ready: bundle exec rake test | bundle exec rubocop | experiments/cryptanalysis/run.sh"

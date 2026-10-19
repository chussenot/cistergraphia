#!/usr/bin/env python3
"""Known-scheme attack on Grille plates: everything public but the key.

Cistergraphia's code is public, so by Kerckhoffs's principle the attacker knows
the scheme and only the grille's key is secret. Known: the tablet (which pair
sums are letters), the padding marker (9999) and the turning grille's rules (an
n x n plate splits into n^2/4 orbits of four cells, one hole per orbit, turned
clockwise N, E, S, W, the holes read row by row). Unknown: which cell of each
orbit is pierced (4^(n^2/4) grilles, 2^50 keys).

The search scans the plate row by row. When it first meets a cell of an orbit
it tries the orbit's 4 holes; each choice fixes the turn at which all four of
the orbit's cells are read. The four quarters of the reading therefore grow in
order together, and each time a pair completes in one of them its sum must be a
letter (or the pair must end with the marker). A wrong branch dies within a
pair or two. The grille found may be the true one turned by quarters (it reads
the same cells, starting at another quarter): the four starts are tried and
the one that reads as words is kept.

With --shared-key the plates are taken to share one grille (the same key used
twice), and searched together: a branch must read letters on every plate.

Glyphs are read with crack.read_grid (public Cistercian numerals only).

Usage:
  crack_grille.py CORPUS_DIR [--answers answers.json] [--node-limit N]
                  [--words] [--shared-key]
                  [--check-min-accuracy 0.9 | --check-max-accuracy 0.1]
"""
import argparse
import bisect
import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import crack  # noqa: E402  (glyph reading and word lists; nothing from Cistergraphia)

# The public tablet: pair sum / 10 -> character
TABLET = dict(zip((1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19,
                   100, 200, 300, 400, 500, 600, 700, 800, 900), 'abcdefghijklmnopqrstuvwxyz '))
LETTERS = {10 * value for value in TABLET}
MARKER = 9999


def orbits(n):
    """Each cell of the top-left quarter, then where quarter turns clockwise take it"""
    out = []
    for r in range(n // 2):
        for c in range(n // 2):
            orbit = [(r, c)]
            for _ in range(3):
                row, col = orbit[-1]
                orbit.append((col, n - 1 - row))
            out.append(orbit)
    return out


def reading(grid, n, holes):
    """The values in the grille's order: holes at N row by row, then E, S, W"""
    seq = []
    for turn in range(4):
        seq += [grid[cell] for cell in sorted(o[(k + turn) % 4] for o, k in zip(orbits(n), holes))]
    return seq


def pair_ok(a, b):
    return a + b in LETTERS or b == MARKER


class Lexicon:
    """Words, to tell text from noise as the letters come: a quarter of the
    reading starts anywhere in a word, so its first fragment is not checked;
    after that, each word must be in the lists, but a few may not be (names,
    rare words): up to `misses` for the whole plate"""

    def __init__(self, words, misses=3):
        self.sorted = sorted(words)
        self.words = words
        self.misses = misses

    def is_prefix(self, fragment):
        i = bisect.bisect_left(self.sorted, fragment)
        return i < len(self.sorted) and self.sorted[i].startswith(fragment)


def search(grids, n, node_limit, lexicon=None, accept=lambda holes: True):
    """A grille under which every pair of every plate reads as a letter (and,
    with a lexicon, the letters as words), or None. On short plates such a
    grille can be false (letters, not text): `accept` judges each one found,
    and the search goes on past those it rejects. Returns (holes, nodes)"""
    orbs = orbits(n)
    where = {cell: (i, j) for i, orbit in enumerate(orbs) for j, cell in enumerate(orbit)}
    cells = [(r, c) for r in range(n) for c in range(n)]
    quarter = n * n // 4
    holes = [None] * len(orbs)
    # Per quarter, the cells read so far: their values on every plate. Per
    # plate and quarter: (seen a space yet, the word being read, it is already
    # a miss); misses so far, all plates together
    values = {cell: tuple(grid[cell] for grid in grids) for cell in cells}
    quarters = [[], [], [], []]
    words = [[(False, '', False)] * 4 for _ in grids]
    history = []
    misses = [0]
    nodes = 0

    def read_letter(g, turn, letter):
        """Follow the words of a quarter; False when too many are not words"""
        spaced, word, missed = words[g][turn]
        history.append((g, turn, words[g][turn], misses[0]))
        if letter == ' ':
            if spaced and word and not missed and word not in lexicon.words:
                misses[0] += 1
            words[g][turn] = (True, '', False)
        else:
            word += letter
            if spaced and not missed and not lexicon.is_prefix(word):
                misses[0] += 1
                missed = True
            words[g][turn] = (spaced, word, missed)
        return misses[0] <= lexicon.misses

    def unread():
        g, turn, state, count = history.pop()
        words[g][turn] = state
        misses[0] = count

    def place(turn, cell):
        """Read `cell` at `turn` on every plate; False if it completes a pair
        that is no letter (or no word) on one of them"""
        q = quarters[turn]
        now = values[cell]
        if (turn * quarter + len(q)) % 2 == 1 and q:
            if not all(map(pair_ok, q[-1], now)):
                return False
            followed = 0
            for g, (before, value) in enumerate(zip(q[-1], now)):
                if lexicon and value != MARKER:
                    followed += 1
                    if not read_letter(g, turn, TABLET[(before + value) // 10]):
                        for _ in range(followed):
                            unread()
                        return False
        q.append(now)
        return True

    def take_back(turn):
        q = quarters[turn]
        now = q.pop()
        if lexicon and (turn * quarter + len(q)) % 2 == 1 and q:
            for _ in range(sum(value != MARKER for value in now)):
                unread()

    def whole_reading_ok():  # also the pairs across two quarters (odd quarters)
        cells_read = quarters[0] + quarters[1] + quarters[2] + quarters[3]
        return all(all(map(pair_ok, a, b)) for a, b in zip(cells_read[::2], cells_read[1::2]))

    def scan(i):
        nonlocal nodes
        nodes += 1
        if nodes > node_limit:
            raise TimeoutError
        if i == len(cells):
            return whole_reading_ok() and accept(holes)
        cell = cells[i]
        orbit, position = where[cell]
        fresh = holes[orbit] is None
        for hole in (range(4) if fresh else [holes[orbit]]):
            turn = (position - hole) % 4  # the turn that brings a hole over this cell
            holes[orbit] = hole
            if place(turn, cell):
                if scan(i + 1):
                    return True
                take_back(turn)
        if fresh:
            holes[orbit] = None
        return False

    sys.setrecursionlimit(max(10000, 4 * len(cells)))
    try:
        found = scan(0)
    except TimeoutError:
        found = False
    return (holes[:] if found else None), nodes


def read_message(grid, n, holes):
    values = crack.strip_marker(reading(grid, n, holes), MARKER, 'prev')
    return ''.join(TABLET.get((a + b) // 10, '?') for a, b in zip(values[::2], values[1::2]))


def best_start(grid, n, holes, words):
    """The grille turned by 0 to 3 quarters reads the same cells from another
    start: keep the start that reads as the most words"""
    def score(text):
        return sum(len(w) ** 2 for w in text.split() if w in words)
    starts = [read_message(grid, n, [(k + s) % 4 for k in holes]) for s in range(4)]
    return max(starts, key=score)


def reads_as_text(grids, n, holes, words, share=0.8):
    """Whether the readings are text: at least `share` of their letters in
    dictionary words (a false grille reads letters, rarely words)"""
    texts = [best_start(grid, n, holes, words) for grid in grids]
    letters = sum(len(w) for text in texts for w in text.split())
    known = sum(len(w) for text in texts for w in text.split() if w in words)
    return letters > 0 and known >= share * letters


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('corpus')
    parser.add_argument('--answers', help='JSON {file name: plaintext}, to score the attack')
    parser.add_argument('--node-limit', type=int, default=200_000_000)
    parser.add_argument('--words', action='store_true',
                        help='also prune with the word lists (letters must make words, a few misses allowed)')
    parser.add_argument('--shared-key', action='store_true',
                        help='the plates share one grille: search them together (they must be the same size)')
    parser.add_argument('--check-min-accuracy', type=float)
    parser.add_argument('--check-max-accuracy', type=float)
    args = parser.parse_args()

    paths = sorted(glob.glob(os.path.join(args.corpus, '*.svg')))
    answers = json.load(open(args.answers)) if args.answers else {}
    words = crack.load_words()
    lexicon = Lexicon(words) if args.words else None
    plain, truth = {}, {}
    groups = [paths] if args.shared_key else [[path] for path in paths]
    for group in groups:
        grids = [crack.read_grid(path) for path in group]
        n = grids[0][1]
        if any(size != n for _, size in grids):
            sys.exit('--shared-key needs plates of one size')
        start = time.time()
        plates = [grid for grid, _ in grids]
        holes, nodes = search(plates, n, args.node_limit, lexicon,
                              accept=lambda holes: reads_as_text(plates, n, holes, words))
        found = 'grille found' if holes else 'no grille found'
        took = f"{n}x{n}: {found} after {nodes:,} nodes, {time.time() - start:.1f} s"
        if args.shared_key:
            print(f"  {len(group)} plates under one grille, {took}")
        for path, (grid, _) in zip(group, grids):
            name = os.path.basename(path)
            plain[name] = best_start(grid, n, holes, words) if holes else ''
            truth[name] = answers.get(name, '')
            verdict = 'OK ' if answers and plain[name] == truth[name] else '   '
            where = name if args.shared_key else f"{name} {took}"
            print(f"  {verdict} {where}  {plain[name]}", flush=True)

    last = None
    if answers:
        last = crack.accuracy(list(plain.values()), list(truth.values()))
        print(f"  character accuracy: {last:.1%}; messages fully recovered: "
              f"{sum(plain[name] == truth[name] for name in truth)}/{len(truth)}")
    if args.check_min_accuracy is not None and (last is None or last < args.check_min_accuracy):
        sys.exit(f"CHECK FAILED: accuracy {last} < {args.check_min_accuracy}")
    if args.check_max_accuracy is not None and (last is None or last > args.check_max_accuracy):
        sys.exit(f"CHECK FAILED: accuracy {last} > {args.check_max_accuracy}")


if __name__ == '__main__':
    main()

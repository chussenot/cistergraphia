#!/usr/bin/env python3
"""Ciphertext-only attack on Cistergraphia SVGs.

Uses no code, tables or constants from the Cistergraphia implementation. Its
only inputs are SVG files. Prior knowledge used:
  - the standard Cistercian numeral glyphs (public, e.g. Wikipedia or dCode)
  - English and French word lists (/usr/share/dict, packages wamerican/wfrench)
Everything else (symbol size, reading order, padding marker, pairing,
character mapping) is inferred from the ciphertexts.

Usage:
  crack.py CORPUS_DIR [--answers answers.json] [--subsets 1 3 10]
           [--check-min-accuracy 0.9 | --check-max-accuracy 0.1]
"""
import argparse
import collections
import functools
import glob
import itertools
import json
import math
import os
import random
import statistics
import sys
import unicodedata
import xml.etree.ElementTree as ET

# --- 1. Glyph recognition (public Cistercian numeral standard) --------------
# Strokes of the units digits in "cell units": stem at x=0, cell is [0,1]x[0,1].
PRIMITIVES = {
    ((0, 0), (1, 0)): 'A',  # top bar          -> 1
    ((0, 1), (1, 1)): 'B',  # lower bar        -> 2
    ((0, 0), (1, 1)): 'C',  # diagonal down    -> 3
    ((0, 1), (1, 0)): 'D',  # diagonal up      -> 4
    ((1, 0), (1, 1)): 'E',  # outer vertical   -> 6
}
DIGITS = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'AD': 5, 'E': 6, 'AE': 7, 'BE': 8, 'ABE': 9}
PLACES = {(True, True): 1, (False, True): 10, (True, False): 100, (False, False): 1000}


def read_lines(path):
    root = ET.parse(path).getroot()
    return [tuple(float(el.get(k)) for k in ('x1', 'y1', 'x2', 'y2'))
            for el in root.iter() if el.tag.split('}')[-1] == 'line']


def read_grid(path):
    """SVG -> ({(row, col): value}, side), learning the symbol geometry from the drawing."""
    lines = read_lines(path)
    verticals = [l for l in lines if abs(l[0] - l[2]) < 1e-6]
    stem_len = max(abs(l[3] - l[1]) for l in verticals)  # stems are the longest strokes
    stems = [l for l in verticals if abs(abs(l[3] - l[1]) - stem_len) < 1e-6]
    unit = statistics.median(abs(l[2] - l[0]) for l in lines if abs(l[1] - l[3]) < 1e-6)
    height = stem_len / unit

    strokes = collections.defaultdict(list)
    stem_ids = {id(s) for s in stems}
    for l in lines:
        if id(l) in stem_ids:
            continue
        mx, my = (l[0] + l[2]) / 2, (l[1] + l[3]) / 2
        owner = min((s for s in stems if min(s[1], s[3]) - 1 <= my <= max(s[1], s[3]) + 1
                     and abs(mx - s[0]) <= unit + 1), key=lambda s: abs(mx - s[0]))
        strokes[id(owner)].append(l)

    xs = sorted({s[0] for s in stems})
    ys = sorted({min(s[1], s[3]) for s in stems})
    grid = {}
    for s in stems:
        top = min(s[1], s[3])
        quads = collections.defaultdict(str)
        for x1, y1, x2, y2 in strokes[id(s)]:
            rel = [((x - s[0]) / unit, (y - top) / unit) for x, y in ((x1, y1), (x2, y2))]
            right = (rel[0][0] + rel[1][0]) > 0
            upper = (rel[0][1] + rel[1][1]) / 2 < height / 2
            norm = tuple(sorted((round(abs(x)), round(y if upper else height - y)) for x, y in rel))
            quads[PLACES[(right, upper)]] += PRIMITIVES[norm]
        grid[(ys.index(top), xs.index(s[0]))] = sum(DIGITS[''.join(sorted(p))] * place for place, p in quads.items())
    return grid, len(xs)


# --- 2. Reading order: try every classic route, keep the ones with structure --
@functools.lru_cache(maxsize=None)
def orders(n):
    row = [(r, c) for r in range(n) for c in range(n)]
    snake = [(r, c if r % 2 == 0 else n - 1 - c) for r in range(n) for c in range(n)]
    spiral, m = [], [[(r, c) for c in range(n)] for r in range(n)]
    while m:
        spiral += m[0]
        m = [list(x) for x in zip(*m[1:])][::-1]
    # The Zodiac's diagonal: one down, two across, wrapping; a new start per orbit
    leap = [(i, (s + 2 * i) % n) for s in range(n) for i in range(n)]
    symmetries = {
        'id': lambda r, c: (r, c), 'transpose': lambda r, c: (c, r),
        'flip-h': lambda r, c: (r, n - 1 - c), 'flip-v': lambda r, c: (n - 1 - r, c),
        'rot180': lambda r, c: (n - 1 - r, n - 1 - c), 'rot90': lambda r, c: (c, n - 1 - r),
        'rot270': lambda r, c: (n - 1 - c, r), 'anti-transpose': lambda r, c: (n - 1 - c, n - 1 - r),
    }
    out = {}
    bases = {'row-major': row, 'boustrophedon': snake, 'spiral': spiral, 'leap': leap}
    for (bname, base), (sname, f), rev in itertools.product(bases.items(), symmetries.items(), (False, True)):
        seq = [f(r, c) for r, c in base]
        out[f"{bname}/{sname}{'/reversed' if rev else ''}"] = seq[::-1] if rev else seq
    return out


def strip_marker(seq, marker, side):
    """Drop each marker and the value next to it (on `side`)."""
    if side == 'next':
        return strip_marker(seq[::-1], marker, 'prev')[::-1]
    out = []
    for v in seq:
        if v != marker:
            out.append(v)
        elif out:
            out.pop()
    return out


def pair_score(values):
    if len(values) % 2:
        return 0.0
    pairs = list(zip(values[::2], values[1::2]))
    return sum((a + b) % 10 == 0 for a, b in pairs) / len(pairs)


# --- 3. Substitution: dictionary-scored search --------------------------------
def load_words():
    words = set()
    for path in ('/usr/share/dict/american-english', '/usr/share/dict/french'):
        if not os.path.exists(path):
            continue
        for w in open(path, encoding='utf-8', errors='ignore'):
            w = unicodedata.normalize('NFKD', w.strip().lower())
            w = ''.join(ch for ch in w if 'a' <= ch <= 'z')
            if w:
                words.add(w)
    if not words:
        sys.exit('No word list found: install wamerican and wfrench')
    return words


EN_FREQ = 'etaoinsrhldcumfpgwybvkxjqz'


def split_words(tokens, space):
    words, word = [], []
    for t in tokens + [space]:
        if t == space:
            if word:
                words.append(tuple(word))
            word = []
        else:
            word.append(t)
    return words


def make_scorer(cipher_words, words):
    def score(key):
        total = 0
        for w in cipher_words:
            plain = ''.join(key[t] for t in w)
            if plain in words:
                total += len(plain) ** 2
        return total
    return score


def generic_solver(letters, score, rng, restarts=30, steps=6000):
    """Simulated annealing over all substitutions (no assumption on the table)."""
    best_key, best = None, -1
    for restart in range(restarts):
        alphabet = list(EN_FREQ)
        if restart:
            rng.shuffle(alphabet)
        key = dict(zip(letters, alphabet))
        current, temp = score(key), 4.0
        for _ in range(steps):
            t, new = rng.choice(letters), rng.choice(EN_FREQ)
            other = next((k for k, v in key.items() if v == new), None)
            old = key[t]
            key[t] = new
            if other is not None:
                key[other] = old
            s = score(key)
            if s >= current or rng.random() < math.exp((s - current) / temp):
                current = s
            else:
                key[t] = old
                if other is not None:
                    key[other] = new
            temp = max(0.05, temp * 0.999)
        if current > best:
            best, best_key = current, dict(key)
    return best_key, best


def monotone_solver(letters, score, rng, restarts=20, steps=4000):
    """Hypothesis spotted by the blind LLM: larger value = later letter.
    Search increasing maps from the sorted values onto a..z (only gaps vary)."""
    tokens = sorted(letters)
    k = len(tokens)
    if k > 26:
        return None, -1

    def key_of(pos):
        return {t: chr(97 + p) for t, p in zip(tokens, pos)}

    best_key, best = None, -1
    for restart in range(restarts):
        pos = list(range(k)) if restart == 0 else sorted(rng.sample(range(26), k))
        current = score(key_of(pos))
        for _ in range(steps):
            i, delta = rng.randrange(k), rng.choice((-1, 1))
            cand = pos[:]
            if rng.random() < 0.5:
                cand[i:] = [p + delta for p in cand[i:]]  # shift a block: opens or closes a gap
            else:
                cand[i] += delta
            if cand[0] < 0 or cand[-1] > 25 or any(a >= b for a, b in zip(cand, cand[1:])):
                continue
            s = score(key_of(cand))
            if s >= current:
                pos, current = cand, s
        if current > best:
            best, best_key = current, key_of(pos)
    return best_key, best


def solve_substitution(messages, words, seed=1, quick=False):
    tokens = collections.Counter(t for m in messages for t in m)
    space = tokens.most_common(1)[0][0]
    letters = [t for t, _ in tokens.most_common() if t != space]
    score = make_scorer([w for m in messages for w in split_words(m, space)], words)
    rng = random.Random(seed)
    scale = 4 if quick else 1
    results = {
        'monotone': monotone_solver(letters, score, rng, restarts=20 // scale, steps=4000 // scale),
        'generic': generic_solver(letters, score, rng, restarts=30 // scale, steps=6000 // scale),
    }
    name, (key, best) = max(results.items(), key=lambda kv: kv[1][1])
    key = dict(key or {})
    key[space] = ' '
    return key, space, best, name


# --- 4. The attack ------------------------------------------------------------
def crack(paths, words, log=print):
    grids = [read_grid(p) for p in paths]
    counts = collections.Counter(v for g, _ in grids for v in g.values())
    marker, marker_count = counts.most_common(1)[0]
    log(f"[glyphs] read {sum(len(g) for g, _ in grids)} symbols in {len(grids)} file(s); most frequent value "
        f"{marker} (x{marker_count}) -> padding-marker hypothesis")

    candidates = []
    for side in ('prev', 'next'):
        for name in orders(grids[0][1]):
            total = sum(pair_score(strip_marker([g[rc] for rc in orders(n)[name]], marker, side)) for g, n in grids)
            candidates.append((total / len(grids), name, side))
    candidates.sort(reverse=True)
    top = candidates[0][0]
    log(f"[order] {len(candidates)} (route, marker-side) hypotheses; best: {top:.0%} of pairs sum to a "
        f"multiple of 10 (chance: 10%)")
    if top < 0.5:
        log("[order] no route shows the pair structure -> attack stops: nothing to decipher")
        return [''] * len(paths)

    def decode_with(name, side):
        msgs = []
        for g, n in grids:
            values = strip_marker([g[rc] for rc in orders(n)[name]], marker, side)
            msgs.append([a + b for a, b in zip(values[::2], values[1::2])])
        return msgs

    tied = [c for c in candidates if c[0] == top]
    _, order_name, side = max(tied, key=lambda c: solve_substitution(decode_with(c[1], c[2]), words, quick=True)[2])
    log(f"[order] {len(tied)} route(s) tie; language picks {order_name}, marker drops the {side} value")

    messages = decode_with(order_name, side)
    log(f"[pairs] {sum(map(len, messages))} characters, {len({t for m in messages for t in m})} distinct pair sums")
    key, space, _, solver = solve_substitution(messages, words)
    log(f"[substitution] space = {space} (most frequent sum); best solver: {solver}")
    return [''.join(key.get(t, '?') for t in m) for m in messages]


def accuracy(plain, truth):
    chars = sum(len(t) for t in truth)
    right = sum(a == b for p, t in zip(plain, truth) for a, b in zip(p, t))
    return right / chars if chars else 0.0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('corpus')
    parser.add_argument('--answers', help='JSON {file name: plaintext}, to score the attack')
    parser.add_argument('--subsets', type=int, nargs='+', help='attack the first N files, for each N')
    parser.add_argument('--check-min-accuracy', type=float)
    parser.add_argument('--check-max-accuracy', type=float)
    args = parser.parse_args()

    paths = sorted(glob.glob(os.path.join(args.corpus, '*.svg')))
    answers = json.load(open(args.answers)) if args.answers else {}
    words = load_words()
    last = None
    for k in args.subsets or [len(paths)]:
        subset = paths[:k]
        print(f"\n=== {len(subset)} ciphertext(s) ===")
        plain = crack(subset, words)
        truth = [answers.get(os.path.basename(p), '') for p in subset]
        for p, t in zip(plain, truth):
            print(f"  {'OK ' if answers and p == t else '   '} {p}")
        if answers:
            last = accuracy(plain, truth)
            print(f"  character accuracy: {last:.1%}; messages fully recovered: "
                  f"{sum(p == t for p, t in zip(plain, truth))}/{len(truth)}")

    if args.check_min_accuracy is not None and (last is None or last < args.check_min_accuracy):
        sys.exit(f"CHECK FAILED: accuracy {last} < {args.check_min_accuracy}")
    if args.check_max_accuracy is not None and (last is None or last > args.check_max_accuracy):
        sys.exit(f"CHECK FAILED: accuracy {last} > {args.check_max_accuracy}")


if __name__ == '__main__':
    main()

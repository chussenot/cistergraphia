// Cistergraphia ways: the five reading orders a plate can run (docs/design.md,
// "Find the path"), as the library draws them (Cistergraphia::Layout), so a
// pathless plate's desk can lay each way over the grid and read along it.
// Pure: no DOM. test/ways_test.rb checks every size against the library.
(() => {
  'use strict';

  const NAMES = ['phaistos', 'rongorongo', 'leap', 'furrows', 'unwinding'];

  // The snail: clockwise from the top-left corner to the centre (the first row,
  // then the rest turned a quarter and peeled again)
  function snail(rows) {
    if (!rows.length) return [];
    const [first, ...rest] = rows;
    const turned = rest.length ? rest[0].map((_, c) => rest.map((row) => row[c])).reverse() : [];
    return first.concat(snail(turned));
  }
  const spiral = (n) => snail(Array.from({ length: n }, (_, r) => Array.from({ length: n }, (_, c) => [r, c])));

  const WAYS = {
    phaistos: (n) => spiral(n).map(([r, c]) => [r, c, false]),
    // The turning tablet: rows from the bottom, every other one turned half round
    rongorongo: (n) => Array.from({ length: n }, (_, k) => n - 1 - k).flatMap((r, k) => {
      const cols = Array.from({ length: n }, (_, c) => (k % 2 ? n - 1 - c : c));
      return cols.map((c) => [r, c, k % 2 === 1]);
    }),
    // The leap: one down, two across, wrapping; a new start a column to the right when the orbit closes
    leap: (n) => Array.from({ length: n }, (_, s) => s).flatMap((s) => Array.from({ length: n }, (_, i) => [i, (s + (2 * i)) % n, false])),
    // The furrows: down the first column, up the next, from the left
    furrows: (n) => Array.from({ length: n }, (_, c) => c).flatMap((c) => {
      const rows = Array.from({ length: n }, (_, r) => (c % 2 ? n - 1 - r : r));
      return rows.map((r) => [r, c, false]);
    }),
    // The unwinding: the snail turned a quarter and read backwards, from the centre outward
    unwinding: (n) => spiral(n).map(([r, c]) => [c, n - 1 - r, false]).reverse()
  };

  // [row, col, turned] of every sign along a way, in reading order
  function path(size, way) {
    if (!WAYS[way]) throw new Error(`Unknown way ${way}`);
    return WAYS[way](size);
  }

  const ways = { NAMES, path };
  if (typeof module !== 'undefined' && module.exports) module.exports = ways;
  if (typeof window !== 'undefined') window.Ways = ways;
})();

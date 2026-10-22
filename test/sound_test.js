// The sounds of silence: the pure part of public/js/sound.js, what a sound is
// from what made it. Run: node --test test/sound_test.js (or bundle exec rake test:sound)
const test = require('node:test');
const assert = require('node:assert/strict');
const { seedOf, biteParams, placeOf, headOf, BELL, MIN_GAP } = require('../public/js/sound.js');

test('a stroke always seeds the same, and different strokes differ', () => {
  assert.equal(seedOf('0,0,0,150'), seedOf('0,0,0,150'));
  assert.notEqual(seedOf('0,0,0,150'), seedOf('0,0,50,0'));
  for (const key of ['0,0,0,150', '0,0,50,0', '50,0,50,50']) {
    const seed = seedOf(key);
    assert.ok(seed >= 0 && seed < 1, `${key} seeds in [0, 1)`);
  }
});

test('a short stroke bites bright and brief, the stem duller and longer', () => {
  const stem = biteParams([0, 0, 0, 150], 0.5);
  const corner = biteParams([0, 0, 50, 0], 0.5);
  assert.ok(corner.centre > stem.centre, 'brighter');
  assert.ok(corner.duration < stem.duration, 'briefer');
  assert.ok(stem.duration <= 0.009 && corner.duration >= 0.004, 'four to eight milliseconds');
  assert.ok(stem.knock >= 120 && stem.knock <= 180, 'a low knock');
});

test('the seed moves a bite a little, never out of its band', () => {
  const low = biteParams([0, 0, 50, 0], 0);
  const high = biteParams([0, 0, 50, 0], 0.999);
  assert.ok(high.centre - low.centre > 100 && high.centre - low.centre < 400);
  assert.ok(Math.abs(high.duration - low.duration) < 0.002);
});

test('the hand is heard where it is: pan by column within ±0.6, depth by row', () => {
  const layout = { padding: 20, cell: [120, 170], offset: -10, size: 4 };
  const at = (col, row) => placeOf({ x: 20 - 10 + (col * 120) + 60, y: 20 - 10 + (row * 170) + 80 }, layout);
  assert.ok(at(0, 0).pan < 0 && at(3, 0).pan > 0, 'left to right');
  assert.equal(at(0, 0).pan, -at(3, 0).pan, 'symmetrical');
  assert.ok(Math.abs(at(3, 0).pan) <= 0.6, 'never hard right');
  assert.equal(at(0, 0).depth, 0, 'the top row is nearest');
  assert.equal(at(0, 3).depth, 1, 'the bottom row is furthest');
  assert.ok(at(1, 1).depth > 0 && at(1, 1).depth < 1);
});

test('a one-sign plate is heard in the centre', () => {
  const layout = { padding: 20, cell: [120, 170], offset: -10, size: 1 };
  assert.deepEqual(placeOf({ x: 70, y: 95 }, layout), { pan: 0, depth: 0 });
});

test('a wedge head is read from its outline, as ink.js reads it', () => {
  const wedge = 'M6 0L14 7L6 14L7 7ZM6 4L50 7L6 10Z'; // the head's four corners, the tail's three points
  assert.deepEqual(headOf(wedge), { x: 6, y: 7 });
  assert.equal(headOf('M0 0L10 10Z'), null, 'not a wedge');
});

test('the bell is one bronze voice: five partials, the prime loudest, the hum longest', () => {
  assert.equal(BELL.length, 5);
  const [hum, prime] = BELL;
  assert.equal(prime[0], 1);
  assert.ok(BELL.every(([, level]) => level <= prime[1]));
  assert.ok(BELL.every(([, , decay]) => decay <= hum[2]));
});

test('bites are thinned to a patter: at most twenty-five a second', () => {
  assert.ok(1 / MIN_GAP <= 25);
});

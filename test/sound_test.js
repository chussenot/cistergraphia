// The sounds of silence: the pure part of public/js/sound.js, what a sound is
// from what made it. Run: node --test test/sound_test.js (or bundle exec rake test:sound)
const test = require('node:test');
const assert = require('node:assert/strict');
const { seedOf, noiseOf, biteParams, placeOf, headOf, BELL, MIN_GAP, LEVELS, softClip } = require('../public/js/sound.js');

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

test('the guard on the sum: untouched below -6 dBFS, rounded above, never full scale', () => {
  for (const x of [0, 0.1, -0.25, 0.5, -0.5]) assert.equal(softClip(x), x, `${x} passes untouched`);
  let last = -Infinity;
  for (let x = -4; x <= 4; x += 0.01) {
    const y = softClip(x);
    assert.ok(y >= last, 'never folds back');
    assert.ok(Math.abs(y) < 1, `${x.toFixed(2)} stays under full scale`);
    assert.equal(Math.sign(y), Math.sign(x) || Math.sign(y));
    last = y;
  }
  assert.ok(softClip(0.6) < 0.6 && softClip(0.6) > 0.55, 'rounded off gently');
});

test('every part of every sound has a level, and the bite is carried by its tick', () => {
  for (const part of ['tick', 'knock', 'lift', 'thud', 'ring', 'turn', 'parchment', 'bell', 'strike']) {
    assert.ok(LEVELS[part] > 0 && Number.isFinite(LEVELS[part]), part);
  }
  // A laptop's or phone's speaker gives nothing of the knock (120 to 180 Hz):
  // the tick is what is heard of a bite, and must lead it
  assert.ok(LEVELS.tick > 10 * LEVELS.knock, 'the tick leads the knock by more than 20 dB');
});

test('the noise is the same on every page, white, and within [-1, 1)', () => {
  const a = noiseOf(48000);
  assert.deepEqual(noiseOf(48000), a);
  let sum = 0;
  let squares = 0;
  for (const v of a) {
    assert.ok(v >= -1 && v < 1);
    sum += v;
    squares += v * v;
  }
  assert.ok(Math.abs(sum / a.length) < 0.01, 'centred');
  assert.ok(Math.abs((squares / a.length) - (1 / 3)) < 0.01, 'the power of uniform white noise');
});

test('a stroke bites from its own grain of the noise, the same every time', () => {
  const seed = seedOf('50,0,50,150');
  assert.equal(biteParams([50, 0, 50, 150], seed).grain, biteParams([50, 0, 50, 150], seed).grain);
  assert.ok(biteParams([0, 0, 0, 150], 0.999).grain < 0.9, 'within the second of noise');
});

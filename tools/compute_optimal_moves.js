#!/usr/bin/env node
/*
 * Computes the optimal (minimum) number of moves for every built-in level and
 * writes entry/src/main/resources/rawfile/optimal_moves.json.
 *
 * The Android app computes this at runtime with the DriftingDroids solver and
 * uses it for the star rating. The HarmonyOS port ships a precomputed table
 * instead. Levels that store `num_moves:` (level 140) use that value, like the
 * Android app does with its predefined solution.
 *
 * Usage: node tools/compute_optimal_moves.js
 */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const MAPS_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/Maps');
const OUT_FILE = path.join(ROOT, 'entry/src/main/resources/rawfile/optimal_moves.json');
const LEVEL_COUNT = 140;
const COLOR = { r: 0, g: 1, b: 2, y: 3 };

function parseLevel(text) {
  const level = { width: 14, height: 14, h: [], v: [], robots: [-1, -1, -1, -1], targetColor: -1, tx: 0, ty: 0, numMoves: -1 };
  const entries = [];
  for (const raw of text.split(/[;\n]/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const colon = line.indexOf(':');
    const digit = line.search(/\d/);
    if (colon !== -1 && (digit === -1 || colon < digit)) {
      entries.push([line.slice(0, colon).trim(), line.slice(colon + 1).trim()]);
    } else if (digit !== -1) {
      entries.push([line.slice(0, digit).trim(), line.slice(digit).trim()]);
    }
  }
  for (const [type, data] of entries) {
    if (type === 'board') {
      const p = data.split(',');
      level.width = parseInt(p[0], 10);
      level.height = parseInt(p[1], 10);
    }
  }
  for (const [type, data] of entries) {
    const p = data.split(',').map((s) => parseInt(s, 10));
    if (type === 'h' || type === 'mh') level.h.push(p);
    else if (type === 'v' || type === 'mv') level.v.push(p);
    else if (type.length === 2 && type[0] === 't') { level.targetColor = type[1] === 'm' ? -1 : COLOR[type[1]]; level.tx = p[0]; level.ty = p[1]; }
    else if (type.length === 2 && type[0] === 'r' && COLOR[type[1]] !== undefined) level.robots[COLOR[type[1]]] = p[1] * level.width + p[0];
    else if (type === 'num_moves') level.numMoves = parseInt(data, 10);
  }
  return level;
}

/** Open-addressing hash set of uint32 keys (0 is never a valid key). */
class U32Set {
  constructor(bits) { this.mask = (1 << bits) - 1; this.table = new Uint32Array(1 << bits); this.size = 0; this.limit = (1 << bits) * 0.7; }
  add(key) {
    let i = (Math.imul(key, 0x9e3779b1) >>> 0) & this.mask;
    const t = this.table;
    while (t[i] !== 0) { if (t[i] === key) return false; i = (i + 1) & this.mask; }
    t[i] = key; this.size++;
    if (this.size > this.limit) throw new Error('hash set full');
    return true;
  }
}

function solve(level, maxStates) {
  const W = level.width, H = level.height, N = W * H;
  const hw = new Uint8Array(W * (H + 1)); // wall on top edge of (x,y)
  const vw = new Uint8Array((W + 1) * H); // wall on left edge of (x,y)
  for (const [x, y] of level.h) if (x >= 0 && x < W && y >= 0 && y <= H) hw[y * W + x] = 1;
  for (const [x, y] of level.v) if (x >= 0 && x <= W && y >= 0 && y < H) vw[y * (W + 1) + x] = 1;
  // stepOk[d][cell]: robot may step from cell in direction d (N,E,S,W) ignoring robots
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0], DELTA = [-W, 1, W, -1];
  const stepOk = [0, 1, 2, 3].map((d) => {
    const a = new Uint8Array(N);
    for (let c = 0; c < N; c++) {
      const x = c % W, y = (c / W) | 0, nx = x + DX[d], ny = y + DY[d];
      if (nx < 0 || nx >= W || ny < 0 || ny >= H) continue;
      if (d === 0 && hw[y * W + x]) continue;
      if (d === 2 && hw[(y + 1) * W + x]) continue;
      if (d === 1 && vw[y * (W + 1) + x + 1]) continue;
      if (d === 3 && vw[y * (W + 1) + x]) continue;
      a[c] = 1;
    }
    return a;
  });

  const tc = level.targetColor;
  const goal = level.ty * W + level.tx;
  // Robot order in state: index 0 = target robot (or robot 0 for multi), 1..3 = other robots sorted.
  const main = tc >= 0 ? tc : 0;
  const others = [0, 1, 2, 3].filter((i) => i !== main).map((i) => level.robots[i]);
  const multi = tc < 0;
  const encode = (m, a, b, c) => {
    // sort a,b,c
    let t;
    if (a > b) { t = a; a = b; b = t; }
    if (b > c) { t = b; b = c; c = t; }
    if (a > b) { t = a; a = b; b = t; }
    return ((m << 24) | (a << 16) | (b << 8) | c) >>> 0;
  };
  const isGoal = (p) => (multi ? (p[0] === goal || p[1] === goal || p[2] === goal || p[3] === goal) : p[0] === goal);

  const start = [level.robots[main], others[0], others[1], others[2]];
  if (isGoal(start)) return 0;
  const seen = new U32Set(26);
  let frontier = new Uint32Array([encode(start[0], start[1], start[2], start[3])]);
  seen.add(frontier[0]);
  const pos = [0, 0, 0, 0];
  for (let depth = 1; depth <= 40; depth++) {
    let next = new Uint32Array(Math.max(1024, frontier.length * 8));
    let n = 0;
    for (let f = 0; f < frontier.length; f++) {
      const k = frontier[f];
      pos[0] = k >>> 24; pos[1] = (k >>> 16) & 255; pos[2] = (k >>> 8) & 255; pos[3] = k & 255;
      for (let r = 0; r < 4; r++) {
        const from = pos[r];
        for (let d = 0; d < 4; d++) {
          const ok = stepOk[d], delta = DELTA[d];
          let c = from;
          while (ok[c]) {
            const nc = c + delta;
            if (nc === pos[0] || nc === pos[1] || nc === pos[2] || nc === pos[3]) break;
            c = nc;
          }
          if (c === from) continue;
          pos[r] = c;
          if (isGoal(pos)) return depth;
          const key = encode(pos[0], pos[1], pos[2], pos[3]);
          pos[r] = from;
          if (seen.add(key)) {
            if (n === next.length) { const g = new Uint32Array(next.length * 2); g.set(next); next = g; }
            next[n++] = key;
          }
        }
      }
    }
    if (n === 0) return -1;
    if (seen.size > maxStates) return -2;
    frontier = next.subarray(0, n);
  }
  return -1;
}

const result = [];
for (let id = 1; id <= LEVEL_COUNT; id++) {
  const level = parseLevel(fs.readFileSync(path.join(MAPS_DIR, `level_${id}.txt`), 'utf8'));
  const t0 = Date.now();
  let moves;
  if (level.numMoves > 0) moves = level.numMoves;
  else if (level.width > 16 || level.height > 16) moves = -1;
  else moves = solve(level, 40000000);
  result.push(moves);
  console.log(`level_${id}: ${moves} (${Date.now() - t0} ms)`);
}
fs.writeFileSync(OUT_FILE, JSON.stringify(result) + '\n');
console.log(`wrote ${OUT_FILE}`);

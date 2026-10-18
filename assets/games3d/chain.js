/* Chain Reaction – glossy bubbles on a milk-white board. Fill a cell to its limit and it bursts into its
 * neighbours, taking them over. Chains of bursts can flip the whole board! 2–4 players, computer, online. */
'use strict';
(function () {
  const COLS = 8, CELL = 1.25;
  let ROWS = 10;
  const PCOL = ['#ff5c8a', '#7c5cff', '#22b8a5', '#ffa31a'];
  const PNAME = ['Pink', 'Violet', 'Teal', 'Mango'];
  let N, NB, CM; // cells, neighbours, how many bubbles a cell holds before it bursts
  const rc = (i) => [Math.floor(i / COLS), i % COLS];
  function setGrid(rows) {
    ROWS = rows;
    N = COLS * ROWS;
    NB = Array.from({ length: N }, (_, i) => {
      const [r, c] = rc(i), out = [];
      if (r > 0) out.push(i - COLS);
      if (r < ROWS - 1) out.push(i + COLS);
      if (c > 0) out.push(i - 1);
      if (c < COLS - 1) out.push(i + 1);
      return out;
    });
    CM = NB.map((n) => n.length);
  }
  // screen space taken by the top bar + player chips, and by the status line at the bottom
  const HUD_TOP = 112, HUD_BOTTOM = 64;
  /** As many rows as fit this screen when the board fills its whole width. */
  function rowsForScreen() {
    const a = window.innerWidth / window.innerHeight;
    const visH = (COLS * CELL) / a; // world units visible top to bottom
    const avail = visH * (window.innerHeight - HUD_TOP - HUD_BOTTOM) / window.innerHeight;
    return Math.max(10, Math.min(18, Math.floor(avail / CELL)));
  }
  /** Look straight down; board edge to edge across the width, all rows between the HUD bars. */
  function fitView() {
    const a = window.innerWidth / window.innerHeight, vf = THREE.MathUtils.degToRad(G.camera.fov), t = Math.tan(vf / 2);
    const H = window.innerHeight, availFrac = (H - HUD_TOP - HUD_BOTTOM) / H;
    const rW = (COLS * CELL + 0.12) / (2 * t * a);
    const rH = (ROWS * CELL + 0.12) / (2 * t * availFrac);
    const r = Math.max(rW, rH) + 0.42; // + top of the bubbles
    const visH = 2 * r * t;
    const shift = ((HUD_TOP - HUD_BOTTOM) / 2 / H) * visH; // centre the board between the bars
    G.setView(new THREE.Vector3(0, 0.42, -shift), 0.001, r, 0);
  }
  setGrid(10);

  let players = [], cnt = [], own = [], turn = 0, step = 0, moves = 0, alive = [], over = false, busy = false;
  let root, cellGroups = [], gridMat, mats = [], orbGeo, sparkGeo;

  const pos = (i) => { const [r, c] = rc(i); return new THREE.Vector3((c - (COLS - 1) / 2) * CELL, 0.42, (r - (ROWS - 1) / 2) * CELL); };
  const cur = () => players[turn];

  // ───────── board ─────────
  function build() {
    if (root) G.scene.remove(root);
    root = new THREE.Group();
    G.scene.add(root);
    G.setBackground('#efe6fb', '#efe6fb');
    const floor = G.addTable('#efe6fb', 80);
    floor.position.y = -0.4;
    root.add(floor);
    const W = COLS * CELL + 0.3, D = ROWS * CELL + 0.3;
    const base = new THREE.Mesh(G.roundedBox(W, 0.5, D, 0.22), new THREE.MeshPhysicalMaterial({ color: 0xfffbf6, roughness: 0.35, clearcoat: 1, clearcoatRoughness: 0.2 }));
    base.position.y = -0.05;
    G.shadowed(base);
    root.add(base);
    // soft lavender cells
    const tileGeo = G.roundedBox(CELL * 0.9, 0.08, CELL * 0.9, 0.12, 3);
    const tileMat = new THREE.MeshPhysicalMaterial({ color: 0xe9dcfb, roughness: 0.45, clearcoat: 0.7 });
    for (let i = 0; i < N; i++) {
      const t = new THREE.Mesh(tileGeo, tileMat);
      const p = pos(i);
      t.position.set(p.x, 0.22, p.z);
      t.receiveShadow = true;
      root.add(t);
    }
    // glowing grid lines in the colour of whoever plays now
    gridMat = new THREE.MeshStandardMaterial({ color: PCOL[0], emissive: PCOL[0], emissiveIntensity: 0.9, roughness: 0.4 });
    const lw = 0.07;
    for (let c = 0; c <= COLS; c++) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(lw, 0.06, ROWS * CELL), gridMat);
      m.position.set((c - COLS / 2) * CELL, 0.27, 0);
      root.add(m);
    }
    for (let r = 0; r <= ROWS; r++) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(COLS * CELL, 0.06, lw), gridMat);
      m.position.set(0, 0.27, (r - ROWS / 2) * CELL);
      root.add(m);
    }
    orbGeo = new THREE.SphereGeometry(0.3, 32, 20);
    sparkGeo = new THREE.SphereGeometry(0.06, 8, 6);
    mats = PCOL.map((c) => new THREE.MeshPhysicalMaterial({ color: G.shade(c, -0.08), roughness: 0.1, metalness: 0.05, clearcoat: 1, clearcoatRoughness: 0.03, emissive: c, emissiveIntensity: 0.28 }));
    cellGroups = [];
    for (let i = 0; i < N; i++) {
      const g = new THREE.Group();
      g.position.copy(pos(i));
      g.userData.spin = Math.random() * 6;
      root.add(g);
      cellGroups.push(g);
    }
  }

  const OFF = [[], [[0, 0]], [[-0.19, 0], [0.19, 0]], [[0, -0.19], [-0.19, 0.13], [0.19, 0.13]], [[-0.19, -0.19], [0.19, -0.19], [-0.19, 0.19], [0.19, 0.19]]];
  function drawCell(i) {
    const g = cellGroups[i];
    while (g.children.length) g.remove(g.children[0]);
    const n = Math.min(cnt[i], 4);
    if (!n || own[i] < 0) return;
    for (const [x, z] of OFF[n]) {
      const s = new THREE.Mesh(orbGeo, mats[own[i]]);
      s.position.set(x, 0, z);
      s.castShadow = true;
      g.add(s);
    }
  }
  const drawAll = () => { for (let i = 0; i < N; i++) drawCell(i); };

  // bubbles wobble; the ones about to burst shake and spin fast
  G.onFrame.push((dt, t) => {
    if (!root || !cellGroups.length) return;
    for (let i = 0; i < N; i++) {
      const g = cellGroups[i];
      if (!g.children.length) continue;
      const hot = cnt[i] >= CM[i] - 1;
      g.userData.spin += dt * (hot ? 5 : 1.2);
      g.rotation.y = g.userData.spin;
      g.position.y = 0.42 + Math.sin(t * 3 + i) * 0.03;
      if (hot) { g.position.x = pos(i).x + Math.sin(t * 40 + i) * 0.025; g.position.z = pos(i).z + Math.cos(t * 37 + i) * 0.025; }
      const k = hot ? 1 + Math.sin(t * 10 + i) * 0.05 : 1;
      g.scale.setScalar(k);
    }
  });

  // ───────── sounds ─────────
  function popSound(wave, n) {
    const rate = Math.min(2.2, 0.85 + wave * 0.09);
    if (!G.snd.play('bubble', { vol: 0.9, rate })) {
      G.snd.tone(300 + wave * 60, 0.12, 'sine', 0.25, 0, 900 + wave * 120);
      G.snd.hit(1800, 0.05, 0.25);
    }
    if (n > 2) G.snd.play('bubble', { vol: 0.6, rate: rate * 1.2, when: 0.06 });
    if (wave === 2) G.snd.play('bubbles', { vol: 0.45 });
    if (wave === 4) { G.snd.say('v_combo', 0.85) || G.snd.six(); G.snd.play('sparkle', { vol: 0.5 }); }
    if (wave === 9) { G.snd.say('v_chain', 0.9); G.snd.play('sparkle', { vol: 0.6 }); }
  }

  // ───────── rules ─────────
  const legal = (i, p) => own[i] < 0 || own[i] === p;
  const orbs = (p, o = own, c = cnt) => { let s = 0; for (let i = 0; i < N; i++) if (o[i] === p) s += c[i]; return s; };

  /** Apply one move on arrays (no animation). Returns the bursts by wave. */
  function simulate(c, o, i, p, firstRound) {
    c[i]++;
    o[i] = p;
    const waves = [];
    for (let w = 0; w < 300; w++) {
      const un = [];
      for (let k = 0; k < N; k++) if (c[k] >= CM[k]) un.push(k);
      if (!un.length) break;
      waves.push(un);
      for (const u of un) {
        c[u] -= CM[u];
        if (c[u] <= 0) { c[u] = 0; o[u] = -1; }
        for (const v of NB[u]) { c[v]++; o[v] = p; }
      }
      if (!firstRound) {
        let others = 0;
        for (let k = 0; k < N; k++) if (o[k] >= 0 && o[k] !== p) others++;
        if (!others) break; // everything is ours – stop the endless chain
      }
    }
    return waves;
  }

  async function doPut(i) {
    busy = true;
    const p = turn;
    G.haptic('light');
    // the new bubble drops in
    cnt[i]++;
    own[i] = p;
    drawCell(i);
    const g = cellGroups[i];
    if (!G.fast) {
      G.snd.play('pop', { vol: 0.8, rate: 1.3 }) || G.snd.tone(520, 0.08, 'sine', 0.2, 0, 900);
      await G.tween(220, (t) => g.scale.setScalar(0.4 + 0.6 * G.ease.back(t)));
    }
    cnt[i]--; // simulate() adds it again
    const firstRound = moves < players.length;
    const c2 = cnt.slice(), o2 = own.slice();
    const waves = simulate(c2, o2, i, p, firstRound);
    // play the bursts wave by wave
    const c = cnt, o = own;
    c[i]++;
    o[i] = p;
    for (let w = 0; w < waves.length; w++) {
      const un = waves[w];
      if (!G.fast) {
        popSound(w, un.length);
        G.haptic(w > 2 ? 'medium' : 'light');
        const flyers = [];
        for (const u of un) {
          for (const v of NB[u]) {
            const s = new THREE.Mesh(orbGeo, mats[p]);
            s.position.copy(pos(u));
            root.add(s);
            flyers.push([s, pos(u), pos(v)]);
          }
          burst(pos(u), p);
          cellGroups[u].visible = false;
        }
        await G.tween(Math.max(150, 260 - w * 8), (t) => {
          for (const [s, a, b] of flyers) {
            s.position.lerpVectors(a, b, t);
            s.position.y = a.y + Math.sin(t * Math.PI) * 0.5;
            s.scale.setScalar(1 + Math.sin(t * Math.PI) * 0.25);
          }
        }, G.ease.out);
        for (const [s] of flyers) root.remove(s);
      }
      for (const u of un) {
        c[u] -= CM[u];
        if (c[u] <= 0) { c[u] = 0; o[u] = -1; }
        for (const v of NB[u]) { c[v]++; o[v] = p; }
      }
      if (!G.fast) {
        for (const u of un) { cellGroups[u].visible = true; drawCell(u); for (const v of NB[u]) drawCell(v); }
      }
    }
    if (G.fast) drawAll();
    if (waves.length >= 6 && !G.fast) G.toast(`💥 ${waves.length}× chain!`);
    moves++;
    // who is still in the game?
    if (moves >= players.length) {
      for (let k = 0; k < players.length; k++) if (alive[k] && orbs(k) === 0) { alive[k] = false; G.toast(`💨 ${players[k].name} is out!`); }
    }
    const left = alive.filter(Boolean).length;
    hud();
    if (left <= 1 && moves >= players.length) {
      over = true;
      busy = false;
      const w = alive.indexOf(true);
      G.status(players[w].name + ' wins! 🎉');
      G.confetti(new THREE.Vector3(0, 0, 0), 10);
      if (players[w].bot) G.botTease(players[w], ['😎', '🥳', '😜']);
      G.winScreen(players[w].name + ' wins! 🎉', 'Took over the whole board', () => G.act({ t: 'new' }));
      return;
    }
    step++;
    nextTurn();
  }

  function burst(at, p) {
    if (G.fast) return;
    const parts = [];
    for (let k = 0; k < 10; k++) {
      const s = new THREE.Mesh(sparkGeo, new THREE.MeshBasicMaterial({ color: k % 3 ? PCOL[p] : '#ffffff', transparent: true }));
      s.position.copy(at);
      const a = Math.random() * Math.PI * 2, sp = 1.5 + Math.random() * 2.5;
      parts.push([s, new THREE.Vector3(Math.cos(a) * sp, 2 + Math.random() * 2.5, Math.sin(a) * sp)]);
      root.add(s);
    }
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.05, 8, 32), new THREE.MeshBasicMaterial({ color: PCOL[p], transparent: true }));
    ring.rotation.x = Math.PI / 2;
    ring.position.copy(at);
    root.add(ring);
    G.tween(520, (t) => {
      for (const [s, v] of parts) {
        s.position.set(at.x + v.x * t * 0.35, at.y + v.y * t * 0.35 - 2.5 * t * t, at.z + v.z * t * 0.35);
        s.material.opacity = 1 - t;
      }
      ring.scale.setScalar(1 + t * 2.4);
      ring.material.opacity = 0.9 * (1 - t);
    }, G.ease.linear).then(() => { for (const [s] of parts) root.remove(s); root.remove(ring); });
  }

  function nextTurn() {
    do { turn = (turn + 1) % players.length; } while (!alive[turn]);
    busy = false;
    hud();
    const p = cur();
    G.status(G.mine(p) ? `<span style="color:${PCOL[turn]}">●</span> ${p.name}, tap a cell` : `<span style="color:${PCOL[turn]}">●</span> ${p.name}'s turn…`);
    if (G.mine(p) && !G.fast && G.localHumans(players) > 1) G.toast(`${p.name}'s turn`, 900);
    if (G.botTurn(p)) setTimeout(botMove, G.fast ? 0 : 650 + Math.random() * 500);
  }

  function hud() {
    gridMat.color.set(PCOL[turn]);
    gridMat.emissive.set(PCOL[turn]);
    G.players(players.map((p, i) => ({ name: (alive[i] ? '' : '💨 ') + p.name, color: PCOL[i], bot: p.bot, extra: alive[i] ? '●' + orbs(i) : '' })), turn);
  }

  // ───────── computer ─────────
  function botMove() {
    if (over || busy || !G.botTurn(cur())) return;
    const p = turn, firstRound = moves < players.length;
    let best = -1, bestScore = -1e9;
    for (let i = 0; i < N; i++) {
      if (!legal(i, p)) continue;
      const c = cnt.slice(), o = own.slice();
      simulate(c, o, i, p, firstRound);
      let mine = 0, theirs = 0, danger = 0, safe = 0;
      for (let k = 0; k < N; k++) {
        if (o[k] === p) {
          mine += c[k];
          // could an enemy blow this up next turn?
          if (NB[k].some((v) => o[v] >= 0 && o[v] !== p && c[v] === CM[v] - 1)) danger += c[k] + 1;
          if (CM[k] === 2) safe += 0.4; // corners are strong
        } else if (o[k] >= 0) theirs += c[k];
      }
      let s = mine * 1.2 - theirs * 1.5 - danger * 1.1 + safe + Math.random() * 0.8;
      if (!theirs && !firstRound) s += 1000;
      if (s > bestScore) { bestScore = s; best = i; }
    }
    if (best >= 0) G.act({ t: 'put', c: best, n: step });
  }

  // ───────── input ─────────
  function tap(x, y) {
    if (over || busy || !G.mine(cur())) return;
    const hit = G.pickPlane(x, y, 0.3);
    if (!hit) return;
    const l = root.worldToLocal(hit.clone());
    const c = Math.round(l.x / CELL + (COLS - 1) / 2), r = Math.round(l.z / CELL + (ROWS - 1) / 2);
    if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return;
    const i = r * COLS + c;
    if (!legal(i, turn)) { G.snd.error(); G.toast('That cell is taken 🙈', 900); return; }
    busy = true;
    G.act({ t: 'put', c: i, n: step });
  }

  function restart() {
    cnt = new Array(N).fill(0);
    own = new Array(N).fill(-1);
    alive = players.map(() => true);
    turn = players.length - 1;
    step = 0;
    moves = 0;
    over = false;
    busy = false;
    G.$('win').classList.remove('show');
    drawAll();
    nextTurn();
    step = 0;
  }

  window.Chain3D = {
    _fit: () => fitView(),
    title: 'Chain Reaction', minPlayers: 2, maxPlayers: 4, colors: PCOL,
    init() {
      G.$('title').textContent = '💥 Chain Reaction';
      G.$('actions').innerHTML = '';
      G.$('roll').style.display = 'none';
      G.$('vig').style.display = 'none'; // keep the board bright right to the edges
      G.onTap = tap;
      setGrid(rowsForScreen());
      build();
      fitView();
      G.orbit.minR = 6;
      G.orbit.maxR = 80;
    },
    makeSetup(list) { return { players: list.slice(0, 4), rows: rowsForScreen() }; },
    begin(s) {
      players = s.players;
      if (s.rows && s.rows !== ROWS) { setGrid(s.rows); build(); fitView(); }
      restart();
      G.status(`<span style="color:${PCOL[0]}">●</span> ${players[0].name} starts – tap any cell`);
    },
    allowed(a, from) {
      if (a.t === 'new') return over || from === G.net.myId;
      const p = cur();
      return p.id === from || (p.bot && from === G.net.myId);
    },
    async apply(a) {
      if (a.t === 'new') { restart(); return; }
      if (over || a.n !== step || !legal(a.c, turn)) { busy = false; return; }
      await doPut(a.c);
    },
  };
})();

window.addEventListener('resize', () => { if (window.Chain3D && G.game === window.Chain3D) setTimeout(() => window.Chain3D._fit && window.Chain3D._fit(), 50); });

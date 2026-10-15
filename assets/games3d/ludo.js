/* Ludo 3D – raised tiles, glossy pawns with faces, a real rolling dice, sounds. */
'use strict';
(function () {
  // 52-square track (col,row) clockwise from Red's start; same layout as the classic board.
  const TRACK = (() => {
    const t = [];
    for (let c = 1; c <= 5; c++) t.push([c, 6]);
    for (let r = 5; r >= 0; r--) t.push([6, r]);
    t.push([7, 0]);
    for (let r = 0; r <= 5; r++) t.push([8, r]);
    for (let c = 9; c <= 14; c++) t.push([c, 6]);
    t.push([14, 7]);
    for (let c = 14; c >= 9; c--) t.push([c, 8]);
    for (let r = 9; r <= 14; r++) t.push([8, r]);
    t.push([7, 14]);
    for (let r = 14; r >= 9; r--) t.push([6, r]);
    for (let c = 5; c >= 0; c--) t.push([c, 8]);
    t.push([0, 7]);
    t.push([0, 6]);
    return t;
  })();
  const SEAT_COL = ['#e53950', '#2eae5a', '#f2b705', '#2f7de1'];
  const START = [0, 13, 26, 39];
  const SAFE = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
  const homeCell = (seat, st) => [[1 + st, 7], [7, 1 + st], [13 - st, 7], [7, 13 - st]][seat];
  const yardCentre = (seat) => [[3, 3], [12, 3], [12, 12], [3, 12]][seat];
  const yardSpot = (seat, k) => { const c = yardCentre(seat); return [c[0] + (k % 2 ? 1.05 : -1.05), c[1] + (k < 2 ? -1.05 : 1.05)]; };

  let cfg, players, seats, tok, turn, dice = 1, sixes = 0, rolled = false, busy = false, over = false;
  let root, pawnMeshes, diceMesh, rings = [], pads = [];
  const cellPos = (c, r, y) => new THREE.Vector3(c - 7 + 0.5, y == null ? 0.17 : y, r - 7 + 0.5);
  const abs = (p, rel) => (START[seats[p]] + rel) % 52;

  function tokenSpot(p, k) {
    const t = tok[p][k], seat = seats[p];
    if (t === -1) { const s = yardSpot(seat, k); return cellPos(s[0] - 0.5, s[1] - 0.5, 0.24); }
    if (t === 56) {
      const off = [[-0.55, 0], [0, -0.55], [0.55, 0], [0, 0.55]][seat];
      return new THREE.Vector3(off[0] + (k - 1.5) * 0.12, 0.3, off[1] + (k - 1.5) * 0.12);
    }
    if (t > 50) { const h = homeCell(seat, t - 51); return cellPos(h[0], h[1]); }
    const c = TRACK[abs(p, t)];
    return cellPos(c[0], c[1]);
  }

  // place tokens sharing a square side by side
  function layout(instant) {
    const groups = {};
    for (let p = 0; p < tok.length; p++) for (let k = 0; k < 4; k++) {
      const v = tokenSpot(p, k);
      const key = v.x.toFixed(2) + ',' + v.z.toFixed(2);
      (groups[key] = groups[key] || []).push([p, k, v]);
    }
    const out = [];
    for (const g of Object.values(groups)) {
      g.forEach(([p, k, v], j) => {
        const n = g.length;
        const o = n > 1 ? new THREE.Vector3(((j % 2) - 0.5) * 0.36, 0, (Math.floor(j / 2) - 0.5) * 0.36 * (n > 2 ? 1 : 0)) : new THREE.Vector3();
        const m = pawnMeshes[p][k];
        const target = v.clone().add(o);
        const sc = n > 1 ? 0.78 : 1.12;
        if (instant) { m.position.copy(target); m.scale.setScalar(sc); m.userData.baseScale = sc; }
        else out.push([m, target, sc]);
      });
    }
    return out;
  }

  // ───────── board ─────────
  function buildBoard() {
    G.setBackground('#ffe2c2', '#c77b4d');
    const S = 15.6;
    const tex = G.canvasTex(1024, 1024, (g, W) => {
      const k = W / S, o = 0.3 * k;
      g.fillStyle = '#fff4e2';
      g.fillRect(0, 0, W, W);
      // yards
      for (let s = 0; s < 4; s++) {
        const [cx, cy] = [[0, 0], [9, 0], [9, 9], [0, 9]][s];
        const gr = g.createLinearGradient(o + cx * k, o + cy * k, o + (cx + 6) * k, o + (cy + 6) * k);
        gr.addColorStop(0, G.shade(SEAT_COL[s], 0.08));
        gr.addColorStop(1, G.shade(SEAT_COL[s], -0.06));
        g.fillStyle = gr;
        G.rrect(g, o + cx * k + 4, o + cy * k + 4, 6 * k - 8, 6 * k - 8, k * 0.5);
        g.fill();
      }
      // arrows into home columns
      g.fillStyle = 'rgba(0,0,0,.12)';
      g.font = `${Math.round(k * 0.7)}px sans-serif`;
    });
    const top = new THREE.MeshPhysicalMaterial({ map: tex, roughness: 0.5, clearcoat: 0.4 });
    const side = new THREE.MeshPhysicalMaterial({ color: 0xf0c48c, roughness: 0.45, clearcoat: 0.5 });
    const base = new THREE.Mesh(G.roundedBox(S, 0.5, S, 0.25, 4), [side, side, top, side, side, side]);
    base.position.y = -0.25;
    base.receiveShadow = true;
    base.castShadow = true;
    root.add(base);
    // outer rail like a clay tray
    const railMat = new THREE.MeshPhysicalMaterial({ color: 0xff8fb3, roughness: 0.35, clearcoat: 0.8 });
    for (const [x, z, w, d] of [[0, -S / 2, S, 0.3], [0, S / 2, S, 0.3], [-S / 2, 0, 0.3, S], [S / 2, 0, 0.3, S]]) {
      const r = new THREE.Mesh(G.roundedBox(w + 0.3, 0.36, d + 0.3, 0.14, 3), railMat);
      r.position.set(x, 0.12, z);
      G.shadowed(r);
      root.add(r);
    }
    const table = G.addTable('#9a6a43', 90);
    table.position.y = -0.5;
    root.add(table);

    // track tiles
    const tileGeo = G.roundedBox(0.9, 0.16, 0.9, 0.07, 3);
    const white = new THREE.MeshPhysicalMaterial({ color: 0xffffff, roughness: 0.35, clearcoat: 0.7 });
    const tinted = SEAT_COL.map((c) => new THREE.MeshPhysicalMaterial({ color: c, roughness: 0.3, clearcoat: 0.8 }));
    const starShape = new THREE.Shape();
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2 - Math.PI / 2, r = i % 2 ? 0.13 : 0.3;
      i ? starShape.lineTo(Math.cos(a) * r, Math.sin(a) * r) : starShape.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    }
    const starGeo = new THREE.ExtrudeGeometry(starShape, { depth: 0.06, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.02, bevelSegments: 2 });
    const gold = new THREE.MeshPhysicalMaterial({ color: 0xffc21a, metalness: 0.3, roughness: 0.25, clearcoat: 1, emissive: 0x6a4a00, emissiveIntensity: 0.4 });
    TRACK.forEach(([c, r], i) => {
      const seat = START.indexOf(i);
      const m = new THREE.Mesh(tileGeo, seat >= 0 ? tinted[seat] : white);
      m.position.copy(cellPos(c, r, 0.08));
      m.receiveShadow = true;
      root.add(m);
      if (SAFE.has(i) && seat < 0) {
        const st = new THREE.Mesh(starGeo, gold);
        st.rotation.x = -Math.PI / 2;
        st.position.copy(cellPos(c, r, 0.17));
        G.shadowed(st);
        root.add(st);
      }
      if (seat >= 0) {
        // arrow on start squares
        const ar = new THREE.Mesh(new THREE.ConeGeometry(0.2, 0.3, 3), white);
        ar.position.copy(cellPos(c, r, 0.2));
        ar.rotation.x = Math.PI / 2;
        ar.rotation.z = [-Math.PI / 2, 0, Math.PI / 2, Math.PI][seat];
        ar.scale.y = 0.4;
        root.add(ar);
      }
    });
    for (let s = 0; s < 4; s++) for (let st = 0; st < 5; st++) {
      const [c, r] = homeCell(s, st);
      const m = new THREE.Mesh(tileGeo, tinted[s]);
      m.position.copy(cellPos(c, r, 0.08));
      m.receiveShadow = true;
      root.add(m);
    }
    // centre: four coloured pyramid faces meeting at the top
    for (let s = 0; s < 4; s++) {
      const corners = [[-1.5, 1.5, -1.5, -1.5], [-1.5, -1.5, 1.5, -1.5], [1.5, -1.5, 1.5, 1.5], [1.5, 1.5, -1.5, 1.5]][s];
      const geo = new THREE.BufferGeometry();
      const v = new Float32Array([corners[0], 0.02, corners[1], corners[2], 0.02, corners[3], 0, 0.7, 0]);
      geo.setAttribute('position', new THREE.BufferAttribute(v, 3));
      geo.setIndex([0, 2, 1]);
      geo.computeVertexNormals();
      const m = new THREE.Mesh(geo, new THREE.MeshPhysicalMaterial({ color: SEAT_COL[s], roughness: 0.3, clearcoat: 0.8, side: THREE.DoubleSide }));
      m.castShadow = m.receiveShadow = true;
      root.add(m);
    }
    const crown = new THREE.Mesh(new THREE.SphereGeometry(0.2, 20, 16), gold);
    crown.position.y = 0.78;
    G.shadowed(crown);
    root.add(crown);
    // yard pads with sockets
    pads = [];
    for (let s = 0; s < 4; s++) {
      const [cx, cy] = yardCentre(s);
      const pad = new THREE.Mesh(G.roundedBox(3.9, 0.22, 3.9, 0.18, 4), new THREE.MeshPhysicalMaterial({ color: new THREE.Color(G.shade(SEAT_COL[s], 0.36)), roughness: 0.35, clearcoat: 0.8, emissive: new THREE.Color(SEAT_COL[s]), emissiveIntensity: 0 }));
      pad.position.copy(cellPos(cx - 0.5, cy - 0.5, 0.11));
      G.shadowed(pad);
      root.add(pad);
      pads.push(pad);
      for (let k = 0; k < 4; k++) {
        const sp = yardSpot(s, k);
        const sock = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.04, 32), new THREE.MeshPhysicalMaterial({ color: G.shade(SEAT_COL[s], 0.15), roughness: 0.4, clearcoat: 0.6 }));
        sock.position.copy(cellPos(sp[0] - 0.5, sp[1] - 0.5, 0.23));
        sock.receiveShadow = true;
        root.add(sock);
      }
    }
  }

  function buildTokens() {
    pawnMeshes = [];
    for (let p = 0; p < players.length; p++) {
      pawnMeshes.push([]);
      for (let k = 0; k < 4; k++) {
        const m = makePawn(SEAT_COL[seats[p]], 1);
        m.userData.pk = [p, k];
        m.traverse((o) => (o.userData.pawn = m));
        root.add(m);
        pawnMeshes[p].push(m);
      }
    }
    layout(true);
  }

  // ───────── game flow ─────────
  const cur = () => players[turn];
  const canMove = (p, k, d) => { const t = tok[p][k]; if (t === 56) return false; if (t === -1) return d === 6; return t + d <= 56; };
  const movable = (d) => [0, 1, 2, 3].filter((k) => canMove(turn, k, d));

  function hud() {
    G.players(players.map((p, i) => ({ name: p.name, color: SEAT_COL[seats[i]], bot: p.bot, extra: tok[i].filter((x) => x === 56).length ? '🏠×' + tok[i].filter((x) => x === 56).length : '' })), turn);
    pads.forEach((pd, s) => (pd.material.emissiveIntensity = s === seats[turn] ? 0.25 : 0));
    const rb = G.$('roll');
    rb.style.display = 'block';
    rb.classList.toggle('off', cur().bot || rolled || busy || over);
    rb.style.background = `linear-gradient(${G.shade(SEAT_COL[seats[turn]], 0.15)}, ${SEAT_COL[seats[turn]]})`;
  }

  function clearRings() { for (const r of rings) root.remove(r); rings = []; }
  function showRings(ks) {
    clearRings();
    for (const k of ks) {
      const r = makeRing(0xffffff, 0.36);
      const m = pawnMeshes[turn][k];
      r.position.set(m.position.x, m.position.y + 0.02, m.position.z);
      r.userData.k = k;
      root.add(r);
      rings.push(r);
    }
  }
  G.onFrame.push((dt, t) => {
    for (const r of rings) {
      const s = 1 + Math.sin(t * 6) * 0.12;
      r.scale.set(s, s, s);
      const m = pawnMeshes && pawnMeshes[turn] && pawnMeshes[turn][r.userData.k];
      if (m && !busy) m.position.y = tokenSpot(turn, r.userData.k).y + Math.abs(Math.sin(t * 5)) * 0.15;
    }
  });

  function diceSpot() {
    const [cx, cy] = yardCentre(seats[turn]);
    return cellPos(cx - 0.5, cy - 0.5, 0.22);
  }

  async function roll() {
    if (busy || rolled || over) return;
    busy = true;
    hud();
    dice = 1 + Math.floor(Math.random() * 6);
    const to = diceSpot();
    await G.rollDice(diceMesh, dice, to);
    rolled = true;
    if (dice === 6) {
      sixes++;
      G.snd.six();
      if (sixes === 3) {
        G.toast('Three 6s! 😅');
        G.status(cur().name + ' loses the turn');
        await G.wait(1100);
        return next(false);
      }
      G.toast('🎲 Six!');
    }
    const ms = movable(dice);
    if (!ms.length) {
      G.status(cur().name + ' rolled ' + dice + ' – no move');
      await G.wait(1000);
      return next(dice === 6);
    }
    busy = false;
    if (cur().bot || ms.length === 1 || ms.every((k) => tok[turn][k] === -1)) {
      G.status(cur().name + ' rolled ' + dice);
      await G.wait(cur().bot ? 550 : 350);
      return move(cur().bot ? botPick(ms) : ms[0]);
    }
    G.status(cur().name + ' rolled ' + dice + ' – tap a pawn');
    showRings(ms);
    hud();
  }

  function botPick(ms) {
    const score = (k) => {
      const t = tok[turn][k];
      if (t === -1) return 60;
      const nt = t + dice;
      if (nt === 56) return 90;
      if (nt <= 50) {
        const a = abs(turn, nt);
        for (let q = 0; q < tok.length; q++) if (q !== turn) for (const o of tok[q]) if (o >= 0 && o <= 50 && abs(q, o) === a && !SAFE.has(a)) return 100;
        if (SAFE.has(a)) return 40 + (nt >> 2);
      }
      if (nt > 50) return 50;
      return 10 + Math.floor(nt / 3);
    };
    return ms.slice().sort((a, b) => score(b) - score(a))[0];
  }

  async function move(k) {
    if (busy || !rolled || !canMove(turn, k, dice)) return;
    busy = true;
    clearRings();
    hud();
    let extra = dice === 6;
    const m = pawnMeshes[turn][k];
    m.position.y = tokenSpot(turn, k).y;
    if (tok[turn][k] === -1) {
      tok[turn][k] = 0;
      G.snd.hop();
      await G.hopTo(m, tokenSpot(turn, k), 420, 1.2);
    } else {
      for (let i = 0; i < dice; i++) {
        tok[turn][k]++;
        G.snd.hop();
        await G.hopTo(m, tokenSpot(turn, k), 210, 0.55);
      }
    }
    G.snd.wood();
    const t = tok[turn][k];
    if (t <= 50) {
      const a = abs(turn, t);
      if (!SAFE.has(a)) {
        for (let q = 0; q < tok.length; q++) {
          if (q === turn) continue;
          for (let j = 0; j < 4; j++) {
            if (tok[q][j] >= 0 && tok[q][j] <= 50 && abs(q, tok[q][j]) === a) {
              tok[q][j] = -1;
              extra = true;
              G.snd.capture();
              G.haptic('heavy');
              G.toast('💥 ' + cur().name + ' cut ' + players[q].name + '!');
              const v = pawnMeshes[q][j];
              v.userData.baseScale = v.scale.y;
              await G.hopTo(v, tokenSpot(q, j), 700, 3.2);
            }
          }
        }
      }
    }
    if (t === 56) {
      extra = true;
      G.snd.home();
      G.toast('🏠 Home!');
      if (tok[turn].every((x) => x === 56)) {
        over = true;
        await settle();
        hud();
        G.confetti(new THREE.Vector3(0, 0, 0), 14);
        G.status(cur().name + ' wins! 🎉');
        G.winScreen(cur().name + ' wins Ludo! 🎉', 'All four pawns are home', restart);
        return;
      }
    }
    await settle();
    await G.wait(250);
    next(extra);
  }

  async function settle() {
    const moves = layout(false);
    await Promise.all(moves.map(([m, to, sc]) => {
      const s0 = m.scale.y;
      const from = m.position.clone();
      if (from.distanceTo(to) < 0.01 && Math.abs(s0 - sc) < 0.01) return Promise.resolve();
      return G.tween(220, (k) => { m.position.lerpVectors(from, to, k); m.scale.setScalar(s0 + (sc - s0) * k); }).then(() => (m.userData.baseScale = sc));
    }));
  }

  function next(extra) {
    if (over) return;
    if (!extra) { sixes = 0; turn = (turn + 1) % players.length; }
    rolled = false;
    busy = false;
    G.status(extra ? cur().name + ' rolls again! 🎲' : cur().name + "'s turn – roll the dice");
    hud();
    if (cur().bot) setTimeout(() => { if (!rolled && !busy && cur().bot) roll(); }, 800);
  }

  function tap(x, y) {
    if (over) return;
    const dh = G.pick(x, y, [diceMesh]);
    if (dh.length && !cur().bot && !rolled) return roll();
    if (cur().bot || !rolled || busy) return;
    const ms = movable(dice);
    const hits = G.pick(x, y, pawnMeshes[turn]);
    for (const h of hits) {
      const pw = h.object.userData.pawn;
      if (pw && ms.includes(pw.userData.pk[1])) return move(pw.userData.pk[1]);
    }
    // tap near a movable pawn
    const pw = G.pickPlane(x, y, 0.2);
    if (!pw) return;
    const p = root.worldToLocal(pw.clone());
    let best = -1, bd = 0.9;
    for (const k of ms) {
      const d = pawnMeshes[turn][k].position.distanceTo(new THREE.Vector3(p.x, pawnMeshes[turn][k].position.y, p.z));
      if (d < bd) { bd = d; best = k; }
    }
    if (best >= 0) move(best);
  }

  function restart() {
    tok = players.map(() => [-1, -1, -1, -1]);
    turn = 0;
    rolled = busy = over = false;
    sixes = 0;
    if (root) G.scene.remove(root);
    root = new THREE.Group();
    root.rotation.y = Math.PI / 2; // first player's corner nearest to you
    G.scene.add(root);
    buildBoard();
    buildTokens();
    diceMesh = G.makeDice(0.85);
    diceMesh.position.copy(diceSpot());
    diceMesh.position.y = 0.65;
    root.add(diceMesh);
    rings = [];
    next(true);
    G.status(cur().name + ', roll the dice! 🎲');
  }

  window.Ludo3D = {
    start(c) {
      cfg = c;
      players = c.players;
      const n = players.length;
      seats = n === 2 ? [0, 2] : n === 3 ? [0, 1, 2] : [0, 1, 2, 3];
      G.$('title').textContent = '🎲 Ludo 3D';
      G.$('actions').innerHTML = '';
      G.$('roll').onclick = () => { if (!cur().bot) roll(); };
      G.onTap = tap;
      G.orbit.minR = 9;
      G.orbit.maxR = 40;
      restart();
      G.setView(new THREE.Vector3(0, 0, 0.6), 0.7, G.fitRadius(16.2, 0.7), 0);
    },
  };
})();

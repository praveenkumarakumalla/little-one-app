/* Snakes & Ladders 3D – round 3D snakes, wooden ladders, hopping pawns, sounds. */
'use strict';
(function () {
  const SNAKES = { 99: 54, 95: 72, 87: 24, 62: 19, 56: 42, 49: 11, 47: 26, 17: 7 };
  const LADDERS = { 4: 14, 9: 31, 20: 38, 28: 84, 40: 59, 51: 67, 63: 81, 71: 91 };
  const PCOL = ['#e53950', '#2eae5a', '#f2b705', '#2f7de1'];
  const CELL_COLS = ['#ff7a9c', '#ffc93c', '#5fd27f', '#5fb2ff', '#b083ff', '#ff9a5c'];

  let players, posn, turn, dice = 1, busy = false, over = false, root, pawns, diceMesh, snakeHeads = [];

  function cellXY(n) {
    const i = n - 1, row = Math.floor(i / 10);
    let col = i % 10;
    if (row % 2) col = 9 - col;
    return [col, row];
  }
  const cellPos = (n, y) => { const [c, r] = cellXY(n); return new THREE.Vector3(c - 4.5, y == null ? 0 : y, 4.5 - r); };

  function buildBoard() {
    G.setBackground('#d9f2ff', '#5aa0c8');
    const S = 10.8;
    const tex = G.canvasTex(1024, 1024, (g, W) => {
      const k = W / S, o = 0.4 * k;
      g.fillStyle = '#fff7ea';
      g.fillRect(0, 0, W, W);
      for (let n = 1; n <= 100; n++) {
        const [c, r] = cellXY(n);
        const x = o + c * k, y = o + (9 - r) * k;
        const col = CELL_COLS[(n * 7 + r) % CELL_COLS.length];
        const gr = g.createLinearGradient(x, y, x + k, y + k);
        gr.addColorStop(0, G.shade(col, 0.07));
        gr.addColorStop(1, G.shade(col, -0.05));
        g.fillStyle = gr;
        G.rrect(g, x + 3, y + 3, k - 6, k - 6, k * 0.14);
        g.fill();
        g.fillStyle = 'rgba(255,255,255,.25)';
        G.rrect(g, x + 6, y + 6, k - 12, k * 0.3, k * 0.1);
        g.fill();
        g.fillStyle = 'rgba(255,255,255,.95)';
        g.shadowColor = 'rgba(0,0,0,.35)';
        g.shadowBlur = 4;
        g.font = `900 ${Math.round(k * 0.3)}px sans-serif`;
        g.textAlign = 'left';
        g.textBaseline = 'top';
        g.fillText(n === 100 ? '🏁' : String(n), x + k * 0.1, y + k * 0.1);
      }
      g.font = `900 ${Math.round(k * 0.34)}px sans-serif`;
      g.textAlign = 'center';
      g.fillStyle = '#e8437a';
      g.fillText('START', o + 0.5 * k, o + 9.55 * k);
    });
    const side = new THREE.MeshPhysicalMaterial({ color: 0x6fb7e8, roughness: 0.35, clearcoat: 0.8 });
    const top = new THREE.MeshPhysicalMaterial({ map: tex, roughness: 0.42, clearcoat: 0.5 });
    const base = new THREE.Mesh(G.roundedBox(S, 0.45, S, 0.2, 4), [side, side, top, side, side, side]);
    base.position.y = -0.225;
    base.receiveShadow = base.castShadow = true;
    root.add(base);
    const table = G.addTable('#a5734a', 90);
    table.position.y = -0.45;
    root.add(table);
    // start tray in front of the board
    const tray = new THREE.Mesh(G.roundedBox(5.6, 0.3, 1.6, 0.25, 4), new THREE.MeshPhysicalMaterial({ color: 0xffd1e3, roughness: 0.35, clearcoat: 0.9 }));
    tray.position.set(-1.6, -0.3, 6.35);
    G.shadowed(tray);
    root.add(tray);
    const dtray = new THREE.Mesh(G.roundedBox(2.4, 0.3, 1.9, 0.3, 4), new THREE.MeshPhysicalMaterial({ color: 0xfff1a8, roughness: 0.35, clearcoat: 0.9 }));
    dtray.position.set(3.4, -0.3, 6.4);
    G.shadowed(dtray);
    root.add(dtray);

    // ladders
    const wood = new THREE.MeshPhysicalMaterial({ map: G.woodTexture('#c98a4b', 9), roughness: 0.45, clearcoat: 0.5 });
    for (const [a, b] of Object.entries(LADDERS)) {
      const p1 = cellPos(+a, 0.12), p2 = cellPos(+b, 0.12);
      const d = p2.clone().sub(p1), len = d.length();
      const g = new THREE.Group();
      const n = new THREE.Vector3(-d.z, 0, d.x).normalize().multiplyScalar(0.2);
      for (const s of [1, -1]) {
        const rail = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, len + 0.3, 10), wood);
        rail.position.copy(p1.clone().add(p2).multiplyScalar(0.5).add(n.clone().multiplyScalar(s)));
        rail.position.y = 0.14;
        rail.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.clone().normalize());
        g.add(rail);
      }
      const steps = Math.max(2, Math.floor(len / 0.38));
      for (let i = 1; i < steps; i++) {
        const c = p1.clone().lerp(p2, i / steps);
        const rung = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.44, 8), wood);
        rung.position.set(c.x, 0.14, c.z);
        rung.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), n.clone().normalize());
        g.add(rung);
      }
      G.shadowed(g);
      root.add(g);
    }

    // snakes
    const SC = [['#2eae5a', '#ffe14d'], ['#e53950', '#ffd0d6'], ['#8e44ad', '#f6c1ff'], ['#f39c12', '#fff0b3'], ['#16a085', '#b8fff0'], ['#e84393', '#ffe0f0'], ['#2f7de1', '#cfe4ff'], ['#6ab04c', '#efffc9']];
    snakeHeads = [];
    let si = 0;
    for (const [a, b] of Object.entries(SNAKES)) {
      const [c1, c2] = SC[si++ % SC.length];
      const head = cellPos(+a, 0.18), tail = cellPos(+b, 0.12);
      const d = tail.clone().sub(head), n = new THREE.Vector3(-d.z, 0, d.x).normalize();
      const pts = [];
      const waves = Math.max(2, Math.round(d.length() / 1.6));
      for (let i = 0; i <= 24; i++) {
        const t = i / 24;
        const p = head.clone().lerp(tail, t).add(n.clone().multiplyScalar(Math.sin(t * Math.PI * waves) * 0.45 * Math.sin(Math.PI * Math.min(1, t * 1.2))));
        p.y = 0.16 + Math.sin(t * Math.PI * waves * 2) * 0.03;
        pts.push(p);
      }
      const curve = new THREE.CatmullRomCurve3(pts);
      const TS = 120, RS = 14;
      const geo = new THREE.TubeGeometry(curve, TS, 0.15, RS, false);
      // taper towards the tail
      const pa = geo.attributes.position, v = new THREE.Vector3();
      for (let i = 0; i <= TS; i++) {
        const t = i / TS, c = curve.getPointAt(t), k = 1 - t * 0.78;
        for (let j = 0; j <= RS; j++) {
          const idx = i * (RS + 1) + j;
          v.fromBufferAttribute(pa, idx).sub(c).multiplyScalar(k).add(c);
          pa.setXYZ(idx, v.x, v.y, v.z);
        }
      }
      geo.computeVertexNormals();
      const skin = G.canvasTex(256, 64, (g, w, h) => {
        g.fillStyle = c1;
        g.fillRect(0, 0, w, h);
        for (let x = 0; x < w; x += 32) {
          g.fillStyle = c2;
          g.beginPath();
          g.ellipse(x + 16, h / 2, 9, h / 2, 0, 0, Math.PI * 2);
          g.fill();
          g.fillStyle = G.shade(c1, -0.12);
          g.beginPath();
          g.ellipse(x, h / 2, 5, h * 0.3, 0, 0, Math.PI * 2);
          g.fill();
        }
      });
      skin.wrapS = skin.wrapT = THREE.RepeatWrapping;
      skin.repeat.set(10, 1);
      const body = new THREE.Mesh(geo, new THREE.MeshPhysicalMaterial({ map: skin, roughness: 0.3, clearcoat: 1, clearcoatRoughness: 0.15 }));
      G.shadowed(body);
      root.add(body);
      // head
      const hg = new THREE.Group();
      const hm = new THREE.Mesh(new THREE.SphereGeometry(0.26, 24, 18), new THREE.MeshPhysicalMaterial({ color: c1, roughness: 0.3, clearcoat: 1 }));
      hm.scale.set(1, 0.7, 1.25);
      hg.add(hm);
      const eyeW = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.2 });
      const eyeB = new THREE.MeshStandardMaterial({ color: 0x111111, roughness: 0.1 });
      for (const s of [-1, 1]) {
        const e = new THREE.Mesh(new THREE.SphereGeometry(0.08, 14, 10), eyeW);
        e.position.set(s * 0.13, 0.13, 0.12);
        const p = new THREE.Mesh(new THREE.SphereGeometry(0.045, 10, 8), eyeB);
        p.position.set(s * 0.14, 0.16, 0.18);
        hg.add(e, p);
      }
      const tongue = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.015, 0.25), new THREE.MeshStandardMaterial({ color: 0xff2a4a }));
      tongue.position.set(0, -0.02, 0.38);
      hg.add(tongue);
      hg.position.copy(head);
      hg.position.y = 0.24;
      const dir = curve.getTangentAt(0).negate();
      hg.rotation.y = Math.atan2(dir.x, dir.z);
      G.shadowed(hg);
      root.add(hg);
      snakeHeads.push({ g: hg, tongue, phase: Math.random() * 6 });
      body.userData.curve = curve;
      SNAKES_CURVE[a] = curve;
    }
  }
  const SNAKES_CURVE = {};

  G.onFrame.push((dt, t) => {
    for (const s of snakeHeads) {
      s.tongue.scale.z = 0.6 + Math.abs(Math.sin(t * 7 + s.phase)) * 0.8;
      s.g.position.y = 0.24 + Math.sin(t * 2 + s.phase) * 0.03;
    }
  });

  function spot(p) {
    const n = posn[p];
    if (n === 0) return new THREE.Vector3(-3.9 + p * 1.25, 0, 6.35);
    return cellPos(n, 0);
  }
  function layout(animate) {
    const groups = {};
    posn.forEach((n, p) => (groups[n] = groups[n] || []).push(p));
    const tw = [];
    for (const [n, ps] of Object.entries(groups)) {
      ps.forEach((p, j) => {
        const base = spot(p);
        const off = +n > 0 && ps.length > 1 ? new THREE.Vector3(((j % 2) - 0.5) * 0.4, 0, (Math.floor(j / 2) - 0.5) * 0.4) : new THREE.Vector3();
        const to = base.add(off);
        const sc = +n > 0 && ps.length > 1 ? 0.6 : 0.85;
        const m = pawns[p];
        if (!animate) { m.position.copy(to); m.scale.setScalar(sc); m.userData.baseScale = sc; }
        else {
          const from = m.position.clone(), s0 = m.scale.y;
          tw.push(G.tween(200, (k) => { m.position.lerpVectors(from, to, k); m.scale.setScalar(s0 + (sc - s0) * k); }).then(() => (m.userData.baseScale = sc)));
        }
      });
    }
    return Promise.all(tw);
  }

  const cur = () => players[turn];
  function hud() {
    G.players(players.map((p, i) => ({ name: p.name, color: PCOL[i], bot: p.bot, extra: posn[i] ? '· ' + posn[i] : '' })), turn);
    const rb = G.$('roll');
    rb.style.display = 'block';
    rb.classList.toggle('off', cur().bot || busy || over);
    rb.style.background = `linear-gradient(${G.shade(PCOL[turn], 0.15)}, ${PCOL[turn]})`;
  }

  async function roll() {
    if (busy || over) return;
    busy = true;
    hud();
    dice = 1 + Math.floor(Math.random() * 6);
    await G.rollDice(diceMesh, dice, new THREE.Vector3(3.4, -0.15, 6.4));
    const p = turn, m = pawns[p];
    if (posn[p] + dice > 100) {
      G.status(cur().name + ' needs exactly ' + (100 - posn[p]) + ' 🙈');
      await G.wait(900);
    } else {
      m.userData.baseScale = 0.85;
      m.scale.setScalar(0.85);
      for (let i = 0; i < dice; i++) {
        posn[p]++;
        G.snd.hop();
        await G.hopTo(m, cellPos(posn[p], 0), 230, 0.5);
      }
      G.snd.wood();
      const at = posn[p];
      if (LADDERS[at]) {
        G.toast('🪜 Ladder! Climb up!');
        G.snd.ladder();
        G.haptic('medium');
        const from = m.position.clone(), to = cellPos(LADDERS[at], 0);
        await G.tween(900, (k) => { m.position.lerpVectors(from, to, k); m.position.y = 0.15 + Math.sin(k * Math.PI) * 0.4; }, G.ease.inOut);
        posn[p] = LADDERS[at];
      } else if (SNAKES[at]) {
        G.toast('🐍 Ssss! Snake bite!');
        G.snd.snake();
        G.haptic('heavy');
        const curve = SNAKES_CURVE[at];
        await G.wait(200);
        await G.tween(1300, (k) => { const q = curve.getPointAt(k); m.position.set(q.x, q.y + 0.1, q.z); m.rotation.y = k * Math.PI * 4; }, G.ease.inOut);
        m.rotation.y = 0;
        posn[p] = SNAKES[at];
      } else {
        G.status(cur().name + ' rolled ' + dice);
      }
      await layout(true);
      if (posn[p] === 100) {
        over = true;
        hud();
        G.confetti(new THREE.Vector3(0, 0, 0), 10);
        G.status(cur().name + ' wins! 🎉');
        G.winScreen(cur().name + ' wins! 🎉', 'Reached 100 first', restart);
        return;
      }
    }
    await G.wait(400);
    if (dice !== 6) turn = (turn + 1) % players.length;
    else G.snd.six();
    busy = false;
    G.status(dice === 6 ? cur().name + ' rolled 6 – roll again! 🎲' : cur().name + "'s turn");
    hud();
    if (cur().bot) setTimeout(() => { if (!busy && cur().bot) roll(); }, 800);
  }

  function restart() {
    posn = players.map(() => 0);
    turn = 0;
    busy = over = false;
    if (root) G.scene.remove(root);
    root = new THREE.Group();
    G.scene.add(root);
    buildBoard();
    pawns = players.map((p, i) => { const m = makePawn(PCOL[i], 1); root.add(m); return m; });
    layout(false);
    diceMesh = G.makeDice(0.8);
    diceMesh.position.set(3.4, 0.25, 6.4);
    root.add(diceMesh);
    G.status(cur().name + ', roll the dice! 🎲');
    hud();
    if (cur().bot) setTimeout(roll, 900);
  }

  window.Snakes3D = {
    start(c) {
      players = c.players;
      G.$('title').textContent = '🐍 Snakes & Ladders';
      G.$('actions').innerHTML = '';
      G.$('roll').onclick = () => { if (!cur().bot) roll(); };
      G.onTap = (x, y) => { if (G.pick(x, y, [diceMesh]).length && !cur().bot) roll(); };
      G.orbit.minR = 8;
      G.orbit.maxR = 36;
      restart();
      G.setView(new THREE.Vector3(0, 0, 1.2), 0.72, G.fitRadius(11.8, 0.72), 0);
    },
  };
})();

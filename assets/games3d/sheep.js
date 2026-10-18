/* Sheep Fight – send sheep down 5 lanes; heavier herds push harder; get sheep to the other side. */
'use strict';
(function () {
  const LANES = 5, L = 11, LANE_W = 1.45, SPEED = 1.7, TARGET = 30, COOLDOWN = 1.1;
  const TEAM = [{ name: 'White', wool: 0xffffff, face: 0x2b2b2b, col: '#2f7de1' }, { name: 'Black', wool: 0x3a3236, face: 0x111111, col: '#e53950' }];
  const laneX = (l) => (l - (LANES - 1) / 2) * LANE_W;

  let players = [], sheep = [], score = [0, 0], queue = [[], []], cd = [0, 0], over = false, nextId = 1, root, meshes = new Map();
  let lastNow = 0, simOn = false, acc = 0, sendAcc = 0, botT = [1.5, 2], rnd = Math.random, lastState = null;

  const weightPick = () => { const r = rnd(); return r < 0.38 ? 1 : r < 0.68 ? 2 : r < 0.9 ? 3 : 4; };
  const len = (w) => 0.72 + w * 0.12;
  const teamOf = (i) => i % 2;

  // ───────── scene ─────────
  function buildField() {
    if (root) G.scene.remove(root);
    root = new THREE.Group();
    G.scene.add(root);
    G.setBackground('#9fd8ff', '#e8f6ff');
    G.scene.fog = new THREE.Fog(0xcfeaff, 30, 70);
    const grass = G.canvasTex(512, 512, (g, w, h) => {
      g.fillStyle = '#5cb85c';
      g.fillRect(0, 0, w, h);
      for (let i = 0; i < 9000; i++) {
        g.strokeStyle = ['#4fa94f', '#6cc66c', '#58b358', '#7bd07b'][i % 4];
        g.lineWidth = 1;
        const x = Math.random() * w, y = Math.random() * h;
        g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.random() * 2 - 1, y - 3 - Math.random() * 4); g.stroke();
      }
    }, 10);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(90, 90), new THREE.MeshStandardMaterial({ map: grass, roughness: 1 }));
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    root.add(ground);
    // lanes: dirt paths
    const dirt = G.canvasTex(256, 512, (g, w, h) => {
      g.fillStyle = '#c99a63';
      g.fillRect(0, 0, w, h);
      for (let i = 0; i < 2500; i++) { g.fillStyle = ['#b98a55', '#d6a870', '#a77a48'][i % 3]; g.fillRect(Math.random() * w, Math.random() * h, 2 + Math.random() * 3, 2 + Math.random() * 3); }
    });
    for (let l = 0; l < LANES; l++) {
      const p = new THREE.Mesh(new THREE.PlaneGeometry(LANE_W * 0.86, L), new THREE.MeshStandardMaterial({ map: dirt, roughness: 1 }));
      p.rotation.x = -Math.PI / 2;
      p.position.set(laneX(l), 0.01, 0);
      p.receiveShadow = true;
      root.add(p);
    }
    // fences between lanes
    const wood = new THREE.MeshStandardMaterial({ map: G.woodTexture('#a8743f', 3), roughness: 0.8 });
    for (let f = 0; f <= LANES; f++) {
      const x = (f - LANES / 2) * LANE_W;
      for (let z = -L / 2; z <= L / 2 + 0.01; z += 1.3) {
        const post = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.07, 0.6, 8), wood);
        post.position.set(x, 0.3, z);
        root.add(post);
      }
      for (const y of [0.22, 0.45]) {
        const rail = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.07, L), wood);
        rail.position.set(x, y, 0);
        root.add(rail);
      }
    }
    G.shadowed(root);
    // home pens
    for (const side of [0, 1]) {
      const pen = new THREE.Mesh(G.roundedBox(LANES * LANE_W + 0.6, 0.25, 1.6, 0.2, 3), new THREE.MeshPhysicalMaterial({ color: new THREE.Color(TEAM[side].col), roughness: 0.4, clearcoat: 0.6 }));
      pen.position.set(0, 0.12, side === 0 ? L / 2 + 1 : -L / 2 - 1);
      G.shadowed(pen);
      root.add(pen);
    }
    // trees and clouds of decoration
    for (let i = 0; i < 14; i++) {
      const t = new THREE.Group();
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.2, 1.2, 8), wood);
      trunk.position.y = 0.6;
      const top = new THREE.Mesh(new THREE.SphereGeometry(0.9, 14, 12), new THREE.MeshStandardMaterial({ color: [0x3f9b3f, 0x4caf50, 0x2e7d32][i % 3], roughness: 0.9 }));
      top.position.y = 1.7;
      t.add(trunk, top);
      const side = i % 2 ? 1 : -1;
      t.position.set(side * (5.6 + Math.random() * 4), 0, -L / 2 + Math.random() * L * 1.2);
      G.shadowed(t);
      root.add(t);
    }
  }

  function makeSheep(side, w) {
    const g = new THREE.Group();
    const woolM = new THREE.MeshStandardMaterial({ color: TEAM[side].wool, roughness: 0.95 });
    const faceM = new THREE.MeshStandardMaterial({ color: TEAM[side].face, roughness: 0.6 });
    const body = new THREE.Group();
    const puffs = [[0, 0.42, 0, 0.32], [0.17, 0.48, 0.12, 0.22], [-0.17, 0.48, 0.12, 0.22], [0.17, 0.46, -0.14, 0.22], [-0.17, 0.46, -0.14, 0.22], [0, 0.58, 0, 0.24], [0, 0.45, 0.24, 0.2], [0, 0.45, -0.26, 0.21]];
    for (const [x, y, z, r] of puffs) {
      const m = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 10), woolM);
      m.position.set(x, y, z);
      body.add(m);
    }
    g.add(body);
    const head = new THREE.Group();
    const hm = new THREE.Mesh(new THREE.SphereGeometry(0.14, 14, 12), faceM);
    hm.scale.set(1, 1.1, 1.35);
    head.add(hm);
    const fluff = new THREE.Mesh(new THREE.SphereGeometry(0.1, 10, 8), woolM);
    fluff.position.set(0, 0.11, -0.02);
    head.add(fluff);
    for (const s of [-1, 1]) {
      const ear = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 6), faceM);
      ear.scale.set(1.6, 0.6, 0.8);
      ear.position.set(s * 0.15, 0.04, -0.02);
      head.add(ear);
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.035, 8, 6), new THREE.MeshStandardMaterial({ color: 0xffffff }));
      eye.position.set(s * 0.07, 0.05, 0.13);
      const pu = new THREE.Mesh(new THREE.SphereGeometry(0.018, 6, 6), new THREE.MeshStandardMaterial({ color: 0x000000 }));
      pu.position.set(s * 0.07, 0.05, 0.16);
      head.add(eye, pu);
    }
    if (w >= 4) {
      // a ram gets curly horns
      for (const s of [-1, 1]) {
        const horn = new THREE.Mesh(new THREE.TorusGeometry(0.08, 0.03, 8, 14, Math.PI * 1.5), new THREE.MeshStandardMaterial({ color: 0xd8c39a, roughness: 0.5 }));
        horn.position.set(s * 0.13, 0.08, -0.03);
        horn.rotation.y = Math.PI / 2;
        head.add(horn);
      }
    }
    head.position.set(0, 0.55, 0.36);
    g.add(head);
    const legs = [];
    for (const [x, z] of [[-0.13, 0.15], [0.13, 0.15], [-0.13, -0.15], [0.13, -0.15]]) {
      const lg = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.3, 6), faceM);
      lg.position.set(x, 0.15, z);
      g.add(lg);
      legs.push(lg);
    }
    // weight badge
    const tag = new THREE.Sprite(new THREE.SpriteMaterial({ map: G.canvasTex(64, 64, (c) => {
      c.fillStyle = TEAM[side].col; c.beginPath(); c.arc(32, 32, 28, 0, 7); c.fill();
      c.lineWidth = 5; c.strokeStyle = '#fff'; c.stroke();
      c.fillStyle = '#fff'; c.font = 'bold 36px sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(String(w), 32, 34);
    }), depthTest: false }));
    tag.scale.set(0.32, 0.32, 1);
    tag.position.y = 1.0;
    g.add(tag);
    const k = 0.95 + w * 0.2;
    g.scale.setScalar(k);
    g.rotation.y = side === 0 ? Math.PI : 0; // face the way they walk
    g.userData = { legs, body, head, side };
    G.shadowed(g);
    return g;
  }

  // ───────── simulation (on the host / single phone) ─────────
  function spawn(side, lane) {
    if (over || cd[side] > 0 || lane < 0 || lane >= LANES) return false;
    const z0 = side === 0 ? L / 2 : -L / 2;
    if (sheep.some((s) => s.lane === lane && Math.abs(s.z - z0) < 0.9)) return false;
    const w = queue[side].shift();
    queue[side].push(weightPick());
    sheep.push({ id: nextId++, lane, side, w, z: z0, v: 0 });
    cd[side] = COOLDOWN;
    return true;
  }

  function simStep(dt) {
    cd[0] = Math.max(0, cd[0] - dt);
    cd[1] = Math.max(0, cd[1] - dt);
    for (let l = 0; l < LANES; l++) {
      const ls = sheep.filter((s) => s.lane === l).sort((a, b) => a.z - b.z);
      // groups of sheep touching each other
      const groups = [];
      for (const s of ls) {
        const g = groups[groups.length - 1];
        const prev = g && g[g.length - 1];
        if (prev && s.z - prev.z < (len(s.w) + len(prev.w)) / 2 + 0.02) g.push(s);
        else groups.push([s]);
      }
      for (const g of groups) {
        let wb = 0, wt = 0;
        for (const s of g) (s.side === 0 ? (wb += s.w) : (wt += s.w));
        let v;
        if (!wt) v = -SPEED;
        else if (!wb) v = SPEED;
        else v = -SPEED * 0.55 * ((wb - wt) / (wb + wt));
        for (const s of g) { s.z += v * dt; s.v = v; s.push = wb && wt; }
      }
      // keep them from walking through each other
      ls.sort((a, b) => a.z - b.z);
      for (let i = 1; i < ls.length; i++) {
        const need = (len(ls[i].w) + len(ls[i - 1].w)) / 2;
        if (ls[i].z - ls[i - 1].z < need) {
          if (ls[i].side === 0) ls[i].z = ls[i - 1].z + need; // bottom sheep waits behind
          else ls[i - 1].z = ls[i].z - need;
        }
      }
    }
    // scoring
    for (const s of sheep.slice()) {
      if (s.side === 0 && s.z < -L / 2 - 0.3) { score[0] += s.w; sheep.splice(sheep.indexOf(s), 1); scored(0, s.w); }
      else if (s.side === 1 && s.z > L / 2 + 0.3) { score[1] += s.w; sheep.splice(sheep.indexOf(s), 1); scored(1, s.w); }
    }
    if (!over && (score[0] >= TARGET || score[1] >= TARGET)) finish(score[0] >= TARGET ? 0 : 1);
  }

  function scored(side, w) {
    G.snd.point(players.some((p, i) => teamOf(i) === side && G.mine(p)));
    G.toast(`+${w} ${teamName(side)} 🐑`, 900);
    const bot = players.find((p, i) => teamOf(i) === side && p.bot);
    if (bot && w >= 3) G.botTease(bot, ['😈', '😂', '💪', '🐑']);
  }

  const teamName = (side) => {
    const ps = players.filter((p, i) => teamOf(i) === side).map((p) => p.name);
    return ps.join(' & ') || TEAM[side].name;
  };

  function finish(side) {
    over = true;
    G.confetti(new THREE.Vector3(0, 0, 0), 10);
    G.status(teamName(side) + ' win! 🎉');
    G.winScreen(teamName(side) + ' win! 🐑🎉', `${score[0]} – ${score[1]}`, () => {
      if (G.runsBots()) restartSim();
    });
  }

  function bots(dt) {
    for (const side of [0, 1]) {
      const humans = players.some((p, i) => teamOf(i) === side && !p.bot);
      if (humans) continue;
      botT[side] -= dt;
      if (botT[side] > 0 || cd[side] > 0) continue;
      botT[side] = 0.9 + rnd() * 1.4;
      // defend the lane where the enemy pushes hardest, else attack the weakest lane
      let best = 0, bestScore = -1e9;
      for (let l = 0; l < LANES; l++) {
        let threat = 0, mine = 0;
        for (const s of sheep) if (s.lane === l) {
          const near = side === 0 ? (s.z + L / 2) / L : (L / 2 - s.z) / L; // 1 = close to my base
          if (s.side !== side) threat += s.w * (0.5 + near);
          else mine += s.w;
        }
        const val = threat * 1.2 - mine * 0.6 + rnd() * 1.5;
        if (val > bestScore) { bestScore = val; best = l; }
      }
      spawn(side, best);
    }
  }

  function restartSim() {
    sheep = [];
    score = [0, 0];
    queue = [[weightPick(), weightPick(), weightPick()], [weightPick(), weightPick(), weightPick()]];
    cd = [1.5, 1.5];
    over = false;
    simOn = true;
    G.$('win').classList.remove('show');
    G.status('Tap a lane to send your sheep! 🐑');
    if (G.net.online) G.sendState(packState());
  }

  const packState = () => ({ s: sheep.map((s) => [s.id, s.lane, s.side, s.w, Math.round(s.z * 100) / 100, s.push ? 1 : 0]), sc: score, q: queue.map((q) => q.slice(0, 3)), cd, over });

  // ───────── drawing ─────────
  let bumpT = 0;
  function syncMeshes(list, dt, t) {
    const seen = new Set();
    for (const s of list) {
      seen.add(s.id);
      let m = meshes.get(s.id);
      if (!m) {
        m = makeSheep(s.side, s.w);
        m.position.set(laneX(s.lane), 0, s.z);
        root.add(m);
        meshes.set(s.id, m);
        m.userData.z = s.z;
        G.snd.baa(s.side);
      }
      if (s.push && !m.userData.push && t - bumpT > 0.25) {
        bumpT = t;
        G.snd.bump();
        if (Math.random() < 0.35) G.snd.baa(s.side);
      }
      m.userData.push = s.push;
      m.userData.z += (s.z - m.userData.z) * Math.min(1, dt * 12);
      m.position.x = laneX(s.lane);
      m.position.z = m.userData.z;
      const walk = t * 10 + s.id;
      m.userData.legs.forEach((lg, i) => (lg.rotation.x = Math.sin(walk + (i % 2 ? Math.PI : 0)) * 0.5));
      m.userData.body.position.y = Math.abs(Math.sin(walk)) * 0.04;
      m.rotation.x = s.push ? (s.side === 0 ? -0.12 : 0.12) : 0; // lean into the push
    }
    for (const [id, m] of meshes) if (!seen.has(id)) { root.remove(m); meshes.delete(id); }
  }

  // ───────── HUD ─────────
  let hud = {};
  function buildHud() {
    const old = document.getElementById('sheepHud');
    if (old) old.remove();
    const st = document.createElement('style');
    st.textContent = `
      #sheepHud { position: fixed; inset: 0; pointer-events: none; z-index: 5; }
      .lanes { position: absolute; left: 0; right: 0; display: flex; justify-content: center; gap: 6px; padding: 0 8px; pointer-events: auto; }
      .lanes.bottom { bottom: calc(env(safe-area-inset-bottom) + 12px); }
      .lanes.top { top: 64px; transform: rotate(180deg); }
      .lanes button { flex: 1; max-width: 72px; height: 64px; border: none; border-radius: 18px; font-size: 26px; color: #fff; font-weight: 900;
        box-shadow: 0 6px 0 rgba(0,0,0,.25), 0 8px 14px rgba(0,0,0,.3); }
      .lanes button:active { transform: translateY(5px); box-shadow: 0 1px 0 rgba(0,0,0,.25); }
      .lanes.cool button { filter: grayscale(.7) brightness(.85); }
      .next { position: absolute; display: flex; align-items: center; gap: 6px; font-weight: 900; color: #fff; text-shadow: 0 2px 4px rgba(0,0,0,.6); font-size: 14px; }
      .next.bottom { left: 14px; bottom: calc(env(safe-area-inset-bottom) + 86px); }
      .next.top { right: 14px; top: 136px; transform: rotate(180deg); }
      .next .w { background: #fff; color: #333; border-radius: 12px; padding: 2px 8px; text-shadow: none; }
      .score { position: absolute; left: 12px; right: 12px; top: 64px; height: 26px; border-radius: 13px; background: rgba(255,255,255,.5); overflow: hidden; display: flex; box-shadow: inset 0 2px 4px rgba(0,0,0,.2); }
      .score .a, .score .b { height: 100%; transition: width .3s; display: flex; align-items: center; font-weight: 900; color: #fff; font-size: 13px; }
      .score .a { background: ${TEAM[0].col}; padding-left: 8px; } .score .b { background: ${TEAM[1].col}; margin-left: auto; justify-content: flex-end; padding-right: 8px; }
    `;
    document.head.appendChild(st);
    const h = document.createElement('div');
    h.id = 'sheepHud';
    document.body.appendChild(h);
    hud = { root: h, rows: [] };
    hud.score = document.createElement('div');
    hud.score.className = 'score';
    hud.score.innerHTML = '<div class="a"></div><div class="b"></div>';
    h.appendChild(hud.score);
  }

  function lanesRow(side, where) {
    const row = document.createElement('div');
    row.className = 'lanes ' + where;
    for (let l = 0; l < LANES; l++) {
      const b = document.createElement('button');
      b.style.background = `linear-gradient(${G.shade(TEAM[side].col, 0.15)}, ${TEAM[side].col})`;
      b.textContent = '🐑';
      const lane = side === 0 ? l : LANES - 1 - l;
      b.onpointerdown = (e) => { e.preventDefault(); G.haptic('light'); G.sendInput({ lane: where === 'top' ? LANES - 1 - l : lane, side }); };
      row.appendChild(b);
    }
    const nx = document.createElement('div');
    nx.className = 'next ' + where;
    hud.root.appendChild(row);
    hud.root.appendChild(nx);
    hud.rows.push({ side, row, nx });
  }

  function updateHud(st) {
    const sc = st.sc, total = TARGET;
    hud.score.querySelector('.a').style.width = Math.max(14, (sc[0] / total) * 50) + '%';
    hud.score.querySelector('.a').textContent = sc[0];
    hud.score.querySelector('.b').style.width = Math.max(14, (sc[1] / total) * 50) + '%';
    hud.score.querySelector('.b').textContent = sc[1];
    for (const r of hud.rows) {
      r.row.classList.toggle('cool', st.cd[r.side] > 0);
      r.nx.innerHTML = 'Next: ' + st.q[r.side].map((w, i) => `<span class="w" style="font-size:${i ? 11 : 15}px">🐑${w}</span>`).join('');
    }
  }

  // ───────── frame loop ─────────
  G.onFrame.push((dt, t) => {
    if (!root || !players.length) return;
    const now = performance.now();
    const real = Math.min(0.3, (now - (lastNow || now)) / 1000);
    lastNow = now;
    if (G.runsBots() && simOn) {
      acc += real;
      while (acc > 1 / 30) { simStep(1 / 30); bots(1 / 30); acc -= 1 / 30; }
      sendAcc += real;
      if (G.net.online && sendAcc > 0.1) { sendAcc = 0; G.sendState(packState()); }
      const st = packState();
      syncMeshes(sheep, dt, t);
      updateHud(st);
    } else if (lastState) {
      syncMeshes(lastState.s.map((a) => ({ id: a[0], lane: a[1], side: a[2], w: a[3], z: a[4], push: a[5] })), dt, t);
      updateHud(lastState);
    }
  });

  window.Sheep3D = {
    title: 'Sheep Fight', minPlayers: 2, maxPlayers: 4, colors: [TEAM[0].col, TEAM[1].col, TEAM[0].col, TEAM[1].col],
    init() {
      G.$('title').textContent = '🐑 Sheep Fight';
      G.$('actions').innerHTML = '';
      G.$('roll').style.display = 'none';
      G.$('players').style.display = 'none';
      G.$('bottom').style.bottom = 'calc(env(safe-area-inset-bottom) + 160px)';
      G.onTap = null;
      buildField();
      G.setView(new THREE.Vector3(0, 0, 0.8), 0.72, G.fitRadius(LANES * LANE_W + 1.5, 0.72) * 1.25, 0);
      buildHud();
    },
    makeSetup(list) { return { players: list.slice(0, 4) }; },
    begin(s) {
      players = s.players;
      const mySides = [...new Set(players.map((p, i) => (G.mine(p) ? teamOf(i) : -1)).filter((x) => x >= 0))];
      if (mySides.includes(0) || !mySides.length) lanesRow(0, 'bottom');
      if (mySides.includes(1)) {
        if (mySides.includes(0)) lanesRow(1, 'top'); // two people on one phone: other side gets the top
        else {
          hud.rows = [];
          lanesRow(1, 'bottom');
          G.setView(new THREE.Vector3(0, 0, -0.8), 0.72, G.orbit.radius, Math.PI);
        }
      }
      G.status(teamName(0) + ' 🆚 ' + teamName(1) + ' – first to ' + TARGET + ' points');
      G.snd.loop('meadow', 0.22);
      if (G.runsBots()) restartSim();
    },
    input(a, from) {
      if (!simOn) return;
      let side = a.side;
      if (G.net.online) {
        const i = players.findIndex((p) => p.id === from);
        if (i < 0) return;
        side = teamOf(i);
      }
      spawn(side === 1 ? 1 : 0, a.lane | 0);
    },
    state(s) {
      if (!lastState || s.over !== lastState.over) {
        if (s.over) { const w = s.sc[0] >= s.sc[1] ? 0 : 1; G.confetti(new THREE.Vector3(0, 0, 0), 10); G.winScreen(teamName(w) + ' win! 🐑🎉', `${s.sc[0]} – ${s.sc[1]}`, () => {}); }
        else G.$('win').classList.remove('show');
      }
      if (lastState && (s.sc[0] > lastState.sc[0] || s.sc[1] > lastState.sc[1])) { const sd = s.sc[0] > lastState.sc[0] ? 0 : 1; G.snd.point(players.some((p, i) => teamOf(i) === sd && G.mine(p))); }
      lastState = s;
    },
    apply() {},
  };
})();

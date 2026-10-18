/* Chess 3D – realistic board, Staunton pieces, 3 themes, computer opponent. */
'use strict';
(function () {
  // ───────── rules engine ─────────  board[r*8+c], r=0 top (black). + white, − black. 1P 2N 3B 4R 5Q 6K
  const KN = [[1, 2], [2, 1], [-1, 2], [-2, 1], [1, -2], [2, -1], [-1, -2], [-2, -1]];
  const KG = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
  const DI = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
  const OR = [[1, 0], [-1, 0], [0, 1], [0, -1]];

  function startPos() {
    return {
      b: [-4, -2, -3, -5, -6, -3, -2, -4, -1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 3, 5, 6, 3, 2, 4],
      side: 1, castle: 15, ep: -1,
    };
  }
  const copy = (p) => ({ b: p.b.slice(), side: p.side, castle: p.castle, ep: p.ep });
  const inB = (r, c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  function attacked(p, sq, by) {
    const b = p.b, r = sq >> 3, c = sq & 7;
    const pr = r + by;
    for (const dc of [-1, 1]) if (inB(pr, c + dc) && b[pr * 8 + c + dc] === by) return true;
    for (const d of KN) if (inB(r + d[0], c + d[1]) && b[(r + d[0]) * 8 + c + d[1]] === 2 * by) return true;
    for (const d of KG) {
      const diag = d[0] && d[1];
      let rr = r + d[0], cc = c + d[1], dist = 1;
      while (inB(rr, cc)) {
        const q = b[rr * 8 + cc];
        if (q) {
          if (q * by > 0) {
            const t = Math.abs(q);
            if (t === 5 || (diag && t === 3) || (!diag && t === 4) || (dist === 1 && t === 6)) return true;
          }
          break;
        }
        rr += d[0]; cc += d[1]; dist++;
      }
    }
    return false;
  }
  const kingSq = (p, s) => p.b.indexOf(6 * s);
  const inCheck = (p, s) => { const k = kingSq(p, s); return k >= 0 && attacked(p, k, -s); };

  function pseudo(p) {
    const out = [], s = p.side, b = p.b;
    for (let sq = 0; sq < 64; sq++) {
      const v = b[sq];
      if (v * s <= 0) continue;
      const t = Math.abs(v), r = sq >> 3, c = sq & 7;
      const add = (to) => {
        if (t === 1 && ((to >> 3) === 0 || (to >> 3) === 7)) for (const pr of [5, 4, 3, 2]) out.push([sq, to, pr]);
        else out.push([sq, to, 0]);
      };
      if (t === 1) {
        const nr = r - s;
        if (nr >= 0 && nr < 8) {
          if (!b[nr * 8 + c]) {
            add(nr * 8 + c);
            if (r === (s === 1 ? 6 : 1) && !b[(r - 2 * s) * 8 + c]) out.push([sq, (r - 2 * s) * 8 + c, 0]);
          }
          for (const dc of [-1, 1]) {
            if (!inB(nr, c + dc)) continue;
            const to = nr * 8 + c + dc;
            if (b[to] * s < 0 || to === p.ep) add(to);
          }
        }
      } else if (t === 2 || t === 6) {
        for (const d of t === 2 ? KN : KG) {
          const rr = r + d[0], cc = c + d[1];
          if (inB(rr, cc) && b[rr * 8 + cc] * s <= 0) out.push([sq, rr * 8 + cc, 0]);
        }
        if (t === 6) {
          const home = s === 1 ? 60 : 4;
          if (sq === home && !attacked(p, home, -s)) {
            const kb = s === 1 ? 1 : 4, qb = s === 1 ? 2 : 8;
            if (p.castle & kb && !b[home + 1] && !b[home + 2] && b[home + 3] === 4 * s && !attacked(p, home + 1, -s) && !attacked(p, home + 2, -s)) out.push([sq, home + 2, 0]);
            if (p.castle & qb && !b[home - 1] && !b[home - 2] && !b[home - 3] && b[home - 4] === 4 * s && !attacked(p, home - 1, -s) && !attacked(p, home - 2, -s)) out.push([sq, home - 2, 0]);
          }
        }
      } else {
        for (const d of t === 3 ? DI : t === 4 ? OR : KG) {
          let rr = r + d[0], cc = c + d[1];
          while (inB(rr, cc)) {
            const q = b[rr * 8 + cc];
            if (q * s > 0) break;
            out.push([sq, rr * 8 + cc, 0]);
            if (q) break;
            rr += d[0]; cc += d[1];
          }
        }
      }
    }
    return out;
  }

  function make(p, m) {
    const b = p.b, v = b[m[0]], t = Math.abs(v), s = Math.sign(v);
    let fx = null; // side effects for animation
    if (t === 1 && m[1] === p.ep) { fx = { ep: m[1] + 8 * s }; b[m[1] + 8 * s] = 0; }
    p.ep = t === 1 && Math.abs(m[1] - m[0]) === 16 ? (m[0] + m[1]) >> 1 : -1;
    if (t === 6 && Math.abs(m[1] - m[0]) === 2) {
      if (m[1] > m[0]) { b[m[1] - 1] = b[m[1] + 1]; b[m[1] + 1] = 0; fx = { rook: [m[1] + 1, m[1] - 1] }; }
      else { b[m[1] + 1] = b[m[1] - 2]; b[m[1] - 2] = 0; fx = { rook: [m[1] - 2, m[1] + 1] }; }
    }
    b[m[1]] = m[2] ? m[2] * s : v;
    b[m[0]] = 0;
    if (t === 6) p.castle &= s === 1 ? ~3 : ~12;
    for (const q of [m[0], m[1]]) {
      if (q === 63) p.castle &= ~1;
      if (q === 56) p.castle &= ~2;
      if (q === 7) p.castle &= ~4;
      if (q === 0) p.castle &= ~8;
    }
    p.side = -p.side;
    return fx;
  }

  function legal(p) {
    const out = [];
    for (const m of pseudo(p)) {
      const q = copy(p);
      make(q, m);
      if (!inCheck(q, p.side)) out.push(m);
    }
    return out;
  }

  // evaluation with simple piece-square bonuses
  const VAL = [0, 100, 320, 335, 500, 920, 0];
  function evalPos(p) {
    let s = 0;
    for (let sq = 0; sq < 64; sq++) {
      const v = p.b[sq];
      if (!v) continue;
      const t = Math.abs(v), r = sq >> 3, c = sq & 7;
      let x = VAL[t];
      const centre = 7 - Math.round(Math.abs(3.5 - r) + Math.abs(3.5 - c));
      if (t === 2 || t === 3) x += centre * 5;
      if (t === 1) x += (v > 0 ? 6 - r : r - 1) * 9 + (c >= 2 && c <= 5 ? 8 : 0);
      if (t === 5) x += centre * 2;
      if (t === 6) x += (v > 0 ? r === 7 : r === 0) && (c <= 2 || c >= 6) ? 25 : 0;
      s += v > 0 ? x : -x;
    }
    return s;
  }
  function search(p, depth, alpha, beta) {
    if (depth === 0) return evalPos(p) * p.side;
    const ms = legal(p);
    if (!ms.length) return inCheck(p, p.side) ? -100000 - depth : 0;
    ms.sort((a, b) => Math.abs(p.b[b[1]]) - Math.abs(p.b[a[1]]));
    for (const m of ms) {
      const q = copy(p);
      make(q, m);
      const v = -search(q, depth - 1, -beta, -alpha);
      if (v > alpha) alpha = v;
      if (alpha >= beta) break;
    }
    return alpha;
  }
  function bestMove(p, depth) {
    const ms = legal(p).sort(() => Math.random() - 0.5);
    ms.sort((a, b) => Math.abs(p.b[b[1]]) - Math.abs(p.b[a[1]]));
    let best = null, bv = -1e9;
    for (const m of ms) {
      const q = copy(p);
      make(q, m);
      const v = -search(q, depth - 1, -1e9, -bv) + Math.random() * 12;
      if (v > bv || !best) { bv = v; best = m; }
    }
    return best;
  }

  // ───────── themes ─────────
  const THEMES = [
    { name: '🪵 Classic Wood', light: '#ecd3a5', dark: '#a4693a', frame: '#5b331b', text: '#f3d9a6', table: '#8f6440', bg: ['#4a3426', '#140d09'],
      white: { color: '#f2ddb6', wood: true, rough: 0.32 }, black: { color: '#3e2415', wood: true, rough: 0.3 } },
    { name: '🍬 Candy Pink', light: '#fff0f6', dark: '#f39cc3', frame: '#c2185b', text: '#ffe3ee', table: '#ffd3e4', bg: ['#ffe0ee', '#c06a9b'],
      white: { color: '#fffafc', rough: 0.18 }, black: { color: '#b3125e', rough: 0.18 } },
    { name: '🌊 Ocean Night', light: '#dbeaff', dark: '#3d61a6', frame: '#101f40', text: '#9cc3ff', table: '#1b2a48', bg: ['#132a52', '#03060d'],
      white: { color: '#e6f1ff', rough: 0.12, metal: 0.35 }, black: { color: '#1a3170', rough: 0.15, metal: 0.25 } },
  ];

  // ───────── 3D scene state ─────────
  let cfg, setup, players = [], pos, moves = [], history = [], theme = 0, root, boardMesh, pieces = {}, sel = -1, marks = [], lastMarks = [], busy = false, over = false;
  let matW, matB, graveW = 0, graveB = 0, checkMark = null;
  const PS = 1.22; // piece scale
  const sqPos = (sq, y) => new THREE.Vector3((sq & 7) - 3.5, y || 0, (sq >> 3) - 3.5);

  function pieceMat(spec) {
    const m = new THREE.MeshPhysicalMaterial({ color: spec.wood ? 0xffffff : spec.color, roughness: spec.rough, metalness: spec.metal || 0, clearcoat: 0.9, clearcoatRoughness: 0.12 });
    if (spec.wood) m.map = G.canvasTex(256, 256, (g, w, h) => G.woodGrain(g, 0, 0, w, h, spec.color, 11, 1.4));
    return m;
  }

  function buildBoard() {
    const th = THEMES[theme];
    G.setBackground(th.bg[0], th.bg[1]);
    const S = 9.4, border = 0.7;
    const tex = G.canvasTex(1024, 1024, (g, W) => {
      const k = W / S;
      G.woodGrain(g, 0, 0, W, W, th.frame, 3, 1.2);
      // inner bevel line
      g.strokeStyle = 'rgba(255,255,255,.25)';
      g.lineWidth = 3;
      g.strokeRect(border * k - 6, border * k - 6, 8 * k + 12, 8 * k + 12);
      for (let r = 0; r < 8; r++) {
        for (let c = 0; c < 8; c++) {
          const light = (r + c) % 2 === 0;
          const x = border * k + c * k, y = border * k + r * k;
          if (th.frame === '#5b331b') G.woodGrain(g, x, y, k + 1, k + 1, light ? th.light : th.dark, 17 + r * 8 + c, 0.8);
          else {
            const gr = g.createLinearGradient(x, y, x + k, y + k);
            gr.addColorStop(0, G.shade(light ? th.light : th.dark, 0.04));
            gr.addColorStop(1, G.shade(light ? th.light : th.dark, -0.04));
            g.fillStyle = gr;
            g.fillRect(x, y, k + 1, k + 1);
            // marble veins for ocean
            if (theme === 2) {
              g.strokeStyle = 'rgba(255,255,255,.12)';
              g.lineWidth = 1.5;
              g.beginPath();
              g.moveTo(x, y + Math.random() * k);
              g.bezierCurveTo(x + k * 0.3, y + Math.random() * k, x + k * 0.7, y + Math.random() * k, x + k, y + Math.random() * k);
              g.stroke();
            }
          }
        }
      }
      g.fillStyle = th.text;
      g.font = `bold ${Math.round(k * 0.32)}px sans-serif`;
      g.textAlign = 'center';
      g.textBaseline = 'middle';
      for (let i = 0; i < 8; i++) {
        g.fillText('abcdefgh'[i], border * k + (i + 0.5) * k, W - border * k * 0.5);
        g.fillText('abcdefgh'[i], border * k + (i + 0.5) * k, border * k * 0.5);
        g.fillText(String(8 - i), border * k * 0.5, border * k + (i + 0.5) * k);
        g.fillText(String(8 - i), W - border * k * 0.5, border * k + (i + 0.5) * k);
      }
    });
    const side = new THREE.MeshPhysicalMaterial({ map: G.woodTexture(th.frame, 5), roughness: 0.4, clearcoat: 0.6 });
    const top = new THREE.MeshPhysicalMaterial({ map: tex, roughness: 0.38, clearcoat: 0.7, clearcoatRoughness: 0.2 });
    boardMesh = new THREE.Mesh(G.roundedBox(S, 0.42, S, 0.06, 2), [side, side, top, side, side, side]);
    // the rounded box maps the top face UVs across the whole face – good
    boardMesh.position.y = -0.21;
    boardMesh.receiveShadow = true;
    boardMesh.castShadow = true;
    root.add(boardMesh);
    const table = G.addTable(th.table, 70);
    table.position.y = -0.42;
    root.add(table);
    matW = pieceMat(th.white);
    matB = pieceMat(th.black);
  }

  function spawn(sq, v) {
    const m = makeChessPiece(Math.abs(v), v > 0 ? matW : matB, v > 0 ? matB : matW);
    m.position.copy(sqPos(sq));
    m.scale.setScalar(PS);
    if (Math.abs(v) === 2) m.rotation.y = (v > 0 ? Math.PI / 2 : -Math.PI / 2) + ((sq & 7) < 4 ? 0.75 : -0.75) * (v > 0 ? 1 : -1);
    m.userData.sq = sq;
    m.traverse((o) => (o.userData.piece = m));
    root.add(m);
    pieces[sq] = m;
    return m;
  }

  function rebuild() {
    if (root) G.scene.remove(root);
    root = new THREE.Group();
    G.scene.add(root);
    pieces = {};
    graveW = graveB = 0;
    marks = [];
    lastMarks = [];
    checkMark = null;
    buildBoard();
    for (let sq = 0; sq < 64; sq++) if (pos.b[sq]) spawn(sq, pos.b[sq]);
    // re-place captured pieces for this game
    for (const v of capturedList()) toGrave(spawnLoose(v), v, true);
    refresh();
  }

  function capturedList() {
    const count = {}, out = [];
    const start = startPos().b;
    for (const v of start) count[v] = (count[v] || 0) + 1;
    for (const v of pos.b) if (v) count[v]--;
    // promotions can make counts negative – ignore
    for (const k of Object.keys(count)) for (let i = 0; i < count[k]; i++) if (+k !== 0) out.push(+k);
    return out;
  }
  function spawnLoose(v) {
    const m = makeChessPiece(Math.abs(v), v > 0 ? matW : matB, v > 0 ? matB : matW);
    root.add(m);
    return m;
  }
  function toGrave(m, v, instant) {
    const white = v > 0;
    const i = white ? graveW++ : graveB++;
    // white's lost pieces wait behind the board, black's in front of it
    const to = new THREE.Vector3(-3.9 + (i % 8) * 1.1 + Math.floor(i / 8) * 0.55, -0.42, white ? -5.6 - Math.floor(i / 8) * 0.9 : 5.6 + Math.floor(i / 8) * 0.9);
    m.userData.sq = -1;
    if (instant) { m.position.copy(to); m.scale.setScalar(0.9); return Promise.resolve(); }
    return G.hopTo(m, to, 520, 1.6).then(() => { m.scale.setScalar(0.9); m.userData.baseScale = 0.9; });
  }

  function clearMarks() {
    for (const m of marks) root.remove(m);
    marks = [];
  }
  function markSq(sq, color, kind) {
    let m;
    if (kind === 'dot') m = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.14, 0.02, 24), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.75 }));
    else if (kind === 'ring') { m = makeRing(color, 0.42); }
    else {
      m = new THREE.Mesh(new THREE.PlaneGeometry(0.98, 0.98), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.45, depthWrite: false }));
      m.rotation.x = -Math.PI / 2;
    }
    m.position.copy(sqPos(sq, kind === 'sq' ? 0.004 : 0.012));
    root.add(m);
    return m;
  }

  function refresh() {
    moves = legal(pos);
    if (checkMark) { root.remove(checkMark); checkMark = null; }
    const chk = inCheck(pos, pos.side);
    if (chk) {
      checkMark = markSq(kingSq(pos, pos.side), 0xff2020, 'sq');
      checkMark.material.opacity = 0.65;
    }
    const wn = players[0].name, bn = players[1].name;
    G.players([
      { name: wn, color: THEMES[theme].white.color === '#fffafc' ? '#e9a3c4' : '#d9b98a', bot: players[0].bot },
      { name: bn, color: THEMES[theme].black.color, bot: players[1].bot },
    ], pos.side === 1 ? 0 : 1);
    if (!moves.length) {
      over = true;
      const winner = pos.side === 1 ? bn : wn;
      if (chk) {
        G.status('Checkmate! ♛');
        setTimeout(() => {
          G.confetti(new THREE.Vector3(0, 0, 0), 10);
          G.winScreen(winner + ' wins! 🎉', 'Checkmate', rematch);
        }, 700);
      } else {
        G.status('Stalemate – draw 🤝');
        setTimeout(() => G.winScreen("It's a draw 🤝", 'Stalemate', rematch), 700);
      }
      return;
    }
    over = false;
    const cur = players[pos.side === 1 ? 0 : 1];
    G.status((chk ? '⚠️ Check! ' : '') + cur.name + (cur.bot ? ' is thinking…' : G.mine(cur) ? ' – your move' : ' is moving…'));
  }

  async function animateMove(m, fx) {
    const piece = pieces[m[0]];
    const victimSq = fx && fx.ep != null ? fx.ep : m[1];
    const victim = pieces[victimSq];
    const vVal = victim ? (victim === piece ? 0 : posBefore.b[victimSq]) : 0;
    delete pieces[m[0]];
    if (victim && victim !== piece) delete pieces[victimSq];
    const t = Math.abs(posBefore.b[m[0]]);
    const dist = Math.hypot((m[1] & 7) - (m[0] & 7), (m[1] >> 3) - (m[0] >> 3));
    G.haptic('light');
    const hop = G.hopTo(piece, sqPos(m[1]), 260 + dist * 70, t === 2 ? 1.1 : 0.35 + dist * 0.06);
    if (victim && victim !== piece) {
      await G.wait(180 + dist * 50);
      G.snd.take();
      G.haptic('medium');
      { const mover = players[seatOf(posBefore.side)]; if (mover && mover.bot) G.botTease(mover, ['😎', '😈', '😂', '🤪']); }
      toGrave(victim, vVal);
    }
    await hop;
    G.snd.place();
    piece.userData.sq = m[1];
    pieces[m[1]] = piece;
    if (fx && fx.rook) {
      const r = pieces[fx.rook[0]];
      delete pieces[fx.rook[0]];
      await G.hopTo(r, sqPos(fx.rook[1]), 320, 0.7);
      G.snd.place();
      r.userData.sq = fx.rook[1];
      pieces[fx.rook[1]] = r;
    }
    if (m[2]) {
      root.remove(piece);
      const np = spawn(m[1], pos.b[m[1]]);
      np.scale.setScalar(0.01);
      G.snd.six();
      await G.tween(350, (k) => np.scale.setScalar(Math.max(0.01, k) * PS), G.ease.back);
    }
  }

  let posBefore = null;
  const seatOf = (side) => (side === 1 ? 0 : 1);
  async function doMove(m) {
    busy = true;
    clearMarks();
    sel = -1;
    history.push(copy(pos));
    posBefore = copy(pos);
    const fx = make(pos, m);
    await animateMove(m, fx);
    for (const lm of lastMarks) root.remove(lm);
    lastMarks = [markSq(m[0], 0xffe14d, 'sq'), markSq(m[1], 0xffe14d, 'sq')];
    refresh();
    if (inCheck(pos, pos.side)) { if (legal(pos).length) G.snd.check(); else G.snd.checkmate(); G.toast('Check! ⚠️'); }
    busy = false;
    if (over) return;
    nextTurn();
  }

  function nextTurn() {
    const cur = players[seatOf(pos.side)];
    if (G.botTurn(cur)) {
      busy = true;
      setTimeout(() => {
        const depth = Math.max(1, Math.min(3, setup.level || 2));
        const bm = bestMove(pos, depth);
        busy = false;
        if (bm) G.act({ m: bm, n: history.length });
      }, G.fast ? 0 : 350);
    } else if (!G.net.online && G.localHumans(players) > 1) {
      // two people on one phone: turn the board to whoever moves next
      turnCamera(pos.side === 1 ? 0 : Math.PI);
    }
  }

  function turnCamera(target) {
    const d = G.orbit.def;
    const from = G.orbit.theta;
    let dt = target - from;
    while (dt > Math.PI) dt -= Math.PI * 2;
    while (dt < -Math.PI) dt += Math.PI * 2;
    if (d) d.theta = target;
    G.tween(900, (k) => { G.orbit.theta = from + dt * k; G.updateCam(); });
  }

  function choosePromo(side) {
    return new Promise((res) => {
      const row = G.$('promoRow');
      row.innerHTML = '';
      for (const [t, g] of [[5, '♛'], [4, '♜'], [3, '♝'], [2, '♞']]) {
        const b = document.createElement('button');
        b.className = 'btn';
        b.style.fontSize = '34px';
        b.style.height = '64px';
        b.textContent = g;
        b.onclick = () => { G.$('promo').classList.remove('show'); res(t); };
        row.appendChild(b);
      }
      G.$('promo').classList.add('show');
    });
  }

  async function tap(x, y) {
    if (busy || over) return;
    if (!G.mine(players[seatOf(pos.side)])) return;
    // the square under the finger wins; tall pieces in front shouldn't steal the tap
    let sq = -1;
    const p = G.pickPlane(x, y, 0);
    if (p) {
      const c = Math.round(p.x + 3.5), r = Math.round(p.z + 3.5);
      if (inB(r, c)) sq = r * 8 + c;
    }
    const useful = (q) => q >= 0 && (pos.b[q] * pos.side > 0 || (sel >= 0 && moves.some((m) => m[0] === sel && m[1] === q)));
    if (!useful(sq)) {
      const hits = G.pick(x, y, Object.values(pieces));
      for (const h of hits) {
        const pc = h.object.userData.piece;
        if (pc && useful(pc.userData.sq)) { sq = pc.userData.sq; break; }
      }
    }
    if (sq < 0) return;
    if (sel >= 0) {
      const ms = moves.filter((m) => m[0] === sel && m[1] === sq);
      if (ms.length) {
        let m = ms[0];
        if (ms.length > 1) {
          const t = await choosePromo(pos.side);
          m = ms.find((q) => q[2] === t);
        }
        G.act({ m, n: history.length });
        return;
      }
    }
    if (pos.b[sq] * pos.side > 0) {
      sel = sq;
      clearMarks();
      G.snd.select();
      G.haptic('light');
      marks.push(markSq(sq, 0x3ddc84, 'sq'), markSq(sq, 0x3ddc84, 'ring'));
      const pc = pieces[sq];
      if (pc) G.tween(160, (k) => (pc.position.y = Math.sin(k * Math.PI) * 0.18));
      for (const m of moves) if (m[0] === sq) marks.push(markSq(m[1], pos.b[m[1]] ? 0xff4f5e : 0x2eae5a, pos.b[m[1]] ? 'ring' : 'dot'));
    } else {
      sel = -1;
      clearMarks();
    }
  }

  function newGame() {
    pos = startPos();
    history = [];
    sel = -1;
    busy = false;
    over = false;
    rebuild();
    // look from your own side of the board
    const meBlack = G.net.online && G.mine(players[1]) && !G.mine(players[0]);
    G.setView(new THREE.Vector3(0, 0, meBlack ? -0.5 : 0.5), 0.95, G.fitRadius(9.5, 0.95), meBlack ? Math.PI : 0);
    nextTurn();
  }
  const rematch = () => G.act({ t: 'new' });

  function undo() {
    if (G.net.online) { G.toast('Undo works only on one phone'); return; }
    if (busy || !history.length) return;
    G.act({ t: 'undo' });
  }

  window.Chess3D = {
    title: 'Chess', minPlayers: 2, maxPlayers: 2, colors: ['#e8d3a9', '#3e2415'],
    init(c) {
      cfg = c;
      theme = c.theme || 0;
      G.$('title').textContent = '♛ Chess 3D';
      const acts = G.$('actions');
      acts.innerHTML = '';
      const mk = (txt, fn) => { const b = document.createElement('button'); b.className = 'btn'; b.textContent = txt; b.onclick = fn; acts.appendChild(b); return b; };
      mk('↶ Undo', undo);
      const tb = mk(THEMES[theme].name, () => {
        theme = (theme + 1) % THEMES.length;
        tb.textContent = THEMES[theme].name;
        G.post('theme:' + theme);
        rebuild();
        G.snd.select();
      });
      mk('⟳ New', () => { if (G.net.online && !over) { G.toast('Finish this game first 🙂'); return; } rematch(); });
      G.onTap = tap;
      G.orbit.minR = 7;
      G.orbit.maxR = 30;
      // show an empty board while the room fills up
      players = [{ name: c.white || 'White' }, { name: c.black || 'Black' }];
      pos = startPos();
      rebuild();
      G.setView(new THREE.Vector3(0, 0, 0.5), 0.95, G.fitRadius(9.5, 0.95), 0);
    },
    makeSetup(list) {
      let ps = list;
      if (!G.net.online) ps = [{ name: cfg.white || 'White', bot: false }, { name: cfg.vsComputer ? 'Computer' : cfg.black || 'Black', bot: !!cfg.vsComputer }];
      while (ps.length < 2) ps.push({ name: 'Computer', bot: true, id: 'bot' });
      return { players: ps.slice(0, 2), level: cfg.level || 2 };
    },
    begin(s) {
      setup = s;
      players = s.players;
      newGame();
    },
    allowed(a, from) {
      if (a.t === 'new') return over || from === G.net.myId;
      if (a.t === 'undo') return false;
      const cur = players[seatOf(pos.side)];
      return cur.id === from || (cur.bot && from === G.net.myId);
    },
    async apply(a) {
      if (a.t === 'new') { newGame(); G.snd.wood(); return; }
      if (a.t === 'undo') {
        if (!history.length) return;
        if (players.some((p) => p.bot) && history.length >= 2 && players[seatOf(pos.side)] && !players[seatOf(pos.side)].bot) history.pop();
        pos = history.pop();
        sel = -1;
        over = false;
        rebuild();
        G.snd.wood();
        return;
      }
      if (over || a.n !== history.length) return; // stale or duplicate
      if (!legal(pos).some((m) => m[0] === a.m[0] && m[1] === a.m[1] && m[2] === a.m[2])) return;
      await doMove(a.m);
    },
  };
})();

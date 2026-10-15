/* UNO – round 3D table, avatars around it, fanned cards, flying card animations, UNO button. */
'use strict';
(function () {
  const COLORS = ['#e8323c', '#f7c21b', '#2fb14b', '#1f7fe0'];
  const CNAME = ['Red', 'Yellow', 'Green', 'Blue'];
  // card id → {c: colour 0-3 or 4 wild, v: 0-9, 10 skip, 11 reverse, 12 +2, 13 wild, 14 +4}
  const DECK = (() => {
    const d = [];
    for (let c = 0; c < 4; c++) {
      d.push({ c, v: 0 });
      for (let v = 1; v <= 12; v++) { d.push({ c, v }); d.push({ c, v }); }
    }
    for (let i = 0; i < 4; i++) { d.push({ c: 4, v: 13 }); d.push({ c: 4, v: 14 }); }
    return d;
  })();
  const label = (v) => (v <= 9 ? String(v) : { 10: '⊘', 11: '⇄', 12: '+2', 13: '★', 14: '+4' }[v]);

  let players = [], hands = [], deck = [], pile = [], turn = 0, dir = 1, color = 0, rng, step = 0, over = false;
  let drew = false, unoPressed = false, viewSeat = 0, busy = false, root, el = {};

  // ───────── styles + DOM ─────────
  const css = `
  #uno { position: fixed; inset: 0; z-index: 4; pointer-events: none; font-family: system-ui, Roboto, sans-serif; }
  #uno * { pointer-events: auto; }
  .ucard { position: absolute; width: 66px; height: 98px; border-radius: 11px; background: #fff; padding: 4px; box-shadow: 0 4px 10px rgba(0,0,0,.35), inset 0 0 0 1px rgba(0,0,0,.08);
    transition: transform .45s cubic-bezier(.2,.9,.3,1.1), left .45s cubic-bezier(.2,.9,.3,1.1), top .45s cubic-bezier(.2,.9,.3,1.1), opacity .3s; will-change: transform; }
  .ucard .in { width: 100%; height: 100%; border-radius: 8px; position: relative; overflow: hidden; }
  .ucard .ov { position: absolute; left: 50%; top: 50%; width: 82%; height: 62%; transform: translate(-50%,-50%) rotate(-28deg); border-radius: 50%; background: #fff; box-shadow: inset 0 -3px 0 rgba(0,0,0,.08); }
  .ucard .big { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-weight: 900; font-style: italic; font-size: 34px; text-shadow: 2px 2px 0 rgba(0,0,0,.25); -webkit-text-stroke: 1px rgba(0,0,0,.25); }
  .ucard .tl, .ucard .br { position: absolute; font-weight: 900; font-size: 13px; color: #fff; text-shadow: 1px 1px 0 rgba(0,0,0,.4); }
  .ucard .tl { left: 4px; top: 2px; } .ucard .br { right: 4px; bottom: 2px; transform: rotate(180deg); }
  .ucard.back .in { background: radial-gradient(circle at 50% 45%, #3a2a55, #160d24); }
  .ucard.back .ov { background: #e8323c; }
  .ucard.back .big { color: #ffd84a; font-size: 15px; -webkit-text-stroke: 0; transform: rotate(-28deg); letter-spacing: 1px; }
  .ucard.play { box-shadow: 0 0 0 3px #fff, 0 0 18px 4px rgba(255,236,120,.9), 0 6px 12px rgba(0,0,0,.4); }
  .ucard.dim { opacity: .82; } .ucard.dim .in { filter: brightness(.8) saturate(.8); }
  .ucard.small { width: 34px; height: 50px; padding: 2px; border-radius: 6px; }
  .ucard.small .big { font-size: 9px; }
  .uav { position: absolute; display: flex; flex-direction: column; align-items: center; gap: 2px; transform: translate(-50%,-50%); transition: all .3s; }
  .uav .face { width: 58px; height: 58px; border-radius: 18px; font-size: 36px; display: flex; align-items: center; justify-content: center; background: linear-gradient(#fff,#ffe3ee); box-shadow: 0 4px 0 rgba(0,0,0,.2), 0 0 0 3px #fff; }
  .uav.on .face { box-shadow: 0 0 0 4px #ffd84a, 0 0 22px 6px rgba(255,216,74,.8); animation: bob 1s infinite; }
  .uav .nm { color: #fff; font-weight: 900; font-size: 13px; text-shadow: 0 2px 4px rgba(0,0,0,.8); white-space: nowrap; }
  .uav .cnt { position: absolute; top: -6px; right: -10px; background: #e8323c; color: #fff; font-weight: 900; font-size: 13px; min-width: 24px; height: 24px; border-radius: 12px; display: flex; align-items: center; justify-content: center; border: 2px solid #fff; }
  .uav .unoTag { position: absolute; bottom: 18px; left: -26px; background: #ffd84a; color: #c2185b; font-weight: 900; font-size: 12px; padding: 2px 6px; border-radius: 8px; transform: rotate(-12deg); display: none; }
  .uav.uno .unoTag { display: block; animation: pop .4s; }
  #ucolor { position: absolute; left: 50%; top: 41%; transform: translate(-50%,-50%); width: 230px; height: 230px; border-radius: 50%; pointer-events: none;
    border: 10px solid; opacity: .85; box-shadow: 0 0 30px currentColor, inset 0 0 30px currentColor; transition: color .4s, border-color .4s; }
  #ucolorName { position: absolute; left: 50%; top: calc(41% + 112px); transform: translateX(-50%); font-size: 30px; font-weight: 900; font-style: italic; color: #fff; -webkit-text-stroke: 1.5px rgba(0,0,0,.4); text-shadow: 0 3px 0 rgba(0,0,0,.3); }
  #udir { position: absolute; left: 50%; top: 41%; width: 290px; height: 290px; transform: translate(-50%,-50%); pointer-events: none; opacity: .5; font-size: 34px; color: #fff; }
  #udir span { position: absolute; }
  #unoBtn { position: absolute; right: 14px; bottom: 150px; width: 82px; height: 82px; border-radius: 50%; border: none; color: #ffd84a; font-weight: 900; font-size: 22px; font-style: italic;
    background: radial-gradient(circle at 35% 30%, #ff6b6b, #c40e1e 70%); box-shadow: 0 6px 0 #7d0710, 0 10px 20px rgba(0,0,0,.45), inset 0 0 0 4px #ffd84a; -webkit-text-stroke: 1px #7d0710; }
  #unoBtn:active { transform: translateY(5px); box-shadow: 0 1px 0 #7d0710; }
  #unoBtn.ready { animation: pulse .7s infinite; }
  #unoBtn.on { filter: brightness(1.3); }
  #upass { position: absolute; left: 14px; bottom: 160px; display: none; }
  #upick { position: fixed; inset: 0; display: none; align-items: center; justify-content: center; background: rgba(0,0,0,.45); z-index: 9; }
  #upick.show { display: flex; }
  #upick .wheel { width: 240px; height: 240px; border-radius: 50%; position: relative; overflow: hidden; box-shadow: 0 0 0 8px #fff, 0 20px 40px rgba(0,0,0,.5); animation: pop .35s; }
  #upick .q { position: absolute; width: 50%; height: 50%; border: none; }
  #ucurtain { position: fixed; inset: 0; display: none; align-items: center; justify-content: center; z-index: 9; background: rgba(20,10,30,.92); color: #fff; text-align: center; font-weight: 900; font-size: 22px; flex-direction: column; gap: 16px; }
  #ucurtain.show { display: flex; }
  @keyframes bob { 50% { transform: translateY(-4px); } }
  @keyframes pulse { 50% { transform: scale(1.1); } }
  `;
  function buildDom() {
    if (el.root) el.root.remove();
    const st = document.createElement('style');
    st.textContent = css;
    document.head.appendChild(st);
    const r = document.createElement('div');
    r.id = 'uno';
    r.innerHTML = `<div id="udir"></div><div id="ucolor"></div><div id="ucolorName"></div>
      <button id="unoBtn">UNO!</button><button class="btn" id="upass">Pass ▶</button>`;
    document.body.appendChild(r);
    const pick = document.createElement('div');
    pick.id = 'upick';
    pick.innerHTML = '<div class="wheel">' + [0, 1, 3, 2].map((c, i) => `<button class="q" data-c="${c}" style="background:${COLORS[c]};left:${i % 2 ? 50 : 0}%;top:${i > 1 ? 50 : 0}%"></button>`).join('') + '</div>';
    document.body.appendChild(pick);
    const cur = document.createElement('div');
    cur.id = 'ucurtain';
    document.body.appendChild(cur);
    el = { root: r, pick, curtain: cur, color: r.querySelector('#ucolor'), cname: r.querySelector('#ucolorName'), dir: r.querySelector('#udir'), uno: r.querySelector('#unoBtn'), pass: r.querySelector('#upass'), cards: new Map(), avs: [] };
    el.uno.onclick = () => {
      unoPressed = true;
      el.uno.classList.add('on');
      G.snd.tone(988, 0.25, 'sine', 0.3);
      G.snd.tone(1319, 0.4, 'sine', 0.25, 0.1);
      G.toast('UNO! 🔔');
    };
    el.pass.onclick = () => { if (G.mine(players[turn]) && drew) G.act({ t: 'pass', n: step }); };
  }

  function cardEl(id) {
    let e = el.cards.get(id);
    if (e) return e;
    e = document.createElement('div');
    e.className = 'ucard back';
    e.innerHTML = '<div class="in"><div class="ov"></div><div class="big">LITTLE ONE</div><div class="tl"></div><div class="br"></div></div>';
    e.style.left = '50%';
    e.style.top = '40%';
    e.onclick = () => tapCard(id);
    el.root.appendChild(e);
    el.cards.set(id, e);
    return e;
  }
  function face(e, id, up) {
    if (!up) {
      if (!e.classList.contains('back')) { e.className = 'ucard back'; e.querySelector('.in').style.background = ''; e.querySelector('.big').textContent = 'LITTLE ONE'; e.querySelector('.big').style.color = ''; e.querySelector('.tl').textContent = ''; e.querySelector('.br').textContent = ''; }
      return;
    }
    const c = DECK[id];
    e.classList.remove('back');
    const inn = e.querySelector('.in');
    inn.style.background = c.c === 4 ? 'conic-gradient(#e8323c 0 25%, #1f7fe0 0 50%, #2fb14b 0 75%, #f7c21b 0)' : `linear-gradient(145deg, ${G.shade(COLORS[c.c], 0.1)}, ${COLORS[c.c]})`;
    const big = e.querySelector('.big');
    big.textContent = label(c.v);
    big.style.color = c.c === 4 ? '#222' : COLORS[c.c];
    big.style.transform = '';
    e.querySelector('.tl').textContent = label(c.v);
    e.querySelector('.br').textContent = label(c.v);
  }

  // ───────── table (3D) ─────────
  function buildTable() {
    if (root) G.scene.remove(root);
    root = new THREE.Group();
    G.scene.add(root);
    G.setBackground('#1d4f8f', '#0a1530');
    const felt = G.canvasTex(1024, 1024, (g, w) => {
      const gr = g.createRadialGradient(w / 2, w / 2, 40, w / 2, w / 2, w / 2);
      gr.addColorStop(0, '#53c26a');
      gr.addColorStop(0.7, '#2f9a4a');
      gr.addColorStop(1, '#1d6e33');
      g.fillStyle = gr;
      g.fillRect(0, 0, w, w);
      g.globalAlpha = 0.08;
      for (let i = 0; i < 6000; i++) { g.fillStyle = Math.random() > 0.5 ? '#fff' : '#000'; g.fillRect(Math.random() * w, Math.random() * w, 2, 2); }
      g.globalAlpha = 0.12;
      g.strokeStyle = '#fff';
      g.lineWidth = 14;
      g.beginPath();
      g.arc(w / 2, w / 2, w * 0.3, 0, Math.PI * 2);
      g.stroke();
      g.globalAlpha = 1;
    });
    const top = new THREE.Mesh(new THREE.CylinderGeometry(6.2, 6.2, 0.3, 80), [
      new THREE.MeshPhysicalMaterial({ map: G.woodTexture('#7a3f1d', 4), roughness: 0.35, clearcoat: 0.8 }),
      new THREE.MeshStandardMaterial({ map: felt, roughness: 0.95 }),
      new THREE.MeshStandardMaterial({ color: 0x3a1d0d }),
    ]);
    top.receiveShadow = true;
    root.add(top);
    const rim = new THREE.Mesh(new THREE.TorusGeometry(6.25, 0.32, 20, 90), new THREE.MeshPhysicalMaterial({ map: G.woodTexture('#8a4a22', 6), roughness: 0.3, clearcoat: 1 }));
    rim.rotation.x = Math.PI / 2;
    rim.position.y = 0.2;
    G.shadowed(rim);
    root.add(rim);
    const floor = G.addTable('#3b2a4a', 80);
    floor.position.y = -1.5;
    root.add(floor);
    G.setView(new THREE.Vector3(0, 0, 0.6), 0.5, 15, 0);
    G.orbit.minR = 10;
    G.orbit.maxR = 22;
  }

  // ───────── layout ─────────
  const W = () => window.innerWidth, H = () => window.innerHeight;
  function seatPos(rel, n) {
    const map = n === 2 ? ['b', 't'] : n === 3 ? ['b', 'l', 'r'] : ['b', 'l', 't', 'r'];
    return map[rel];
  }
  const AV = { b: () => [W() * 0.13, H() - 190], l: () => [40, H() * 0.3], t: () => [W() / 2, 128], r: () => [W() - 40, H() * 0.3] };
  const avatarFor = (p) => (p.bot ? '🤖' : ({ nanna: '👨', amma: '👩', ammamma: '👵', tatayya: '👴' }[(p.name || '').toLowerCase()] || ['🧑', '👧', '🧔', '👱‍♀️'][players.indexOf(p) % 4]));

  function buildAvatars() {
    for (const a of el.avs) a.remove();
    el.avs = players.map((p, i) => {
      const d = document.createElement('div');
      d.className = 'uav';
      d.innerHTML = `<div class="face">${avatarFor(p)}<div class="cnt">7</div></div><div class="nm">${p.name}</div><div class="unoTag">UNO!</div>`;
      el.root.appendChild(d);
      return d;
    });
  }

  function render() {
    const n = players.length;
    const pileX = W() / 2, pileY = H() * 0.41;
    // pile
    pile.forEach((id, k) => {
      const e = cardEl(id);
      face(e, id, true);
      e.classList.remove('play', 'dim', 'small');
      const depth = pile.length - 1 - k;
      e.style.display = depth > 4 ? 'none' : '';
      const rot = ((id * 37) % 40) - 20;
      e.style.left = pileX - 33 + 'px';
      e.style.top = pileY - 49 + 'px';
      e.style.transform = `rotate(${rot}deg) scale(1.15)`;
      e.style.zIndex = 10 + k;
    });
    // draw stack
    deck.forEach((id, k) => {
      const e = cardEl(id);
      face(e, id, false);
      e.classList.remove('play', 'dim', 'small');
      e.style.display = k < deck.length - 4 ? 'none' : '';
      e.style.left = pileX - 118 + (deck.length - k) * 0.7 + 'px';
      e.style.top = pileY - 52 - (deck.length - k) * 0.7 + 'px';
      e.style.transform = 'rotate(-8deg)';
      e.style.zIndex = 5 + (k - deck.length + 5);
    });
    // hands
    const showHand = viewSeat >= 0 && G.mine(players[viewSeat]) && !el.curtain.classList.contains('show');
    players.forEach((p, i) => {
      const rel = (i - viewSeat + n) % n;
      const pos = seatPos(rel, n);
      const hand = hands[i];
      const av = el.avs[i];
      const [ax, ay] = AV[pos]();
      av.style.left = ax + 'px';
      av.style.top = ay + 'px';
      av.classList.toggle('on', i === turn && !over);
      av.classList.toggle('uno', hand.length === 1);
      av.querySelector('.cnt').textContent = hand.length;
      if (pos === 'b') {
        const playable = i === turn && showHand && !busy && !over;
        const cw = Math.min(62, (W() - 90) / Math.max(1, hand.length));
        const total = cw * (hand.length - 1);
        hand.forEach((id, k) => {
          const e = cardEl(id);
          face(e, id, showHand);
          e.classList.remove('small');
          const t = hand.length > 1 ? k / (hand.length - 1) - 0.5 : 0;
          const can = playable && canPlay(id);
          e.classList.toggle('play', can);
          e.classList.toggle('dim', playable && !can);
          e.style.display = '';
          e.style.left = W() / 2 + 20 - total / 2 + k * cw - 33 + 'px';
          e.style.top = H() - 128 + Math.abs(t) * 26 - (can ? 18 : 0) + 'px';
          e.style.transform = `rotate(${t * 26}deg) scale(1.08)`;
          e.style.zIndex = 40 + k;
        });
      } else {
        hand.forEach((id, k) => {
          const e = cardEl(id);
          face(e, id, false);
          e.classList.add('small');
          e.classList.remove('play', 'dim');
          e.style.display = k > 11 ? 'none' : '';
          const spread = Math.min(16, 160 / Math.max(1, hand.length));
          const off = (k - (Math.min(hand.length, 12) - 1) / 2) * spread;
          let x = ax, y = ay, rot = 0;
          if (pos === 't') { x = ax + off - 17; y = ay + 48; rot = 180 + off * 0.4; }
          if (pos === 'l') { x = ax - 17; y = ay + 95 + off * 0.7; rot = 90 + off * 0.4; }
          if (pos === 'r') { x = ax - 17; y = ay + 95 + off * 0.7; rot = -90 + off * 0.4; }
          e.style.left = x + 'px';
          e.style.top = y + 'px';
          e.style.transform = `rotate(${rot}deg)`;
          e.style.zIndex = 20 + k;
        });
      }
    });
    el.color.style.color = COLORS[color];
    el.color.style.borderColor = COLORS[color];
    el.cname.textContent = CNAME[color];
    el.cname.style.color = COLORS[color];
    el.dir.innerHTML = dir === 1 ? '<span style="left:8px;top:40%">⤸</span><span style="right:8px;top:40%">⤹</span>' : '<span style="left:8px;top:40%">⤹</span><span style="right:8px;top:40%">⤸</span>';
    const me = turn === viewSeat && G.mine(players[turn]) && !over;
    el.pass.style.display = me && drew && !busy ? 'block' : 'none';
    el.uno.style.display = showHand ? 'block' : 'none';
    el.uno.classList.toggle('ready', showHand && hands[viewSeat].length === 2 && turn === viewSeat && !unoPressed);
    G.players(players.map((p, i) => ({ name: p.name, color: G.seatColor(i), bot: p.bot, extra: hands[i].length + '🂠' })), turn);
  }
  window.addEventListener('resize', () => { if (players.length && el.root) render(); });

  // ───────── rules ─────────
  const top = () => DECK[pile[pile.length - 1]];
  const canPlay = (id) => { const c = DECK[id], t = top(); return c.c === 4 || c.c === color || c.v === t.v; };
  function draw1() {
    if (!deck.length) {
      const keep = pile.pop();
      deck = pile;
      for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }
      pile = [keep];
    }
    return deck.pop();
  }

  async function deal(setup) {
    rng = G.rng(setup.seed);
    deck = DECK.map((_, i) => i);
    for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }
    for (const e of el.cards.values()) e.remove();
    el.cards = new Map();
    hands = players.map(() => []);
    pile = [];
    let first = deck.pop();
    while (DECK[first].v > 9) { deck.unshift(first); first = deck.pop(); }
    pile.push(first);
    color = DECK[first].c;
    turn = 0;
    dir = 1;
    step = 0;
    over = false;
    drew = false;
    render();
    for (let r = 0; r < 7; r++) {
      for (let i = 0; i < players.length; i++) {
        hands[i].push(deck.pop());
        render();
        G.snd.hit(3000, 0.04, 0.25);
        await G.wait(45);
      }
    }
    await G.wait(300);
    startTurn();
  }

  function pickView() {
    if (G.mine(players[turn])) {
      if (viewSeat !== turn && G.localHumans(players) > 1 && !G.fast) {
        viewSeat = turn;
        el.curtain.innerHTML = `<div style="font-size:60px">📱</div><div>Pass the phone to<br>${players[turn].name}</div><button class="btn" id="ucur">I'm ${players[turn].name} – show my cards</button>`;
        el.curtain.classList.add('show');
        el.curtain.querySelector('#ucur').onclick = () => { el.curtain.classList.remove('show'); render(); };
      }
      viewSeat = turn;
    } else if (!G.mine(players[viewSeat])) {
      const m = players.findIndex((p) => G.mine(p));
      viewSeat = m >= 0 ? m : 0;
    }
  }

  function startTurn() {
    if (over) return;
    drew = false;
    unoPressed = false;
    el.uno.classList.remove('on');
    pickView();
    busy = false;
    render();
    const p = players[turn];
    G.status(G.mine(p) ? `${p.name}, your turn – match ${CNAME[color]} or ${label(top().v)}` : `${p.name}'s turn…`);
    if (G.mine(p) && !G.fast) G.snd.tone(880, 0.1, 'sine', 0.15);
    if (G.botTurn(p)) setTimeout(botMove, G.fast ? 0 : 900 + Math.random() * 600);
  }

  function botMove() {
    if (over || !G.botTurn(players[turn])) return;
    const h = hands[turn];
    const opts = h.filter(canPlay);
    const best = (list) => {
      const cnt = [0, 0, 0, 0];
      for (const id of h) if (DECK[id].c < 4) cnt[DECK[id].c]++;
      const bc = cnt.indexOf(Math.max(...cnt));
      list.sort((a, b) => sc(DECK[b]) - sc(DECK[a]));
      function sc(c) { return c.c === 4 ? 0 : (c.v >= 10 ? 3 : 2) + (c.c === color ? 1 : 0); }
      return { id: list[0], c: bc };
    };
    if (opts.length) {
      const b = best(opts);
      G.act({ t: 'play', id: b.id, c: b.c, uno: h.length === 2 && Math.random() > 0.15, n: step });
    } else if (!drew) {
      G.act({ t: 'draw', n: step });
    } else {
      G.act({ t: 'pass', n: step });
    }
  }

  function tapCard(id) {
    if (over || busy || !G.mine(players[turn]) || viewSeat !== turn) return;
    if (!hands[turn].includes(id)) {
      if (deck.includes(id) && !drew) G.act({ t: 'draw', n: step });
      return;
    }
    if (!canPlay(id)) { G.snd.tone(200, 0.12, 'square', 0.1); G.toast('Match ' + CNAME[color] + ' or ' + label(top().v)); return; }
    const c = DECK[id];
    if (c.c === 4) {
      el.pick.classList.add('show');
      el.pick.querySelectorAll('.q').forEach((b) => (b.onclick = () => {
        el.pick.classList.remove('show');
        G.act({ t: 'play', id, c: +b.dataset.c, uno: unoPressed, n: step });
      }));
      return;
    }
    busy = true;
    G.act({ t: 'play', id, c: c.c, uno: unoPressed, n: step });
  }

  async function doPlay(a) {
    busy = true;
    const h = hands[turn];
    h.splice(h.indexOf(a.id), 1);
    pile.push(a.id);
    const c = DECK[a.id];
    color = c.c === 4 ? a.c : c.c;
    G.snd.hit(2400, 0.08, 0.6, 0, 1.2);
    G.snd.tone(520, 0.1, 'triangle', 0.2, 0, 300);
    G.haptic('light');
    render();
    await G.wait(450);
    const who = players[turn];
    if (!h.length) {
      over = true;
      render();
      G.status(who.name + ' wins! 🎉');
      G.confetti(new THREE.Vector3(0, 0, 0), 10);
      G.winScreen(who.name + ' wins UNO! 🎉', 'All cards played', () => G.act({ t: 'new', seed: Math.floor(Math.random() * 1e9) }));
      return;
    }
    if (h.length === 1) {
      if (a.uno) { G.toast('🔔 ' + who.name + ': UNO!'); G.snd.tone(988, 0.25, 'sine', 0.3); G.snd.tone(1319, 0.45, 'sine', 0.25, 0.12); }
      else {
        G.toast('😅 ' + who.name + ' forgot UNO! +2');
        G.snd.tone(300, 0.3, 'sawtooth', 0.15, 0, 150);
        await G.wait(500);
        h.push(draw1(), draw1());
        render();
        await G.wait(400);
      }
    }
    let skip = false;
    if (c.v === 10) { skip = true; G.toast('⊘ Skip!'); G.snd.tone(700, 0.25, 'triangle', 0.25, 0, 250); }
    else if (c.v === 11) {
      if (players.length === 2) skip = true;
      else dir = -dir;
      G.toast('⇄ Reverse!');
      G.snd.tone(400, 0.2, 'triangle', 0.2, 0, 800);
    } else if (c.v === 12 || c.v === 14) {
      const victim = (turn + dir + players.length) % players.length;
      const k = c.v === 12 ? 2 : 4;
      G.toast(`${players[victim].name} draws ${k}! 😈`);
      [392, 523, 659, 784].slice(0, k).forEach((f, i) => G.snd.tone(f, 0.15, 'triangle', 0.2, i * 0.07));
      for (let j = 0; j < k; j++) { hands[victim].push(draw1()); render(); await G.wait(140); }
      skip = true;
    }
    if (c.c === 4) G.toast('🎨 ' + CNAME[color] + '!');
    await G.wait(250);
    nextTurn(skip);
  }

  function nextTurn(skip) {
    const n = players.length;
    turn = (turn + dir * (skip ? 2 : 1)) % n;
    if (turn < 0) turn += n;
    step++;
    startTurn();
  }

  async function doDraw() {
    busy = true;
    const id = draw1();
    hands[turn].push(id);
    drew = true;
    G.snd.hit(1800, 0.12, 0.4, 0, 1);
    render();
    await G.wait(450);
    busy = false;
    step++;
    const p = players[turn];
    if (G.mine(p)) G.status(canPlay(id) ? 'You can play the card you drew – or tap Pass' : 'No luck – tap Pass');
    render();
    if (G.botTurn(p)) setTimeout(botMove, G.fast ? 0 : 700);
  }

  window.Uno3D = {
    title: 'UNO', minPlayers: 2, maxPlayers: 4, colors: ['#e8323c', '#2fb14b', '#f7c21b', '#1f7fe0'],
    init() {
      G.$('title').textContent = '🃏 UNO';
      G.$('actions').innerHTML = '';
      G.$('roll').style.display = 'none';
      G.onTap = null;
      G.$('players').style.display = 'none';
      const b = G.$('bottom');
      b.style.bottom = 'auto';
      b.style.top = 'calc(41% + 158px)';
      buildTable();
      buildDom();
    },
    makeSetup(list) { return { players: list.slice(0, 4), seed: Math.floor(Math.random() * 1e9) }; },
    begin(s) {
      players = s.players;
      viewSeat = Math.max(0, players.findIndex((p) => G.mine(p)));
      buildAvatars();
      deal(s);
    },
    allowed(a, from) {
      if (a.t === 'new') return over || from === G.net.myId;
      const p = players[turn];
      return p.id === from || (p.bot && from === G.net.myId);
    },
    async apply(a) {
      if (a.t === 'new') { await deal({ seed: a.seed }); return; }
      if (over || a.n !== step) return;
      const h = hands[turn];
      if (a.t === 'play' && h.includes(a.id) && canPlay(a.id)) await doPlay(a);
      else if (a.t === 'draw' && !drew) await doDraw();
      else if (a.t === 'pass' && drew) nextTurn(false);
      else { busy = false; render(); }
    },
  };
})();

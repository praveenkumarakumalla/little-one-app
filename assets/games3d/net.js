/* Playing together on several phones: room codes, lobby, and an ordered stream of moves.
 *
 * One phone creates a room (the host). Others join with the room code. Phones connect
 * directly (WebRTC via PeerJS – works on the same Wi-Fi or over the internet). Every move
 * goes to the host, which numbers it and sends it to everyone, so all phones apply the same
 * moves in the same order. Room codes are only for games – they never open the family chat
 * or memories.
 */
'use strict';
(function () {
  const PREFIX = 'littleone-game-';
  const net = (G.net = {
    online: false, role: 'local', code: '', myId: 'me', name: 'Me',
    peer: null, conns: new Map(), hostConn: null, lobby: [], log: [], seq: 0, setup: null, started: false,
  });

  // ───────── seeded random (same cards / dice for everybody when needed) ─────────
  G.rng = function (seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };

  // ───────── who controls which seat ─────────
  G.mine = (p) => !!p && !p.bot && (!net.online || p.id === net.myId);
  G.runsBots = () => !net.online || net.role === 'host';
  G.botTurn = (p) => !!p && p.bot && G.runsBots();
  G.localHumans = (players) => players.filter((p) => G.mine(p)).length;

  // ───────── ordered actions ─────────
  let queue = Promise.resolve();
  let game = null;
  function applyOrdered(a) {
    queue = queue.then(() => game && game.apply(a)).catch((e) => console.error(e));
    return queue;
  }
  /** Ask for a move. Offline it happens straight away; online it goes through the host. */
  G.act = function (a) {
    if (!net.online) return applyOrdered(a);
    if (net.role === 'host') return hostAccept(a, net.myId);
    if (net.hostConn && net.hostConn.open) net.hostConn.send({ t: 'act', a });
    else G.toast('Reconnecting… 📶');
  };
  /** Live state from the host (real-time games such as Sheep Fight). */
  G.sendState = function (s) {
    if (net.online && net.role === 'host') for (const c of net.conns.values()) if (c.open) c.send({ t: 'state', s });
  };
  G.sendInput = function (a) {
    if (!net.online) return game && game.input && game.input(a, net.myId);
    if (net.role === 'host') return game && game.input && game.input(a, net.myId);
    if (net.hostConn && net.hostConn.open) net.hostConn.send({ t: 'input', a });
  };

  function hostAccept(a, fromId) {
    if (game && game.allowed && !game.allowed(a, fromId)) return;
    const msg = { t: 'act', seq: ++net.seq, a };
    net.log.push(msg);
    for (const c of net.conns.values()) if (c.open) c.send(msg);
    return applyOrdered(a);
  }

  // ───────── connection ─────────
  function peerOpts() {
    const srv = (G.cfg.net && G.cfg.net.server) || {}; // only used for testing with a private server
    return { debug: 0, ...srv, config: { iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: ['turn:eu-0.turn.peerjs.com:3478', 'turn:us-0.turn.peerjs.com:3478'], username: 'peerjs', credential: 'peerjsp' },
    ] } };
  }

  function lobbyUI() {
    const L = G.$('lobby');
    L.classList.add('show');
    G.$('lobbyCode').textContent = net.code;
    const list = G.$('lobbyList');
    list.innerHTML = '';
    net.lobby.forEach((p, i) => {
      const d = document.createElement('div');
      d.className = 'lp';
      d.innerHTML = `<span class="seat" style="background:${G.seatColor(i)}"></span>${p.bot ? '🤖 ' : '📱 '}${p.name}${p.id === net.myId ? ' <i>(you)</i>' : ''}${i === 0 && !p.bot ? ' 👑' : ''}`;
      if (net.role === 'host' && p.bot) {
        const x = document.createElement('button');
        x.className = 'x';
        x.textContent = '✕';
        x.onclick = () => { net.lobby.splice(i, 1); pushLobby(); };
        d.appendChild(x);
      }
      list.appendChild(d);
    });
    const max = game.maxPlayers || 4, min = game.minPlayers || 2;
    G.$('lobbyAddBot').style.display = net.role === 'host' && net.lobby.length < max ? '' : 'none';
    G.$('lobbyStart').style.display = net.role === 'host' ? '' : 'none';
    G.$('lobbyStart').disabled = net.lobby.length < min;
    G.$('lobbyWait').style.display = net.role === 'host' ? 'none' : '';
    G.$('lobbyHint').textContent = net.role === 'host'
      ? `Share the code. Others open Little One → Games → ${game.title} → Join room. (${min}–${max} players)`
      : 'Connected! Waiting for the host to start…';
  }
  function pushLobby() {
    const msg = { t: 'lobby', players: net.lobby };
    for (const c of net.conns.values()) if (c.open) c.send(msg);
    lobbyUI();
  }
  G.seatColor = (i) => (game && game.colors ? game.colors[i % game.colors.length] : ['#e53950', '#2eae5a', '#f2b705', '#2f7de1'][i % 4]);

  function startNow(setup) {
    net.setup = setup;
    net.started = true;
    G.$('lobby').classList.remove('show');
    game.begin(setup);
  }

  function hostData(conn, d) {
    if (!d || typeof d !== 'object') return;
    if (d.t === 'hello') {
      conn.label = d.name;
      if (net.started) {
        // re-joining or late: catch up
        conn.send({ t: 'sync', setup: net.setup, log: net.log });
        G.toast('📱 ' + d.name + ' joined');
        return;
      }
      if (!net.lobby.find((p) => p.id === conn.peer)) {
        if (net.lobby.length >= (game.maxPlayers || 4)) {
          const bi = net.lobby.findIndex((p) => p.bot);
          if (bi >= 0) net.lobby.splice(bi, 1);
          else { conn.send({ t: 'full' }); return; }
        }
        net.lobby.push({ id: conn.peer, name: String(d.name || 'Guest').slice(0, 16), bot: false });
      }
      G.snd.select();
      pushLobby();
    } else if (d.t === 'act') {
      hostAccept(d.a, conn.peer);
    } else if (d.t === 'input') {
      if (game && game.input) game.input(d.a, conn.peer);
    }
  }

  function guestData(d) {
    if (!d || typeof d !== 'object') return;
    if (d.t === 'lobby') { net.lobby = d.players; lobbyUI(); }
    else if (d.t === 'full') { G.status('That room is full 😕'); G.toast('Room is full'); }
    else if (d.t === 'start') { startNow(d.setup); }
    else if (d.t === 'sync') {
      if (!net.started) startNow(d.setup);
      const todo = d.log.filter((m) => m.seq > net.seq);
      if (todo.length) {
        G.fast = true;
        for (const m of todo) { net.seq = m.seq; applyOrdered(m.a); }
        queue = queue.then(() => { G.fast = false; });
      }
    } else if (d.t === 'act') {
      if (d.seq <= net.seq) return;
      net.seq = d.seq;
      applyOrdered(d.a);
    } else if (d.t === 'state') {
      if (game && game.state) game.state(d.s);
    }
  }

  function netStatus(text, ok) {
    const el = G.$('netBadge');
    el.style.display = 'block';
    el.textContent = text;
    el.classList.toggle('bad', !ok);
  }

  function openHost() {
    net.peer = new Peer(PREFIX + net.code.toLowerCase(), peerOpts());
    net.peer.on('open', (id) => {
      net.myId = id;
      net.lobby = [{ id, name: net.name, bot: false }];
      netStatus('🌐 Room ' + net.code, true);
      lobbyUI();
    });
    net.peer.on('connection', (conn) => {
      conn.on('open', () => net.conns.set(conn.peer, conn));
      conn.on('data', (d) => hostData(conn, d));
      conn.on('close', () => {
        net.conns.delete(conn.peer);
        if (!net.started) { net.lobby = net.lobby.filter((p) => p.id !== conn.peer); pushLobby(); }
        else G.toast('📴 ' + (conn.label || 'A player') + ' disconnected');
      });
    });
    net.peer.on('disconnected', () => { netStatus('📶 Reconnecting…', false); try { net.peer.reconnect(); } catch (e) {} });
    net.peer.on('error', (e) => {
      if (e.type === 'unavailable-id') {
        G.$('lobbyHint').textContent = 'That room code is already in use – go back and create a new room.';
      } else if (e.type === 'network' || e.type === 'server-error' || e.type === 'socket-error') {
        netStatus('📶 No internet – check Wi-Fi/data', false);
      }
    });
  }

  function openGuest() {
    net.peer = new Peer(undefined, peerOpts());
    let tries = 0;
    const connect = () => {
      const c = net.peer.connect(PREFIX + net.code.toLowerCase(), { reliable: true, serialization: 'json' });
      net.hostConn = c;
      c.on('open', () => {
        tries = 0;
        netStatus('🌐 Room ' + net.code, true);
        c.send({ t: 'hello', name: net.name });
      });
      c.on('data', guestData);
      c.on('close', () => {
        netStatus('📶 Lost the host – retrying…', false);
        if (tries++ < 20) setTimeout(connect, 2500);
      });
    };
    net.peer.on('open', (id) => { net.myId = id; connect(); });
    net.peer.on('error', (e) => {
      if (e.type === 'peer-unavailable') {
        G.$('lobbyHint').textContent = 'Room ' + net.code + ' not found yet. Check the code – retrying…';
        if (tries++ < 20) setTimeout(connect, 3000);
      } else if (e.type === 'network' || e.type === 'server-error' || e.type === 'socket-error') {
        netStatus('📶 No internet – check Wi-Fi/data', false);
      }
    });
    net.peer.on('disconnected', () => { try { net.peer.reconnect(); } catch (e) {} });
    lobbyUI();
  }

  G.$('lobbyAddBot').onclick = () => {
    const n = net.lobby.filter((p) => p.bot).length;
    net.lobby.push({ id: 'bot' + Date.now(), name: ['Robo Raju', 'Chitti', 'Bujji Bot', 'Tinku'][n % 4], bot: true });
    pushLobby();
  };
  G.$('lobbyStart').onclick = () => {
    const setup = game.makeSetup(net.lobby.map((p) => ({ name: p.name, id: p.id, bot: p.bot })));
    const msg = { t: 'start', setup };
    for (const c of net.conns.values()) if (c.open) c.send(msg);
    startNow(setup);
  };
  G.$('lobbyShare').onclick = () => G.post('share:' + `Come play ${game.title} with me on Little One! 🎮 Open Games → ${game.title} → Join room and enter code: ${net.code}`);

  // ───────── entry point from the app ─────────
  window.startGame = function (cfg) {
    if (typeof cfg === 'string') cfg = JSON.parse(cfg);
    G.cfg = cfg;
    game = { chess: window.Chess3D, ludo: window.Ludo3D, snakes: window.Snakes3D, uno: window.Uno3D, sheep: window.Sheep3D }[cfg.game];
    G.game = game;
    G.$('loading').style.display = 'none';
    if (!game) return;
    game.init(cfg);
    if (cfg.net) {
      net.online = true;
      net.role = cfg.net.role;
      net.code = String(cfg.net.code || '').toUpperCase();
      net.name = cfg.net.name || 'Player';
      if (typeof Peer === 'undefined') { G.status('Online play is not available'); return; }
      net.role === 'host' ? openHost() : openGuest();
    } else {
      startNow(game.makeSetup(cfg.players || []));
    }
  };
})();

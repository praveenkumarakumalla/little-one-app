/* Little One – shared 3D engine for the family games (three.js r149). */
'use strict';
const G = (window.G = {});
if (THREE.ColorManagement) THREE.ColorManagement.legacyMode = false; // treat colours as sRGB (rich, not washed out)

// ───────────── messages to the app ─────────────
G.post = (m) => {
  try { if (window.Flutter) window.Flutter.postMessage(m); } catch (e) {}
};
G.haptic = (k) => G.post('haptic:' + (k || 'light'));

// ───────────── sound: real recordings (sfx.js) with synthesised fall-backs ─────────────
const Snd = (G.snd = {
  ctx: null,
  on: true,
  buf: {},
  _loops: {},
  unlock() {
    if (!this.ctx) {
      try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
      const comp = this.ctx.createDynamicsCompressor();
      comp.threshold.value = -14;
      comp.knee.value = 10;
      comp.ratio.value = 4;
      comp.connect(this.ctx.destination);
      this.master = this.ctx.createGain();
      this.master.gain.value = 1.0;
      this.master.connect(comp);
      this._decodeAll();
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
  },
  _decodeAll() {
    const data = window.SFX_DATA || {};
    for (const name of Object.keys(data)) {
      this.buf[name] = [];
      data[name].forEach((url, i) => {
        try {
          const b64 = url.slice(url.indexOf(',') + 1), bin = atob(b64), u = new Uint8Array(bin.length);
          for (let k = 0; k < bin.length; k++) u[k] = bin.charCodeAt(k);
          const done = (ab) => { this.buf[name][i] = ab; if (this._pendingLoop && this._pendingLoop[name]) this.loop(name, this._pendingLoop[name]); };
          const pr = this.ctx.decodeAudioData(u.buffer, done, () => {});
          if (pr && pr.catch) pr.catch(() => {});
        } catch (e) {}
      });
    }
  },
  has(name) { const l = this.buf[name]; return !!(l && l.some(Boolean)); },
  /** Play a recorded sound. Returns false when it isn't available (then the caller synthesises one). */
  play(name, o) {
    if (!this.ok()) return true; // muted / fast-forward: pretend it played
    const l = (this.buf[name] || []).filter(Boolean);
    if (!l.length) return false;
    o = o || {};
    const c = this.ctx, t = c.currentTime + (o.when || 0);
    const src = c.createBufferSource();
    src.buffer = l[Math.floor(Math.random() * l.length)];
    const vary = o.vary == null ? 0.06 : o.vary;
    src.playbackRate.value = (o.rate || 1) * (1 + (Math.random() * 2 - 1) * vary);
    const g = c.createGain();
    g.gain.value = (o.vol == null ? 0.8 : o.vol) * (1 + (Math.random() - 0.5) * 0.15);
    let node = g;
    if (o.pan && c.createStereoPanner) { const p = c.createStereoPanner(); p.pan.value = o.pan; g.connect(p); node = p; }
    src.connect(g);
    node.connect(this.master);
    src.start(t);
    return true;
  },
  /** Gentle background ambience (looped). */
  loop(name, vol) {
    if (!this.ctx || !this.on) { (this._pendingLoop = this._pendingLoop || {})[name] = vol; return; }
    if (this._loops[name]) return;
    const l = (this.buf[name] || []).filter(Boolean);
    if (!l.length) { (this._pendingLoop = this._pendingLoop || {})[name] = vol; return; }
    if (this._pendingLoop) delete this._pendingLoop[name];
    const src = this.ctx.createBufferSource(), g = this.ctx.createGain();
    src.buffer = l[0];
    src.loop = true;
    g.gain.setValueAtTime(0.0001, this.ctx.currentTime);
    g.gain.linearRampToValueAtTime(vol || 0.25, this.ctx.currentTime + 2);
    src.connect(g);
    g.connect(this.master);
    src.start();
    this._loops[name] = { src, g };
  },
  stopLoops() {
    for (const k of Object.keys(this._loops)) { try { this._loops[k].src.stop(); } catch (e) {} delete this._loops[k]; }
  },
  setOn(v) {
    this.on = v;
    if (this.master) this.master.gain.value = v ? 1 : 0;
  },
  _noise(dur) {
    const c = this.ctx, n = Math.floor(c.sampleRate * dur), b = c.createBuffer(1, n, c.sampleRate), d = b.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    const s = c.createBufferSource();
    s.buffer = b;
    return s;
  },
  _env(node, t, a, peak, dec) {
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + dec);
    node.connect(g);
    g.connect(this.master);
    return g;
  },
  tone(freq, dur, type, vol, when, slideTo) {
    if (!this.ok()) return;
    const c = this.ctx, t = c.currentTime + (when || 0);
    const o = c.createOscillator();
    o.type = type || 'sine';
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    this._env(o, t, 0.005, vol || 0.3, dur);
    o.start(t);
    o.stop(t + dur + 0.05);
  },
  hit(freq, dur, vol, when, q) {
    if (!this.ok()) return;
    const c = this.ctx, t = c.currentTime + (when || 0);
    const s = this._noise(dur + 0.05);
    const f = c.createBiquadFilter();
    f.type = 'bandpass';
    f.frequency.value = freq;
    f.Q.value = q || 4;
    s.connect(f);
    this._env(f, t, 0.002, vol || 0.5, dur);
    s.start(t);
    s.stop(t + dur + 0.05);
  },
  /** a soft bell note with overtones – for chimes when no recording */
  bellTone(freq, when, vol) {
    [1, 2.01, 3.02, 4.1].forEach((m, i) => this.tone(freq * m, 1.1 / (i + 1), 'sine', (vol || 0.2) / (i + 1.3), when));
  },
  ok() { return !G.fast && this.on && this.ctx && this.ctx.state !== 'closed'; },
  /** voice shout ("UNO!", "Check!") */
  say(key, vol) { return this.play(key, { vol: vol == null ? 0.95 : vol, vary: 0 }); },

  // ───── board pieces ─────
  wood() { this.play('chess_move', { vol: 0.7 }) || (this.hit(1800, 0.06, 0.7), this.tone(420, 0.09, 'triangle', 0.35, 0, 240)); },
  place() { this.play('chess_move', { vol: 0.95 }) || (this.hit(1300, 0.08, 0.9), this.tone(300, 0.12, 'triangle', 0.4, 0, 160)); },
  lift() { this.play('click', { vol: 0.35, rate: 1.2 }) || this.tone(1320, 0.05, 'sine', 0.1); },
  take() {
    if (!this.play('chess_take', { vol: 0.95 })) this.capture();
    this.play('whoosh', { vol: 0.3, when: 0.05, rate: 1.2 });
  },
  select() { this.play('click', { vol: 0.5 }) || (this.tone(880, 0.07, 'sine', 0.18), this.tone(1320, 0.06, 'sine', 0.12, 0.04)); },
  hop(i) {
    if (!this.play('piece_tap', { vol: 0.75, rate: 1 + (i || 0) * 0.03 })) { this.tone(520, 0.08, 'sine', 0.22, 0, 760); this.hit(2500, 0.03, 0.25); }
  },
  dice() {
    if (this.has('dice')) {
      this.play('dice_shake', { vol: 0.6 });
      this.play('dice', { vol: 0.95, when: this.has('dice_shake') ? 0.25 : 0 });
      return;
    }
    for (let i = 0; i < 9; i++) {
      const w = i * 0.055 + Math.random() * 0.03;
      this.hit(2200 + Math.random() * 2500, 0.03, 0.5 - i * 0.04, w, 6);
      this.hit(900 + Math.random() * 400, 0.04, 0.35 - i * 0.03, w, 3);
    }
  },
  capture() {
    if (this.has('pop')) {
      this.play('whoosh', { vol: 0.6 });
      this.play('pop', { vol: 0.9, when: 0.08 });
      this.play('hop', { vol: 0.5, when: 0.2, rate: 0.8 });
      this.say('v_capture', 0.8);
      return;
    }
    if (!this.ok()) return;
    const c = this.ctx, t = c.currentTime;
    const s = this._noise(0.45), f = c.createBiquadFilter();
    f.type = 'bandpass';
    f.Q.value = 1.5;
    f.frequency.setValueAtTime(400, t);
    f.frequency.exponentialRampToValueAtTime(4000, t + 0.35);
    s.connect(f);
    this._env(f, t, 0.02, 0.5, 0.4);
    s.start(t);
    this.tone(160, 0.25, 'sine', 0.6, 0.05, 60);
  },
  ladder() {
    if (!this.play('zip_up', { vol: 0.75, vary: 0 })) [523, 659, 784, 1047, 1319].forEach((n, i) => this.tone(n, 0.16, 'triangle', 0.25, i * 0.08));
    this.play('chime', { vol: 0.5, when: 0.5 });
    this.say('v_ladder');
  },
  snake() {
    if (this.play('hiss', { vol: 0.85 })) {
      this.play('zip_down', { vol: 0.6, when: 0.35, vary: 0 });
      this.say('v_snake');
      return;
    }
    this.tone(700, 0.7, 'sawtooth', 0.12, 0, 120);
    if (!this.ok()) return;
    const c = this.ctx, t = c.currentTime, s = this._noise(0.6), f = c.createBiquadFilter();
    f.type = 'highpass';
    f.frequency.value = 5000;
    s.connect(f);
    this._env(f, t, 0.05, 0.25, 0.55);
    s.start(t);
  },
  six() {
    if (!this.play('chime', { vol: 0.55 })) [1047, 1319, 1568, 2093].forEach((n, i) => this.tone(n, 0.12, 'sine', 0.18, i * 0.05));
    this.say('v_six', 0.85);
  },
  check() {
    if (!this.play('bell', { vol: 0.6, vary: 0 })) { this.bellTone(880, 0, 0.25); this.bellTone(880, 0.18, 0.2); }
    this.say('v_check');
  },
  checkmate() {
    this.play('bell', { vol: 0.7, vary: 0 }) || this.bellTone(660, 0, 0.3);
    this.say('v_checkmate');
  },
  home() {
    if (!this.play('chime', { vol: 0.65 })) [784, 988, 1175, 1568].forEach((n, i) => this.tone(n, 0.2, 'triangle', 0.25, i * 0.09));
    this.say('v_home', 0.8);
  },
  win() {
    const rec = this.play('fanfare', { vol: 0.75, vary: 0 });
    this.play('cheer', { vol: 0.6, when: 0.3, vary: 0 }) || this.play('applause', { vol: 0.6, when: 0.3, vary: 0 });
    this.say('v_win');
    if (rec) return;
    const seq = [[523, 0], [659, 0.12], [784, 0.24], [1047, 0.36], [784, 0.52], [1047, 0.64]];
    seq.forEach(([n, w]) => { this.tone(n, 0.28, 'triangle', 0.3, w); this.tone(n / 2, 0.28, 'sine', 0.2, w); });
    [523, 659, 784].forEach((n) => this.tone(n * 2, 0.9, 'sine', 0.15, 0.8));
  },
  lose() { this.play('fail', { vol: 0.6, vary: 0 }) || [392, 370, 349, 330].forEach((n, i) => this.tone(n, 0.3, 'triangle', 0.2, i * 0.25)); },
  turn() { this.play('click', { vol: 0.4, rate: 0.8 }) || this.tone(880, 0.1, 'sine', 0.15); },
  error() { this.tone(220, 0.1, 'square', 0.08); this.tone(180, 0.14, 'square', 0.08, 0.08); },
  tick() { this.play('click', { vol: 0.25, rate: 1.5 }) || this.tone(1200, 0.03, 'square', 0.06); },

  // ───── cards ─────
  card() {
    if (!this.play('card_play', { vol: 1 })) { this.hit(2400, 0.08, 0.6, 0, 1.2); this.tone(520, 0.1, 'triangle', 0.2, 0, 300); }
  },
  cardDraw(when) { this.play('card_draw', { vol: 0.8, when }) || this.hit(1800, 0.12, 0.4, when || 0, 1); },
  deal(i) { this.play('card_draw', { vol: 0.5, rate: 1.25 }) || this.play('card_play', { vol: 0.35, rate: 1.3 }) || this.hit(3000, 0.04, 0.25); },
  shuffle() { this.play('shuffle', { vol: 0.85, vary: 0 }) || this.dice(); },
  uno() {
    if (!this.say('v_uno', 1)) { this.tone(988, 0.25, 'sine', 0.3); this.tone(1319, 0.45, 'sine', 0.25, 0.12); }
    this.play('bell', { vol: 0.35, when: 0.1, vary: 0 });
  },

  // ───── sheep ─────
  baa(side) {
    if (this.play('sheep', { vol: 0.8, rate: side ? 0.92 : 1.08, vary: 0.08, pan: side ? -0.3 : 0.3 })) return;
    // synthesised bleat: wobbling buzzy voice through a vowel filter
    if (!this.ok()) return;
    const c = this.ctx, t = c.currentTime, f0 = side ? 330 : 420;
    const o = c.createOscillator(), lfo = c.createOscillator(), lg = c.createGain(), bp = c.createBiquadFilter();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(f0, t);
    o.frequency.linearRampToValueAtTime(f0 * 0.85, t + 0.55);
    lfo.frequency.value = 22;
    lg.gain.value = f0 * 0.06;
    lfo.connect(lg);
    lg.connect(o.frequency);
    bp.type = 'bandpass';
    bp.frequency.value = 1100;
    bp.Q.value = 2;
    o.connect(bp);
    this._env(bp, t, 0.04, 0.35, 0.55);
    o.start(t); lfo.start(t);
    o.stop(t + 0.7); lfo.stop(t + 0.7);
  },
  bump() { this.play('bump', { vol: 0.55 }) || this.tone(120, 0.12, 'sine', 0.35, 0, 70); },
  point(mine) {
    this.play('coin', { vol: 0.7 }) || this.home();
    if (mine) this.say('v_point', 0.8);
  },
});
document.addEventListener('pointerdown', () => Snd.unlock(), { capture: true, passive: true });
document.addEventListener('touchstart', () => Snd.unlock(), { capture: true, passive: true });

// ───────────── renderer / scene ─────────────
const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.72;
renderer.physicallyCorrectLights = false;
document.getElementById('stage').appendChild(renderer.domElement);
G.renderer = renderer;

const scene = (G.scene = new THREE.Scene());
const camera = (G.camera = new THREE.PerspectiveCamera(38, window.innerWidth / window.innerHeight, 0.1, 200));

// environment reflections from a tiny "studio room"
(function env() {
  const pm = new THREE.PMREMGenerator(renderer);
  const room = new THREE.Scene();
  room.add(new THREE.Mesh(new THREE.BoxGeometry(30, 20, 30), new THREE.MeshBasicMaterial({ color: 0x3e3530, side: THREE.BackSide })));
  const panel = (x, y, z, w, h, c) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: c, side: THREE.DoubleSide }));
    m.position.set(x, y, z);
    m.lookAt(0, 0, 0);
    room.add(m);
  };
  panel(0, 9.5, 0, 10, 10, 0xd8d0c8);
  panel(-14, 4, 4, 8, 6, 0xfff1dd);
  panel(14, 5, -4, 8, 6, 0xdde8ff);
  panel(0, 3, 14, 12, 4, 0xb8b0a8);
  scene.environment = pm.fromScene(room, 0.03).texture;
})();

G.setBackground = function (top, bottom) {
  const c = document.createElement('canvas');
  c.width = 4;
  c.height = 256;
  const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 256);
  gr.addColorStop(0, top);
  gr.addColorStop(1, bottom);
  g.fillStyle = gr;
  g.fillRect(0, 0, 4, 256);
  const t = new THREE.CanvasTexture(c);
  t.encoding = THREE.sRGBEncoding;
  scene.background = t;
};

// lights
const hemi = new THREE.HemisphereLight(0xfff6ea, 0x5a4636, 0.32);
scene.add(hemi);
const sun = (G.sun = new THREE.DirectionalLight(0xfff3e2, 1.15));
sun.position.set(-5, 13, -3);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -11;
sun.shadow.camera.right = 11;
sun.shadow.camera.top = 11;
sun.shadow.camera.bottom = -11;
sun.shadow.camera.near = 1;
sun.shadow.camera.far = 40;
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.02;
sun.shadow.radius = 4;
scene.add(sun);
const fill = new THREE.DirectionalLight(0xcfe0ff, 0.45);
fill.position.set(6, 5, 8);
scene.add(fill);

// ───────────── procedural textures ─────────────
G.canvasTex = function (w, h, draw, repeat) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  t.encoding = THREE.sRGBEncoding;
  t.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  if (repeat) {
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(repeat, repeat);
  }
  return t;
};

function shade(hex, amt) {
  const c = new THREE.Color(hex);
  const hsl = {};
  c.getHSL(hsl);
  c.setHSL(hsl.h, hsl.s, Math.max(0, Math.min(1, hsl.l + amt)));
  return '#' + c.getHexString();
}
G.shade = shade;

/** Wood grain painted into a 2D context region. */
G.woodGrain = function (g, x, y, w, h, base, seed, strength) {
  strength = strength == null ? 1 : strength;
  let s = seed || 1;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  g.save();
  g.beginPath();
  g.rect(x, y, w, h);
  g.clip();
  g.fillStyle = base;
  g.fillRect(x, y, w, h);
  const lines = Math.floor(h / 3);
  for (let i = 0; i < lines; i++) {
    const yy = y + (i / lines) * h + rnd() * 3;
    g.strokeStyle = rnd() > 0.5 ? shade(base, -0.06 * strength - rnd() * 0.05 * strength) : shade(base, 0.03 * strength);
    g.globalAlpha = 0.25 + rnd() * 0.35;
    g.lineWidth = 0.6 + rnd() * 1.8;
    g.beginPath();
    const ph = rnd() * 6, amp = 1 + rnd() * 3, fr = 0.004 + rnd() * 0.01;
    for (let xx = x; xx <= x + w; xx += 6) {
      const yv = yy + Math.sin(xx * fr + ph) * amp + Math.sin(xx * fr * 3.1 + ph) * amp * 0.3;
      xx === x ? g.moveTo(xx, yv) : g.lineTo(xx, yv);
    }
    g.stroke();
  }
  // knots
  for (let k = 0; k < Math.max(1, (w * h) / 90000); k++) {
    if (rnd() > 0.6) continue;
    const kx = x + rnd() * w, ky = y + rnd() * h, kr = 4 + rnd() * 10;
    for (let r = kr; r > 1; r -= 2) {
      g.globalAlpha = 0.12;
      g.strokeStyle = shade(base, -0.15 * strength);
      g.beginPath();
      g.ellipse(kx, ky, r * 2.2, r, 0, 0, Math.PI * 2);
      g.stroke();
    }
  }
  g.globalAlpha = 1;
  g.restore();
};

G.rrect = function (g, x, y, w, h, r) {
  g.beginPath();
  g.moveTo(x + r, y);
  g.arcTo(x + w, y, x + w, y + h, r);
  g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r);
  g.arcTo(x, y, x + w, y, r);
  g.closePath();
};

G.woodTexture = function (base, seed, rep) {
  return G.canvasTex(512, 512, (g, w, h) => G.woodGrain(g, 0, 0, w, h, base, seed), rep);
};

// table under the board
G.addTable = function (color, size) {
  const tex = G.woodTexture(color || '#9b6b43', 7, 3);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(size || 80, size || 80), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.75, metalness: 0 }));
  m.rotation.x = -Math.PI / 2;
  m.position.y = -0.001;
  m.receiveShadow = true;
  scene.add(m);
  return m;
};

// ───────────── geometry helpers ─────────────
G.lathe = function (pts, seg) {
  return new THREE.LatheGeometry(pts.map((p) => new THREE.Vector2(p[0], p[1])), seg || 40);
};

/** Points for a sphere-ish cap in a lathe profile. */
G.arc = function (cx, cy, r, a0, a1, n) {
  const out = [];
  for (let i = 0; i <= n; i++) {
    const a = a0 + ((a1 - a0) * i) / n;
    out.push([Math.max(0.0001, cx + Math.cos(a) * r), cy + Math.sin(a) * r]);
  }
  return out;
};

G.roundedBox = function (w, h, d, r, seg) {
  seg = seg || 5;
  const geo = new THREE.BoxGeometry(w, h, d, seg, seg, seg);
  const p = geo.attributes.position, v = new THREE.Vector3(), inner = new THREE.Vector3(w / 2 - r, h / 2 - r, d / 2 - r);
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const c = new THREE.Vector3(Math.max(-inner.x, Math.min(inner.x, v.x)), Math.max(-inner.y, Math.min(inner.y, v.y)), Math.max(-inner.z, Math.min(inner.z, v.z)));
    const n = v.clone().sub(c).normalize().multiplyScalar(r);
    v.copy(c).add(n);
    p.setXYZ(i, v.x, v.y, v.z);
  }
  geo.computeVertexNormals();
  return geo;
};

G.shadowed = function (o) {
  o.traverse((m) => {
    if (m.isMesh) {
      m.castShadow = true;
      m.receiveShadow = true;
    }
  });
  return o;
};

// ───────────── tweens ─────────────
const tweens = [];
G.ease = {
  linear: (t) => t,
  out: (t) => 1 - Math.pow(1 - t, 3),
  inOut: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  back: (t) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
};
G.fast = false; // true while catching up on moves made before we joined
G.tween = function (ms, fn, ease) {
  if (G.fast) { fn((ease || G.ease.inOut)(1)); return Promise.resolve(); }
  return new Promise((res) => tweens.push({ t0: performance.now(), ms, fn, ease: ease || G.ease.inOut, res }));
};
G.wait = (ms) => (G.fast ? Promise.resolve() : new Promise((r) => setTimeout(r, ms)));

/** Hop an object from its position to `to` with an arc of height h. */
G.hopTo = function (obj, to, ms, h) {
  const from = obj.position.clone();
  const k0 = obj.userData.baseScale || obj.scale.y;
  obj.userData.baseScale = k0;
  return G.tween(ms, (t) => {
    obj.position.lerpVectors(from, to, t);
    obj.position.y = from.y + (to.y - from.y) * t + Math.sin(t * Math.PI) * (h == null ? 0.6 : h);
    const sq = 1 - Math.sin(t * Math.PI) * 0.08;
    obj.scale.set(k0 / Math.sqrt(sq), k0 * sq, k0 / Math.sqrt(sq));
  }, G.ease.inOut).then(() => obj.scale.setScalar(k0));
};

// ───────────── camera orbit + taps ─────────────
const orbit = (G.orbit = { target: new THREE.Vector3(), theta: 0, phi: 0.75, radius: 16, minR: 6, maxR: 40, def: null });
G.setView = function (target, phi, radius, theta) {
  orbit.target.copy(target);
  orbit.phi = phi;
  orbit.radius = radius;
  orbit.theta = theta || 0;
  orbit.def = { phi, radius, theta: orbit.theta };
  updateCam();
};
G.resetView = function () {
  if (!orbit.def) return;
  const s = { phi: orbit.phi, radius: orbit.radius, theta: orbit.theta }, d = orbit.def;
  let dt = d.theta - s.theta;
  while (dt > Math.PI) dt -= Math.PI * 2;
  while (dt < -Math.PI) dt += Math.PI * 2;
  G.tween(600, (t) => {
    orbit.phi = s.phi + (d.phi - s.phi) * t;
    orbit.radius = s.radius + (d.radius - s.radius) * t;
    orbit.theta = s.theta + dt * t;
    updateCam();
  });
};
/** Distance so a square board of `size` fits the screen. */
G.fitRadius = function (size, phi) {
  const a = window.innerWidth / window.innerHeight;
  const vf = THREE.MathUtils.degToRad(camera.fov);
  const hf = 2 * Math.atan(Math.tan(vf / 2) * a);
  const half = size * 0.5;
  // near edge of the board is closer to the camera, so it looks wider – fit that
  const rW = half / Math.tan(hf / 2) + half * Math.sin(phi) * 0.9;
  const rH = (half * Math.cos(phi) * 1.25) / Math.tan(vf / 2);
  return Math.max(rW, rH);
};
function updateCam() {
  const o = orbit, sp = Math.sin(o.phi);
  camera.position.set(o.target.x + o.radius * sp * Math.sin(o.theta), o.target.y + o.radius * Math.cos(o.phi), o.target.z + o.radius * sp * Math.cos(o.theta));
  camera.lookAt(o.target);
}
G.updateCam = updateCam;

const ray = new THREE.Raycaster(), ndc = new THREE.Vector2();
G.pick = function (x, y, objects) {
  ndc.set((x / window.innerWidth) * 2 - 1, -(y / window.innerHeight) * 2 + 1);
  ray.setFromCamera(ndc, camera);
  return ray.intersectObjects(objects, true);
};
G.pickPlane = function (x, y, h) {
  ndc.set((x / window.innerWidth) * 2 - 1, -(y / window.innerHeight) * 2 + 1);
  ray.setFromCamera(ndc, camera);
  const p = new THREE.Vector3();
  return ray.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0, 1, 0), -(h || 0)), p) ? p : null;
};

G.onTap = null;
(function input() {
  const el = renderer.domElement;
  const pts = new Map();
  let start = null, moved = false, pinch0 = 0, r0 = 0;
  el.addEventListener('pointerdown', (e) => {
    Snd.unlock();
    el.setPointerCapture(e.pointerId);
    pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pts.size === 1) {
      start = { x: e.clientX, y: e.clientY, th: orbit.theta, ph: orbit.phi };
      moved = false;
    } else if (pts.size === 2) {
      const [a, b] = [...pts.values()];
      pinch0 = Math.hypot(a.x - b.x, a.y - b.y);
      r0 = orbit.radius;
      moved = true;
    }
  });
  el.addEventListener('pointermove', (e) => {
    if (!pts.has(e.pointerId)) return;
    pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pts.size === 2) {
      const [a, b] = [...pts.values()];
      const d = Math.hypot(a.x - b.x, a.y - b.y);
      if (pinch0 > 0) orbit.radius = Math.max(orbit.minR, Math.min(orbit.maxR, (r0 * pinch0) / d));
      updateCam();
      return;
    }
    if (!start) return;
    const dx = e.clientX - start.x, dy = e.clientY - start.y;
    if (Math.hypot(dx, dy) > 10) moved = true;
    if (moved) {
      orbit.theta = start.th - dx * 0.008;
      orbit.phi = Math.max(0.12, Math.min(1.25, start.ph - dy * 0.006));
      updateCam();
    }
  });
  const up = (e) => {
    if (!pts.has(e.pointerId)) return;
    pts.delete(e.pointerId);
    if (pts.size === 0) {
      if (!moved && start && G.onTap) G.onTap(e.clientX, e.clientY);
      start = null;
    }
  };
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('wheel', (e) => {
    orbit.radius = Math.max(orbit.minR, Math.min(orbit.maxR, orbit.radius * (1 + e.deltaY * 0.001)));
    updateCam();
  });
})();

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  if (G.onResize) G.onResize();
});

// ───────────── frame loop ─────────────
G.onFrame = [];
let last = performance.now();
function loop(now) {
  requestAnimationFrame(loop);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  for (let i = tweens.length - 1; i >= 0; i--) {
    const tw = tweens[i];
    const k = Math.min(1, (now - tw.t0) / tw.ms);
    tw.fn(tw.ease(k));
    if (k >= 1) {
      tweens.splice(i, 1);
      tw.res();
    }
  }
  for (const f of G.onFrame) f(dt, now / 1000);
  renderer.render(scene, camera);
}
requestAnimationFrame(loop);

// ───────────── 3D dice ─────────────
G.makeDice = function (size, color, pip) {
  const faces = { px: 3, nx: 4, py: 1, ny: 6, pz: 2, nz: 5 };
  const spots = {
    1: [[0.5, 0.5]],
    2: [[0.27, 0.27], [0.73, 0.73]],
    3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
    4: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.73], [0.73, 0.73]],
    5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
    6: [[0.27, 0.22], [0.73, 0.22], [0.27, 0.5], [0.73, 0.5], [0.27, 0.78], [0.73, 0.78]],
  };
  const mat = (n) =>
    new THREE.MeshPhysicalMaterial({
      map: G.canvasTex(256, 256, (g, w) => {
        g.fillStyle = color || '#fffaf0';
        g.fillRect(0, 0, w, w);
        for (const s of spots[n]) {
          const gr = g.createRadialGradient(s[0] * w - 4, s[1] * w - 4, 2, s[0] * w, s[1] * w, w * 0.1);
          gr.addColorStop(0, n === 1 ? '#ff5a6a' : '#3a3a48');
          gr.addColorStop(1, n === 1 ? '#c8102e' : pip || '#14141c');
          g.fillStyle = gr;
          g.beginPath();
          g.arc(s[0] * w, s[1] * w, n === 1 ? w * 0.13 : w * 0.085, 0, Math.PI * 2);
          g.fill();
        }
      }),
      roughness: 0.25,
      clearcoat: 1,
      clearcoatRoughness: 0.15,
    });
  const m = new THREE.Mesh(G.roundedBox(size, size, size, size * 0.16, 6), [mat(faces.px), mat(faces.nx), mat(faces.py), mat(faces.ny), mat(faces.pz), mat(faces.nz)]);
  m.castShadow = true;
  m.receiveShadow = true;
  m.userData.size = size;
  return m;
};

const faceQ = {
  1: new THREE.Quaternion(),
  6: new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), Math.PI),
  2: new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2),
  5: new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), Math.PI / 2),
  3: new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), Math.PI / 2),
  4: new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), -Math.PI / 2),
};

/** Throw the dice so it lands showing `value` at position `to`. */
G.rollDice = function (dice, value, to, from) {
  Snd.dice();
  G.haptic('medium');
  const s = dice.userData.size;
  const end = to.clone();
  end.y = to.y + s / 2;
  const start = from ? from.clone() : end.clone().add(new THREE.Vector3((Math.random() - 0.5) * 3, 3.5, 3));
  const yaw = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.random() * Math.PI * 2);
  const qEnd = yaw.clone().multiply(faceQ[value]);
  const axis = new THREE.Vector3(Math.random() - 0.5, Math.random() * 0.4, Math.random() - 0.5).normalize();
  const turns = 3 + Math.random() * 2;
  const tmp = new THREE.Quaternion();
  return G.tween(1000, (t) => {
    const k = G.ease.out(t);
    dice.position.lerpVectors(start, end, k);
    // bounces
    const b = Math.abs(Math.sin(t * Math.PI * 3)) * (1 - t) * 1.6;
    dice.position.y = end.y + (start.y - end.y) * Math.pow(1 - t, 3) + b;
    tmp.setFromAxisAngle(axis, (1 - k) * turns * Math.PI * 2);
    dice.quaternion.copy(qEnd).premultiply(tmp);
  }, G.ease.linear).then(() => {
    dice.quaternion.copy(qEnd);
    dice.position.copy(end);
    Snd.wood();
  });
};

// ───────────── confetti ─────────────
G.confetti = function (center, spread) {
  const cols = [0xff3b30, 0xffcc00, 0x34c759, 0x007aff, 0xaf52de, 0xff4f8b];
  const group = new THREE.Group();
  const geo = new THREE.PlaneGeometry(0.18, 0.1);
  const parts = [];
  for (let i = 0; i < 160; i++) {
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: cols[i % cols.length], side: THREE.DoubleSide }));
    m.position.set(center.x + (Math.random() - 0.5) * spread, center.y + 6 + Math.random() * 6, center.z + (Math.random() - 0.5) * spread);
    m.rotation.set(Math.random() * 6, Math.random() * 6, Math.random() * 6);
    parts.push({ m, v: 1.5 + Math.random() * 2.5, s: Math.random() * 6, r: (Math.random() - 0.5) * 8 });
    group.add(m);
  }
  scene.add(group);
  const f = (dt, t) => {
    for (const p of parts) {
      p.m.position.y -= p.v * dt;
      p.m.position.x += Math.sin(t * 2 + p.s) * dt * 0.8;
      p.m.rotation.x += p.r * dt;
      p.m.rotation.y += p.r * dt * 0.7;
    }
  };
  G.onFrame.push(f);
  setTimeout(() => {
    scene.remove(group);
    G.onFrame.splice(G.onFrame.indexOf(f), 1);
  }, 7000);
};

// ───────────── HUD helpers ─────────────
G.$ = (id) => document.getElementById(id);
G.toast = function (text, ms) {
  const t = G.$('toast');
  t.textContent = text;
  t.classList.add('show');
  clearTimeout(t._h);
  t._h = setTimeout(() => t.classList.remove('show'), ms || 1600);
};
G.status = (text) => { G.$('status').innerHTML = text; };
G.players = function (list, turn) {
  const el = G.$('players');
  el.innerHTML = '';
  list.forEach((p, i) => {
    const d = document.createElement('div');
    d.className = 'pl' + (i === turn ? ' on' : '');
    d.style.setProperty('--c', p.color);
    d.innerHTML = '<span class="dot"></span>' + (p.bot ? '🤖 ' : '') + p.name + (p.extra ? ' <b>' + p.extra + '</b>' : '');
    el.appendChild(d);
  });
};
G.winScreen = function (title, sub, again) {
  Snd.win();
  G.haptic('heavy');
  const w = G.$('win');
  G.$('winTitle').textContent = title;
  G.$('winSub').textContent = sub || '';
  w.classList.add('show');
  G.$('again').onclick = () => {
    w.classList.remove('show');
    again();
  };
};
G.$('back').onclick = () => G.post('exit');
G.$('cam').onclick = () => G.resetView();
G.$('sound').onclick = () => {
  Snd.setOn(!Snd.on);
  G.$('sound').textContent = Snd.on ? '🔊' : '🔇';
};
G.$('exitWin').onclick = () => G.post('exit');


// ───────────── live emoji reactions (tease each other while playing!) ─────────────
(function emojis() {
  const EMO = ['😜', '😂', '🤪', '😎', '🔥', '😈', '🤡', '🙈', '😤', '🥱', '👀', '💪', '🐢', '🏆', '😭', '💩', '😘', '🥳', '🤯', '👻'];
  const TAUNTS = [
    ['🐢', 'Too slow!', 'నెమ్మదిగా ఆడుతున్నావ్!'], ['😂', 'Ha ha ha!', 'హ హ హ!'], ['💪', 'Bring it on!', 'రా చూసుకుందాం!'],
    ['😎', 'Watch me win!', 'నేనే గెలుస్తా!'], ['🙈', 'Oops!', 'అయ్యో!'], ['😈', 'Revenge time!', 'ప్రతీకారం!'],
  ];
  const st = document.createElement('style');
  st.textContent = `
  #emoPanel { position: fixed; right: 10px; top: calc(env(safe-area-inset-top) + 62px); z-index: 11; display: none; width: min(320px, calc(100vw - 20px));
    background: linear-gradient(#fffbf6, #f3ecfd); border-radius: 26px; padding: 12px; box-shadow: 0 8px 0 #d9cdf2, 0 18px 40px rgba(60,30,90,.35); animation: pop .25s cubic-bezier(.2,1.6,.4,1); }
  #emoPanel.show { display: block; }
  #emoPanel .grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 6px; }
  #emoPanel .e { border: none; background: #fff; border-radius: 16px; font-size: 30px; height: 50px; box-shadow: 0 3px 0 #e6dcf7; }
  #emoPanel .e:active { transform: translateY(3px); box-shadow: none; }
  #emoPanel .taunts { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
  #emoPanel .t { border: none; border-radius: 14px; padding: 7px 10px; font-weight: 800; font-size: 13px; color: #4e3b5c; background: #e9defb; box-shadow: 0 3px 0 #cdbdf0; }
  .flyEmo { position: fixed; z-index: 12; pointer-events: none; display: flex; flex-direction: column; align-items: center; animation: emoFly 5s cubic-bezier(.2,.8,.3,1) forwards; }
  .flyEmo .big { font-size: 84px; filter: drop-shadow(0 6px 10px rgba(0,0,0,.35)); animation: emoWob .6s ease-in-out infinite alternate; }
  .flyEmo .who { margin-top: -4px; background: #fffbf6; color: #4e3b5c; font-weight: 900; font-size: 13px; padding: 4px 10px; border-radius: 12px; box-shadow: 0 3px 0 #d9cdf2; white-space: nowrap; max-width: 70vw; overflow: hidden; text-overflow: ellipsis; }
  .miniEmo { position: fixed; z-index: 11; pointer-events: none; font-size: 30px; animation: emoMini 2.4s ease-out forwards; }
  @keyframes emoFly { 0% { transform: translate(-50%, 40px) scale(.2); opacity: 0; } 8% { transform: translate(-50%, 0) scale(1.25); opacity: 1; } 14% { transform: translate(-50%, -10px) scale(1); }
    85% { opacity: 1; } 100% { transform: translate(-50%, -34vh) scale(.9); opacity: 0; } }
  @keyframes emoWob { from { transform: rotate(-12deg); } to { transform: rotate(12deg) scale(1.08); } }
  @keyframes emoMini { 0% { transform: translate(0,0) scale(.4); opacity: 1; } 100% { transform: translate(var(--dx), var(--dy)) scale(1.1) rotate(var(--r)); opacity: 0; } }
  `;
  document.head.appendChild(st);
  const panel = document.createElement('div');
  panel.id = 'emoPanel';
  const te = () => (G.cfg && G.cfg.lang === 'te');
  panel.innerHTML = '<div class="grid">' + EMO.map((e) => `<button class="e">${e}</button>`).join('') + '</div><div class="taunts"></div>';
  document.body.appendChild(panel);
  const fillTaunts = () => {
    panel.querySelector('.taunts').innerHTML = TAUNTS.map((t, i) => `<button class="t" data-i="${i}">${t[0]} ${te() ? t[2] : t[1]}</button>`).join('');
    panel.querySelectorAll('.t').forEach((b) => (b.onclick = () => send(TAUNTS[+b.dataset.i][0], te() ? TAUNTS[+b.dataset.i][2] : TAUNTS[+b.dataset.i][1])));
  };
  panel.querySelectorAll('.e').forEach((b) => (b.onclick = () => send(b.textContent, '')));
  let last = 0;
  function send(e, text) {
    const now = Date.now();
    if (now - last < 700) return; // no spamming
    last = now;
    panel.classList.remove('show');
    const name = (G.net && G.net.online ? G.net.name : (G.cfg && G.cfg.me)) || 'Me';
    G.showEmoji(e, name, text, true);
    if (G.sendEmoji) G.sendEmoji({ e, text, name });
  }
  const btn = document.getElementById('emo');
  if (btn) btn.onclick = () => { fillTaunts(); panel.classList.toggle('show'); G.haptic('light'); };
  document.addEventListener('pointerdown', (ev) => { if (!panel.contains(ev.target) && ev.target !== btn) panel.classList.remove('show'); }, true);

  /** Show a big floating emoji for 5 seconds, with a little burst of smaller ones. */
  G.showEmoji = function (e, name, text, mine) {
    const x = mine ? 30 + Math.random() * 14 : 56 + Math.random() * 16;
    const d = document.createElement('div');
    d.className = 'flyEmo';
    d.style.left = x + '%';
    d.style.top = '52%';
    d.innerHTML = `<div class="big">${e}</div><div class="who"></div>`;
    d.querySelector('.who').textContent = text ? `${name}: ${text}` : name;
    document.body.appendChild(d);
    setTimeout(() => d.remove(), 5100);
    for (let i = 0; i < 7; i++) {
      const m = document.createElement('div');
      m.className = 'miniEmo';
      m.textContent = e;
      m.style.left = `calc(${x}% - 15px)`;
      m.style.top = '56%';
      m.style.setProperty('--dx', (Math.random() * 220 - 110).toFixed(0) + 'px');
      m.style.setProperty('--dy', (-80 - Math.random() * 220).toFixed(0) + 'px');
      m.style.setProperty('--r', (Math.random() * 80 - 40).toFixed(0) + 'deg');
      m.style.animationDelay = (i * 0.08).toFixed(2) + 's';
      document.body.appendChild(m);
      setTimeout(() => m.remove(), 2900);
    }
    try { Snd.play('pop', { vol: 0.7 }) || Snd.tone(880, 0.12, 'sine', 0.2, 0, 1320); } catch (err) {}
    if (!mine) G.haptic('light');
  };
  /** Computer players tease too (shown on every phone the same way). */
  G.botTease = function (p, pool) {
    if (!p || G.fast || Math.random() > 0.6) return;
    const list = pool || ['😜', '😈', '😂', '😎', '🤪'];
    setTimeout(() => G.showEmoji(list[Math.floor(Math.random() * list.length)], p.name, '', false), 500);
  };
})();

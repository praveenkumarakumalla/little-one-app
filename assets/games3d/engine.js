/* Little One – shared 3D engine for the family games (three.js r149). */
'use strict';
const G = (window.G = {});
if (THREE.ColorManagement) THREE.ColorManagement.legacyMode = false; // treat colours as sRGB (rich, not washed out)

// ───────────── messages to the app ─────────────
G.post = (m) => {
  try { if (window.Flutter) window.Flutter.postMessage(m); } catch (e) {}
};
G.haptic = (k) => G.post('haptic:' + (k || 'light'));

// ───────────── sound (synthesised, no files) ─────────────
const Snd = (G.snd = {
  ctx: null,
  on: true,
  unlock() {
    if (!this.ctx) {
      try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.9;
      this.master.connect(this.ctx.destination);
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
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
  ok() { return this.on && this.ctx && this.ctx.state !== 'closed'; },
  // game sounds
  wood() { this.hit(1800, 0.06, 0.7); this.tone(420, 0.09, 'triangle', 0.35, 0, 240); },
  place() { this.hit(1300, 0.08, 0.9); this.tone(300, 0.12, 'triangle', 0.4, 0, 160); },
  select() { this.tone(880, 0.07, 'sine', 0.18); this.tone(1320, 0.06, 'sine', 0.12, 0.04); },
  hop() { this.tone(520, 0.08, 'sine', 0.22, 0, 760); this.hit(2500, 0.03, 0.25); },
  dice() {
    for (let i = 0; i < 9; i++) {
      const w = i * 0.055 + Math.random() * 0.03;
      this.hit(2200 + Math.random() * 2500, 0.03, 0.5 - i * 0.04, w, 6);
      this.hit(900 + Math.random() * 400, 0.04, 0.35 - i * 0.03, w, 3);
    }
  },
  capture() {
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
  ladder() { [523, 659, 784, 1047, 1319].forEach((n, i) => this.tone(n, 0.16, 'triangle', 0.25, i * 0.08)); },
  snake() {
    this.tone(700, 0.7, 'sawtooth', 0.12, 0, 120);
    if (!this.ok()) return;
    const c = this.ctx, t = c.currentTime, s = this._noise(0.6), f = c.createBiquadFilter();
    f.type = 'highpass';
    f.frequency.value = 5000;
    s.connect(f);
    this._env(f, t, 0.05, 0.25, 0.55);
    s.start(t);
  },
  six() { [1047, 1319, 1568, 2093].forEach((n, i) => this.tone(n, 0.12, 'sine', 0.18, i * 0.05)); },
  check() { this.tone(660, 0.12, 'square', 0.12); this.tone(660, 0.12, 'square', 0.12, 0.16); },
  home() { [784, 988, 1175, 1568].forEach((n, i) => this.tone(n, 0.2, 'triangle', 0.25, i * 0.09)); },
  win() {
    const seq = [[523, 0], [659, 0.12], [784, 0.24], [1047, 0.36], [784, 0.52], [1047, 0.64]];
    seq.forEach(([n, w]) => { this.tone(n, 0.28, 'triangle', 0.3, w); this.tone(n / 2, 0.28, 'sine', 0.2, w); });
    [523, 659, 784].forEach((n) => this.tone(n * 2, 0.9, 'sine', 0.15, 0.8));
  },
  tick() { this.tone(1200, 0.03, 'square', 0.06); },
});

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
G.tween = function (ms, fn, ease) {
  return new Promise((res) => tweens.push({ t0: performance.now(), ms, fn, ease: ease || G.ease.inOut, res }));
};
G.wait = (ms) => new Promise((r) => setTimeout(r, ms));

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
  Snd.on = !Snd.on;
  G.$('sound').textContent = Snd.on ? '🔊' : '🔇';
};
G.$('exitWin').onclick = () => G.post('exit');

window.startGame = function (cfg) {
  if (typeof cfg === 'string') cfg = JSON.parse(cfg);
  G.cfg = cfg;
  const game = { chess: window.Chess3D, ludo: window.Ludo3D, snakes: window.Snakes3D }[cfg.game];
  if (game) game.start(cfg);
  G.$('loading').style.display = 'none';
};

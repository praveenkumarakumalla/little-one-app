/* Realistic Staunton-style chess pieces and Ludo pawns, built from lathe profiles. */
'use strict';
(function () {
  const base = (r) => [
    [0.0001, 0], [r, 0], [r, 0.035], [r * 0.97, 0.06], [r * 0.9, 0.075], [r * 0.92, 0.1], [r * 0.86, 0.12], [r * 0.72, 0.14],
  ];

  function pawn() {
    const p = base(0.3).concat([[0.2, 0.18], [0.15, 0.25], [0.12, 0.34], [0.11, 0.38], [0.18, 0.4], [0.19, 0.42], [0.12, 0.44], [0.1, 0.45]]);
    return p.concat(G.arc(0, 0.55, 0.13, -Math.PI / 2 + 0.6, Math.PI / 2, 12));
  }
  function rook() {
    return base(0.33).concat([[0.24, 0.18], [0.2, 0.26], [0.18, 0.4], [0.18, 0.52], [0.23, 0.55], [0.24, 0.58], [0.21, 0.6], [0.23, 0.62], [0.24, 0.74], [0.17, 0.74], [0.17, 0.69], [0.0001, 0.69]]);
  }
  function bishop() {
    const p = base(0.31).concat([[0.21, 0.18], [0.15, 0.27], [0.12, 0.42], [0.11, 0.5], [0.19, 0.52], [0.2, 0.55], [0.12, 0.57], [0.13, 0.6]]);
    for (let i = 0; i <= 12; i++) {
      const t = i / 12;
      p.push([Math.max(0.0001, 0.155 * Math.sin(Math.PI * (0.12 + t * 0.88)) * (1 - t * 0.25)), 0.6 + t * 0.32]);
    }
    return p.concat(G.arc(0, 0.955, 0.045, -Math.PI / 2, Math.PI / 2, 8));
  }
  function queen() {
    const p = base(0.35).concat([[0.24, 0.18], [0.17, 0.3], [0.13, 0.5], [0.12, 0.62], [0.21, 0.65], [0.22, 0.68], [0.14, 0.7], [0.15, 0.74], [0.24, 0.92], [0.22, 0.95], [0.12, 0.97]]);
    return p.concat(G.arc(0, 0.98, 0.1, -0.2, Math.PI / 2, 8), G.arc(0, 1.1, 0.05, -Math.PI / 2, Math.PI / 2, 8));
  }
  function king() {
    return base(0.36).concat([[0.25, 0.18], [0.18, 0.3], [0.14, 0.52], [0.13, 0.66], [0.22, 0.69], [0.23, 0.72], [0.15, 0.74], [0.16, 0.78], [0.23, 0.95], [0.21, 0.98], [0.13, 1.0], [0.08, 1.04], [0.0001, 1.05]]);
  }

  function knightHead(mat) {
    const s = new THREE.Shape();
    const pts = [
      [-0.2, 0.0], [0.2, 0.0], [0.21, 0.12], [0.15, 0.22], [0.13, 0.3], [0.24, 0.38], [0.33, 0.45], [0.35, 0.52], [0.3, 0.57], [0.18, 0.58],
      [0.12, 0.64], [0.07, 0.72], [0.03, 0.78], [-0.04, 0.74], [-0.1, 0.72], [-0.17, 0.62], [-0.22, 0.48], [-0.23, 0.3], [-0.22, 0.15],
    ];
    s.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) s.lineTo(pts[i][0], pts[i][1]);
    s.closePath();
    const geo = new THREE.ExtrudeGeometry(s, { depth: 0.2, bevelEnabled: true, bevelThickness: 0.06, bevelSize: 0.045, bevelSegments: 4, curveSegments: 8 });
    geo.translate(0, 0, -0.1);
    geo.computeVertexNormals();
    const head = new THREE.Mesh(geo, mat);
    // ears
    const ear = new THREE.Mesh(new THREE.ConeGeometry(0.035, 0.11, 10), mat);
    ear.position.set(0.0, 0.8, 0.05);
    ear.rotation.z = 0.25;
    const ear2 = ear.clone();
    ear2.position.z = -0.05;
    const g = new THREE.Group();
    g.add(head, ear, ear2);
    // mane ridge
    const mane = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.03, 8, 16, Math.PI * 0.75), mat);
    mane.position.set(0.0, 0.48, 0);
    mane.rotation.z = Math.PI * 0.42;
    g.add(mane);
    return g;
  }

  const crenel = (g, mat) => {
    for (let i = 0; i < 4; i++) {
      const b = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.08, 0.1), mat);
      const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
      b.position.set(Math.cos(a) * 0.19, 0.78, Math.sin(a) * 0.19);
      b.rotation.y = -a;
      g.add(b);
    }
  };

  /** type: 1 pawn … 6 king. Returns a Group standing on y = 0, facing +x for the knight. */
  window.makeChessPiece = function (type, mat, accent) {
    const g = new THREE.Group();
    const L = (pts) => new THREE.Mesh(G.lathe(pts, 48), mat);
    switch (type) {
      case 1: g.add(L(pawn())); break;
      case 4: g.add(L(rook())); crenel(g, mat); break;
      case 3: {
        g.add(L(bishop()));
        const slit = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.12, 0.3), accent || mat);
        slit.position.set(0.04, 0.8, 0);
        slit.rotation.z = -0.6;
        g.add(slit);
        break;
      }
      case 5: {
        g.add(L(queen()));
        for (let i = 0; i < 8; i++) {
          const b = new THREE.Mesh(new THREE.SphereGeometry(0.035, 12, 10), mat);
          const a = (i / 8) * Math.PI * 2;
          b.position.set(Math.cos(a) * 0.22, 0.96, Math.sin(a) * 0.22);
          g.add(b);
        }
        break;
      }
      case 6: {
        g.add(L(king()));
        const v = new THREE.Mesh(G.roundedBox(0.06, 0.24, 0.06, 0.015, 3), mat);
        v.position.y = 1.15;
        const h = new THREE.Mesh(G.roundedBox(0.18, 0.06, 0.06, 0.015, 3), mat);
        h.position.y = 1.18;
        g.add(v, h);
        break;
      }
      case 2: {
        g.add(L(base(0.32).concat([[0.24, 0.17], [0.22, 0.2], [0.0001, 0.2]])));
        const k = knightHead(mat);
        k.position.y = 0.17;
        g.add(k);
        break;
      }
    }
    return G.shadowed(g);
  };

  /** A glossy Ludo / Snakes pawn ("man"). */
  window.makePawn = function (color, h) {
    h = h || 1;
    const mat = new THREE.MeshPhysicalMaterial({ color, roughness: 0.28, metalness: 0.05, clearcoat: 1, clearcoatRoughness: 0.12, sheen: 0.4 });
    const pts = [[0.0001, 0], [0.33, 0], [0.34, 0.04], [0.31, 0.09], [0.24, 0.12], [0.2, 0.2], [0.15, 0.36], [0.12, 0.5], [0.2, 0.53], [0.2, 0.56], [0.1, 0.59]];
    const body = new THREE.Mesh(G.lathe(pts.concat(G.arc(0, 0.72, 0.17, -Math.PI / 2 + 0.55, Math.PI / 2, 14)), 40), mat);
    const g = new THREE.Group();
    g.add(body);
    // cute face: two eyes
    const eyeW = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.3 });
    const eyeB = new THREE.MeshStandardMaterial({ color: 0x111111, roughness: 0.2 });
    for (const s of [-1, 1]) {
      const e = new THREE.Mesh(new THREE.SphereGeometry(0.045, 12, 10), eyeW);
      e.position.set(s * 0.06, 0.75, 0.145);
      const p = new THREE.Mesh(new THREE.SphereGeometry(0.025, 10, 8), eyeB);
      p.position.set(s * 0.06, 0.75, 0.183);
      g.add(e, p);
    }
    const blush = new THREE.MeshBasicMaterial({ color: 0xff8fb3, transparent: true, opacity: 0.6 });
    for (const s of [-1, 1]) {
      const b = new THREE.Mesh(new THREE.CircleGeometry(0.03, 12), blush);
      b.position.set(s * 0.11, 0.69, 0.155);
      b.rotation.y = s * 0.6;
      g.add(b);
    }
    g.scale.setScalar(h);
    g.userData.mat = mat;
    return G.shadowed(g);
  };

  /** Pulsing ring under a selectable piece. */
  window.makeRing = function (color, r) {
    const m = new THREE.Mesh(new THREE.TorusGeometry(r || 0.38, 0.045, 10, 40), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.9 }));
    m.rotation.x = -Math.PI / 2;
    return m;
  };
})();

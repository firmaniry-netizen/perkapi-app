// Ikon 3D PERKAPI — gaya "clay" lembut, warna merek. Satu model per kata kunci, dirender ke PNG transparan.
import * as THREE from "./three/build/three.module.js";
import { RoomEnvironment } from "./three/examples/jsm/environments/RoomEnvironment.js";

const C = {
  navy: 0x1a3787, navyDeep: 0x0e1f4d, sky: 0x4a7fe6, gold: 0xd9a21f, goldDeep: 0xa87414,
  maroon: 0x9c1a2a, cream: 0xf6f1e6, white: 0xffffff, ink: 0x2b3245, wood: 0x8a5a2b, teal: 0x14918a,
};
const mat = (c, o = {}) => new THREE.MeshPhysicalMaterial({ color: c, roughness: 0.45, metalness: 0, clearcoat: 0.5, clearcoatRoughness: 0.35, envMapIntensity: 0.55, ...o });
const metal = (c) => mat(c, { metalness: 0.3, roughness: 0.3, clearcoat: 0.9, envMapIntensity: 0.9 });
const M = (g, m, x = 0, y = 0, z = 0) => { const o = new THREE.Mesh(g, m); o.position.set(x, y, z); o.castShadow = true; o.receiveShadow = true; return o; };

// kotak membulat (lebar w, tinggi h, tebal d, radius r) — berdiri di bidang XY, tebal ke Z
function rbox(w, h, d, r = 0.12, seg = 5) {
  r = Math.min(r, w / 2 - 1e-3, h / 2 - 1e-3, d / 2 - 1e-3);
  const s = new THREE.Shape(), x = -w / 2 + r, y = -h / 2 + r, W = w - 2 * r, H = h - 2 * r, k = Math.min(r * 0.9, W / 2, H / 2) || 0.001;
  s.moveTo(x + k, y); s.lineTo(x + W - k, y); s.quadraticCurveTo(x + W, y, x + W, y + k); s.lineTo(x + W, y + H - k);
  s.quadraticCurveTo(x + W, y + H, x + W - k, y + H); s.lineTo(x + k, y + H); s.quadraticCurveTo(x, y + H, x, y + H - k);
  s.lineTo(x, y + k); s.quadraticCurveTo(x, y, x + k, y);
  const g = new THREE.ExtrudeGeometry(s, { depth: Math.max(1e-3, d - 2 * r), bevelEnabled: true, bevelThickness: r, bevelSize: r, bevelSegments: seg, curveSegments: 10 });
  g.translate(0, 0, -(d - 2 * r) / 2); g.computeVertexNormals(); return g;
}
function extrude(shape, d, b = 0.05) {
  const g = new THREE.ExtrudeGeometry(shape, { depth: d, bevelEnabled: true, bevelThickness: b, bevelSize: b, bevelSegments: 4, curveSegments: 24 });
  g.center(); return g;
}
const cyl = (r1, r2, h, s = 48) => new THREE.CylinderGeometry(r1, r2, h, s);
const sph = (r) => new THREE.SphereGeometry(r, 48, 32);
const tor = (R, r, arc = Math.PI * 2) => new THREE.TorusGeometry(R, r, 20, 64, arc);
const cap = (r, l) => new THREE.CapsuleGeometry(r, l, 10, 24);
function G(...xs) { const g = new THREE.Group(); xs.forEach((x) => x && g.add(x)); return g; }
const rot = (o, x = 0, y = 0, z = 0) => { o.rotation.set(x, y, z); return o; };
const at = (o, x = 0, y = 0, z = 0) => { o.position.set(x, y, z); return o; };
function lines(n, w, x, y, z, gap, m, th = 0.07) { const g = new THREE.Group(); for (let i = 0; i < n; i++) g.add(M(rbox(w * (i === n - 1 ? 0.6 : 1), th, 0.04, 0.03), m, x + (i === n - 1 ? -w * 0.2 : 0), y - i * gap, z)); return g; }
function dotsGrid(nx, ny, s, gap, m, hi, hiIdx = -1) { const g = new THREE.Group(); let k = 0; for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++, k++) g.add(M(rbox(s, s, 0.06, 0.03), k === hiIdx ? hi : m, (i - (nx - 1) / 2) * gap, -(j - (ny - 1) / 2) * gap, 0)); return g; }
function star(R, r, n = 5) { const s = new THREE.Shape(); for (let i = 0; i < n * 2; i++) { const a = Math.PI / 2 + (i * Math.PI) / n, rr = i % 2 ? r : R; const p = [Math.cos(a) * rr, Math.sin(a) * rr]; i ? s.lineTo(...p) : s.moveTo(...p); } s.closePath(); return s; }
function check() { const s = new THREE.Shape(); s.moveTo(-0.42, 0.02); s.lineTo(-0.27, 0.17); s.lineTo(-0.1, 0); s.lineTo(0.3, 0.4); s.lineTo(0.45, 0.25); s.lineTo(-0.1, -0.3); s.closePath(); return s; }
function bubble(w, h, d, m, tailLeft = true) {
  const g = G(M(rbox(w, h, d, Math.min(w, h) * 0.32), m));
  const t = M(cyl(0, h * 0.2, h * 0.32, 24), m, (tailLeft ? -1 : 1) * w * 0.26, -h * 0.55, 0);
  t.rotation.z = (tailLeft ? -1 : 1) * 0.5 + Math.PI; g.add(t); return g;
}

const B = {
  berita() {
    const back = rot(G(M(rbox(1.5, 1.9, 0.06, 0.04), mat(C.white))), 0, 0, 0.12); at(back, 0.18, 0.05, -0.12);
    const top = G(M(rbox(1.5, 1.9, 0.07, 0.04), mat(C.cream)), M(rbox(1.3, 0.26, 0.05, 0.03), mat(C.navy), 0, 0.68, 0.05),
      M(rbox(0.55, 0.5, 0.05, 0.03), mat(C.gold), -0.36, 0.2, 0.05), lines(3, 0.62, 0.32, 0.38, 0.05, 0.16, mat(0x9aa3b8)), lines(4, 1.25, 0, -0.25, 0.05, 0.17, mat(0xb9c0cf)));
    return rot(G(back, top), -0.05, 0, -0.06);
  },
  kalender() {
    const g = G(M(rbox(1.7, 1.6, 0.34, 0.16), mat(C.white)), M(rbox(1.7, 0.44, 0.36, 0.16), mat(C.maroon), 0, 0.6, 0.01),
      M(tor(0.12, 0.045), metal(C.gold), -0.45, 0.86, 0), M(tor(0.12, 0.045), metal(C.gold), 0.45, 0.86, 0));
    g.children[2].rotation.y = g.children[3].rotation.y = Math.PI / 2;
    g.add(at(dotsGrid(4, 3, 0.2, 0.3, mat(0xc9cfdc), mat(C.gold), 6), 0, -0.2, 0.19));
    return g;
  },
  hukum() {
    const book = G(M(rbox(1.8, 0.32, 1.3, 0.08), mat(C.navy)), M(rbox(1.66, 0.24, 1.2, 0.04), mat(C.cream), 0.06, 0, 0), M(rbox(0.08, 0.34, 1.32, 0.03), mat(C.gold), -0.62, 0, 0));
    const head = G(M(cyl(0.2, 0.2, 0.8), mat(C.wood)), M(cyl(0.215, 0.215, 0.08), metal(C.gold), 0, 0.28, 0), M(cyl(0.215, 0.215, 0.08), metal(C.gold), 0, -0.28, 0));
    rot(head, 0, 0, Math.PI / 2); at(head, 0, 0.42, 0);
    const handle = rot(M(cyl(0.06, 0.07, 1.2), mat(C.wood)), Math.PI / 2, 0, 0); at(handle, 0, 0.42, 0.55);
    const gavel = rot(G(head, handle), 0, -0.6, 0.18); at(gavel, 0.1, 0.18, 0);
    return G(book, gavel);
  },
  forum() {
    const a = at(bubble(1.35, 1.0, 0.32, mat(C.navy), true), -0.32, 0.32, -0.2);
    const b = at(bubble(1.25, 0.92, 0.34, mat(C.gold), false), 0.36, -0.3, 0.2);
    [-0.3, 0, 0.3].forEach((x) => b.add(M(sph(0.085), mat(C.white), x, 0, 0.18)));
    return G(a, b);
  },
  chat() {
    const b = bubble(1.7, 1.25, 0.4, mat(C.sky), true);
    [-0.4, 0, 0.4].forEach((x) => b.add(M(sph(0.12), mat(C.white), x, 0, 0.22)));
    return b;
  },
  ai() {
    const s = M(extrude(star(1, 0.3, 4), 0.28, 0.08), mat(C.gold, { clearcoat: 1, roughness: 0.25 }));
    const s2 = M(extrude(star(0.38, 0.12, 4), 0.14, 0.04), mat(C.sky), 0.82, 0.78, 0.1);
    const s3 = M(extrude(star(0.26, 0.08, 4), 0.1, 0.03), mat(C.maroon), -0.85, -0.7, 0.1);
    return G(s, s2, s3);
  },
  semua() {
    const cs = [C.navy, C.gold, C.maroon, C.sky], g = new THREE.Group();
    [[-1, 1], [1, 1], [-1, -1], [1, -1]].forEach(([x, y], i) => g.add(M(rbox(0.78, 0.78, 0.26, 0.2), mat(cs[i]), x * 0.46, y * 0.46, i === 1 ? 0.18 : 0)));
    return g;
  },
  kartu() {
    const g = G(M(rbox(2.0, 1.3, 0.1, 0.06), mat(C.navy)), M(rbox(2.0, 0.2, 0.11, 0.05), mat(C.gold), 0, 0.42, 0.002),
      M(cyl(0.24, 0.24, 0.06), mat(C.cream), -0.6, -0.08, 0.06), lines(3, 0.6, -0.02, 0.05, 0.06, 0.17, mat(0xbfc9e6)));
    g.children[2].rotation.x = Math.PI / 2;
    g.add(at(dotsGrid(3, 3, 0.1, 0.13, mat(C.white), mat(C.gold), 4), 0.68, -0.3, 0.06));
    return rot(g, -0.15, 0.1, 0.06);
  },
  saku() {
    const g = G(M(rbox(1.25, 1.7, 0.36, 0.08), mat(C.navy)), M(rbox(1.12, 1.6, 0.3, 0.04), mat(C.cream), 0.07, 0, 0),
      M(rbox(1.27, 0.14, 0.38, 0.03), mat(C.gold), 0, 0.45, 0), M(rbox(1.27, 0.06, 0.38, 0.02), mat(C.gold), 0, 0.3, 0),
      M(rbox(0.16, 0.6, 0.04, 0.02), mat(C.maroon), 0.3, -0.95, 0.15));
    g.add(M(extrude(star(0.2, 0.08), 0.03, 0.01), metal(C.gold), 0, -0.2, 0.2));
    return g;
  },
  medali() {
    const rib = (x, r) => rot(M(rbox(0.34, 1.0, 0.06, 0.03), mat(C.maroon), x, -0.55, -0.14), 0, 0, r);
    const disc = rot(G(M(cyl(0.72, 0.72, 0.16, 64), metal(C.gold)), M(tor(0.72, 0.06), metal(C.goldDeep))), Math.PI / 2, 0, 0);
    disc.children[1].rotation.x = Math.PI / 2;
    const st = M(extrude(star(0.42, 0.18), 0.08, 0.03), mat(C.navy), 0, 0, 0.12);
    return at(G(rib(-0.25, 0.25), rib(0.25, -0.25), disc, st), 0, 0.2, 0);
  },
  pengumuman() {
    // dibangun searah sumbu +X lalu dimiringkan sedikit ke atas
    const cone = rot(M(cyl(0.66, 0.26, 1.25, 48), mat(C.maroon)), 0, 0, -Math.PI / 2);
    const rim = rot(M(tor(0.66, 0.075), metal(C.gold)), 0, Math.PI / 2, 0); at(rim, 0.63, 0, 0);
    const inner = rot(M(cyl(0.6, 0.6, 0.02, 48), mat(C.navyDeep)), 0, 0, -Math.PI / 2); at(inner, 0.6, 0, 0);
    const back = rot(M(cyl(0.3, 0.3, 0.34, 40), mat(C.white)), 0, 0, -Math.PI / 2); at(back, -0.78, 0, 0);
    const handle = at(M(rbox(0.2, 0.62, 0.22, 0.09), mat(C.navy)), -0.32, -0.45, 0);
    const w1 = at(rot(M(tor(0.42, 0.045, 1.1), mat(C.gold)), 0, Math.PI / 2 - 0.3, -0.55), 1.12, 0, 0);
    const w2 = at(rot(M(tor(0.66, 0.045, 1.0), mat(C.gold)), 0, Math.PI / 2 - 0.3, -0.5), 1.32, 0, 0);
    return rot(G(cone, rim, inner, back, handle, w1, w2), 0, 0, 0.22);
  },
  gedung() {
    const g = G(M(rbox(2.0, 0.16, 1.0, 0.04), mat(C.cream), 0, -0.82, 0), M(rbox(1.8, 0.14, 0.9, 0.04), mat(C.white), 0, -0.68, 0),
      M(rbox(1.8, 0.16, 0.9, 0.04), mat(C.white), 0, 0.35, 0));
    [-0.66, -0.22, 0.22, 0.66].forEach((x) => g.add(M(cyl(0.11, 0.12, 0.88, 32), mat(C.cream), x, -0.16, 0.18)));
    const tri = new THREE.Shape(); tri.moveTo(-1.0, 0); tri.lineTo(1.0, 0); tri.lineTo(0, 0.55); tri.closePath();
    g.add(at(M(extrude(tri, 0.75, 0.04), mat(C.navy)), 0, 0.68, 0));
    g.add(M(sph(0.1), metal(C.gold), 0, 0.72, 0.42));
    return g;
  },
  struktur() {
    const n = (c, x, y) => M(rbox(0.62, 0.48, 0.26, 0.14), mat(c), x, y, 0);
    const bar = (x, y, w, h) => M(rbox(w, h, 0.1, 0.04), mat(0xc9cfdc), x, y, -0.05);
    return G(n(C.navy, 0, 0.62), n(C.gold, -0.7, -0.55), n(C.maroon, 0.7, -0.55), bar(0, 0.12, 0.08, 0.5), bar(0, -0.12, 1.48, 0.08), bar(-0.7, -0.24, 0.08, 0.2), bar(0.7, -0.24, 0.08, 0.2));
  },
  anggota() {
    const p = (c, x, z, s) => at(G(M(sph(0.34 * s), mat(c), 0, 0.62 * s, 0), M(cap(0.42 * s, 0.3 * s), mat(c), 0, -0.2 * s, 0)), x, 0, z);
    const back = p(C.gold, 0.5, -0.4, 0.82), front = p(C.navy, -0.2, 0.2, 1);
    const clip = (o) => { o.children[1].scale.y = 0.85; return o; };
    return G(clip(back), clip(front));
  },
  perisai() {
    const s = new THREE.Shape(); s.moveTo(0, 1); s.bezierCurveTo(0.45, 0.82, 0.8, 0.8, 0.85, 0.78); s.bezierCurveTo(0.85, 0.1, 0.6, -0.55, 0, -1); s.bezierCurveTo(-0.6, -0.55, -0.85, 0.1, -0.85, 0.78); s.bezierCurveTo(-0.8, 0.8, -0.45, 0.82, 0, 1);
    const base = M(extrude(s, 0.3, 0.08), mat(C.navy));
    const inner = M(extrude(s, 0.05, 0.02), mat(C.sky)); inner.scale.set(0.78, 0.78, 1); inner.position.z = 0.22;
    const ck = M(extrude(check(), 0.12, 0.03), mat(C.white), 0.02, 0.0, 0.3);
    return G(base, inner, ck);
  },
  lokasi() {
    const pts = []; for (let i = 0; i <= 40; i++) { const t = i / 40, a = -Math.PI / 2 + t * Math.PI * 1.25; pts.push(new THREE.Vector2(Math.max(0, Math.cos(a) * 0.62 * (t < 0.2 ? t / 0.2 : 1)), 0.5 + Math.sin(a) * 0.62)); }
    const shape = []; for (let i = 0; i <= 32; i++) { const t = i / 32; const y = -0.75 + t * 2.0; const r = y < 0.35 ? Math.max(0.0, (y + 0.75) / 1.1) * 0.6 : Math.sqrt(Math.max(0, 0.6 * 0.6 - (y - 0.4) ** 2)); shape.push(new THREE.Vector2(r, y)); }
    const pin = M(new THREE.LatheGeometry(shape, 64), mat(C.maroon));
    const hole = M(sph(0.22), mat(C.white), 0, 0.4, 0.42);
    const base = M(cyl(0.7, 0.7, 0.08, 64), mat(C.gold), 0, -0.8, 0);
    const ring = M(tor(0.5, 0.03), mat(C.goldDeep), 0, -0.75, 0); ring.rotation.x = Math.PI / 2;
    return G(pin, hole, base, ring);
  },
  laporan() {
    const g = G(M(rbox(1.9, 0.14, 1.0, 0.05), mat(C.cream), 0, -0.8, 0));
    [[-0.6, 0.6, C.sky], [0, 1.05, C.navy], [0.6, 1.5, C.gold]].forEach(([x, h, c]) => g.add(M(rbox(0.42, h, 0.42, 0.08), mat(c), x, -0.73 + h / 2, 0)));
    return g;
  },
  dokumen() {
    const g = G(M(rbox(1.4, 1.85, 0.12, 0.08), mat(C.navy)), M(rbox(1.2, 1.55, 0.06, 0.03), mat(C.cream), 0, -0.07, 0.07),
      M(rbox(0.55, 0.22, 0.16, 0.06), metal(C.gold), 0, 0.85, 0.08));
    g.add(lines(4, 0.86, 0, 0.35, 0.11, 0.24, mat(0xb9c0cf)));
    g.add(at(rot(M(extrude(check(), 0.06, 0.02), mat(C.teal)), 0, 0, 0), 0.32, -0.5, 0.14));
    return rot(g, 0, 0, 0.06);
  },
  verifikasi() {
    const s = new THREE.Shape(); const N = 12; for (let i = 0; i <= N * 2; i++) { const a = (i / (N * 2)) * Math.PI * 2, r = i % 2 ? 0.86 : 1; const p = [Math.cos(a) * r, Math.sin(a) * r]; i ? s.lineTo(...p) : s.moveTo(...p); }
    return G(M(extrude(s, 0.26, 0.07), mat(C.sky)), M(extrude(check(), 0.12, 0.03), mat(C.white), 0, 0, 0.22));
  },
  perpanjang() {
    const arc = (c, r) => { const g = G(M(tor(0.72, 0.13, Math.PI * 0.8), mat(c))); const head = M(cyl(0, 0.28, 0.38, 32), mat(c)); const a = Math.PI * 0.8; head.position.set(Math.cos(a) * 0.72, Math.sin(a) * 0.72, 0); head.rotation.z = a; g.add(head); g.rotation.z = r; return g; };
    return G(arc(C.gold, 0.25), arc(C.navy, Math.PI + 0.25));
  },
  lonceng() {
    const pts = [];
    for (let i = 0; i <= 48; i++) {
      const t = i / 48, y = 0.9 - t * 1.5;
      let r;
      if (t < 0.28) r = 0.45 * Math.sin((t / 0.28) * Math.PI / 2);            // kubah atas
      else if (t < 0.8) r = 0.45 + 0.07 * ((t - 0.28) / 0.52);               // badan
      else r = 0.52 + 0.24 * ((t - 0.8) / 0.2) ** 1.6;                       // bibir melebar
      pts.push(new THREE.Vector2(r, y));
    }
    pts.push(new THREE.Vector2(0.7, -0.64), new THREE.Vector2(0.6, -0.66), new THREE.Vector2(0, -0.66));
    const bell = M(new THREE.LatheGeometry(pts, 72), metal(C.gold));
    return G(bell, M(sph(0.16), metal(C.goldDeep), 0, -0.74, 0.08), M(tor(0.11, 0.045), metal(C.goldDeep), 0, 0.98, 0), M(sph(0.2), mat(C.maroon), 0.52, 0.55, 0.3));
  },
  pengaturan() {
    const gear = (R, n, c, z) => { const s = new THREE.Shape(); const N = n * 2; for (let i = 0; i <= N * 2; i++) { const a = (i / (N * 2)) * Math.PI * 2, r = Math.floor(i / 2) % 2 ? R * 0.8 : R; const p = [Math.cos(a) * r, Math.sin(a) * r]; i ? s.lineTo(...p) : s.moveTo(...p); }
      const h = new THREE.Path(); h.absarc(0, 0, R * 0.34, 0, Math.PI * 2, true); s.holes.push(h); return M(extrude(s, 0.22, 0.05), mat(c), 0, 0, z); };
    return G(gear(1, 8, C.navy, 0), at(gear(0.5, 6, C.gold, -0.2), 0.85, -0.7, -0.2));
  },
  profil() {
    const g = G(M(sph(0.42), mat(C.navy), 0, 0.45, 0), M(cap(0.62, 0.2), mat(C.navy), 0, -0.55, 0), M(cyl(0.95, 0.95, 0.1, 64), mat(C.gold), 0, -0.85, 0));
    g.children[1].scale.set(1, 0.7, 0.75); return g;
  },
  riwayat() {
    const face = rot(G(M(cyl(0.9, 0.9, 0.24, 64), mat(C.white)), M(tor(0.9, 0.09), mat(C.navy))), Math.PI / 2, 0, 0);
    face.children[1].rotation.x = Math.PI / 2;
    const h1 = rot(M(rbox(0.1, 0.5, 0.06, 0.03), mat(C.navyDeep), 0, 0.22, 0.16), 0, 0, 0), h2 = at(rot(M(rbox(0.09, 0.38, 0.06, 0.03), mat(C.maroon)), 0, 0, -1.1), 0.16, 0.08, 0.17);
    return G(face, h1, h2, M(sph(0.08), metal(C.gold), 0, 0, 0.19));
  },
  global() {
    const globe = M(sph(0.85), mat(C.sky));
    const r1 = M(tor(0.86, 0.035), mat(C.white)); r1.rotation.x = Math.PI / 2;
    const r2 = M(tor(0.86, 0.035), mat(C.white)); r2.rotation.y = 0.6;
    const r3 = M(tor(0.86, 0.035), mat(C.white)); r3.rotation.y = -0.6;
    const ring = M(tor(1.05, 0.06, Math.PI * 1.2), metal(C.gold)); ring.rotation.z = -Math.PI * 0.1 - Math.PI / 2; ring.rotation.y = 0.3;
    return G(globe, r1, r2, r3, ring);
  },
  beranda() {
    const body = M(rbox(1.4, 1.0, 1.1, 0.08), mat(C.cream), 0, -0.4, 0);
    const tri = new THREE.Shape(); tri.moveTo(-0.95, 0); tri.lineTo(0.95, 0); tri.lineTo(0, 0.75); tri.closePath();
    const roof = at(M(extrude(tri, 1.2, 0.06), mat(C.maroon)), 0, 0.42, 0);
    return G(body, roof, M(rbox(0.38, 0.6, 0.06, 0.05), mat(C.navy), 0, -0.6, 0.56), M(rbox(0.22, 0.4, 0.22, 0.04), mat(C.maroon), 0.45, 0.62, -0.2));
  },
};

export async function render(name, size = 1024) {
  const R = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  R.setSize(size, size); R.setPixelRatio(1); R.outputColorSpace = THREE.SRGBColorSpace; R.toneMapping = THREE.NoToneMapping;
  R.shadowMap.enabled = true; R.shadowMap.type = THREE.PCFSoftShadowMap;
  document.body.appendChild(R.domElement);
  const scene = new THREE.Scene();
  const pm = new THREE.PMREMGenerator(R); scene.environment = pm.fromScene(new RoomEnvironment(R), 0.04).texture;
  const key = new THREE.DirectionalLight(0xffffff, 1.25); key.position.set(-2.5, 5, 4); key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048); key.shadow.radius = 8; key.shadow.camera.left = key.shadow.camera.bottom = -3; key.shadow.camera.right = key.shadow.camera.top = 3;
  scene.add(key, new THREE.HemisphereLight(0xffffff, 0x8899bb, 0.35));
  const obj = B[name](); scene.add(obj);
  // pusatkan & seragamkan ukuran
  const box = new THREE.Box3().setFromObject(obj), c = box.getCenter(new THREE.Vector3()), s = box.getSize(new THREE.Vector3());
  const k = 2.1 / Math.max(s.x, s.y, s.z); obj.scale.setScalar(k); obj.position.sub(c.multiplyScalar(k));
  // putar sedikit ke 3/4 supaya terlihat tebal
  const piv = new THREE.Group(); scene.remove(obj); piv.add(obj); scene.add(piv); piv.rotation.set(0.32, -0.42, 0);
  const b2 = new THREE.Box3().setFromObject(piv);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(10, 10), new THREE.ShadowMaterial({ opacity: 0.13 })); floor.rotation.x = -Math.PI / 2; floor.position.y = b2.min.y - 0.02; floor.receiveShadow = true; scene.add(floor);
  const cam = new THREE.PerspectiveCamera(26, 1, 0.1, 50); cam.position.set(0, 0.35, 8.3); cam.lookAt(0, -0.05, 0);
  R.render(scene, cam);
  const url = R.domElement.toDataURL("image/png");
  R.dispose(); R.domElement.remove();
  return url;
}
export const names = Object.keys(B);

// Generates the helmet visor overlays used by VisorClient (PNG with alpha, 1280x720):
//   frame - out-of-focus helmet rim around a wide visor, inner rim highlight,
//           one curved glare, faint smudges, hairline scratches, dust specks
//   fog   - breath condensation: patchy haze at the bottom with small droplets
//   dust  - Mars dust on the glass: fine reddish grain, specks and streaks
// Usage: node scripts/visor-texture.mjs <outDir>   (writes visor-frame.png, visor-fog.png, visor-dust.png)
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { deflateSync } from "node:zlib";

const W = 1280;
const H = 720;

// Deterministic random so the textures are the same every run.
let seed = 1337;
const rand = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
const smooth = (a, b, x) => {
	const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
	return t * t * (3 - 2 * t);
};

// Value noise + fractal sum, for patchy fog and dust.
const LAT = 256;
const lattice = new Float32Array(LAT * LAT).map(() => rand());
const lat = (x, y) => lattice[(((y % LAT) + LAT) % LAT) * LAT + (((x % LAT) + LAT) % LAT)];
function noise(x, y) {
	const xi = Math.floor(x);
	const yi = Math.floor(y);
	const fx = x - xi;
	const fy = y - yi;
	const sx = fx * fx * (3 - 2 * fx);
	const sy = fy * fy * (3 - 2 * fy);
	const a = lat(xi, yi) + (lat(xi + 1, yi) - lat(xi, yi)) * sx;
	const b = lat(xi, yi + 1) + (lat(xi + 1, yi + 1) - lat(xi, yi + 1)) * sx;
	return a + (b - a) * sy;
}
const fbm = (x, y, oct = 5) => {
	let s = 0;
	let amp = 0.5;
	let f = 1;
	for (let i = 0; i < oct; i++) {
		s += noise(x * f, y * f) * amp;
		amp *= 0.5;
		f *= 2;
	}
	return s;
};

function canvas() {
	const px = new Float32Array(W * H * 4);
	const blend = (i, r, g, b, a) => {
		if (a <= 0) return;
		a = Math.min(1, a);
		const k = i * 4;
		const da = px[k + 3];
		const oa = a + da * (1 - a);
		px[k] = (r * a + px[k] * da * (1 - a)) / oa;
		px[k + 1] = (g * a + px[k + 1] * da * (1 - a)) / oa;
		px[k + 2] = (b * a + px[k + 2] * da * (1 - a)) / oa;
		px[k + 3] = oa;
	};
	const dot = (cx, cy, r, color, a) => {
		for (let y = Math.floor(cy - r); y <= cy + r; y++) {
			for (let x = Math.floor(cx - r); x <= cx + r; x++) {
				if (x < 0 || y < 0 || x >= W || y >= H) continue;
				const t = 1 - Math.hypot(x - cx, y - cy) / r;
				if (t > 0) blend(y * W + x, color[0], color[1], color[2], a * Math.min(1, t * 2));
			}
		}
	};
	return { px, blend, dot };
}

// Visor opening: a superellipse a little above centre, so the chin rim is thicker.
const CX = W / 2;
const CY = H * 0.46;
const AX = W * 0.5;
const AY = H * 0.47;
const N = 3.4;
const visor = (x, y) => (Math.abs((x - CX) / AX) ** N + Math.abs((y - CY) / AY) ** N) ** (1 / N);

function frame() {
	const { px, blend, dot } = canvas();
	for (let y = 0; y < H; y++) {
		for (let x = 0; x < W; x++) {
			const i = y * W + x;
			const s = visor(x, y);
			// Out-of-focus rim: wide soft falloff into a dark shell.
			const rim = smooth(0.9, 1.08, s);
			const shade = 0.07 + 0.05 * fbm(x / 90, y / 90, 3); // a little uneven, like a real shell
			blend(i, shade, shade + 0.01, shade + 0.03, rim * 0.95);
			// Soft inner shadow just inside the opening.
			blend(i, 0.03, 0.04, 0.06, smooth(0.72, 0.98, s) * (1 - rim) * 0.32);
			// Light catching the inner edge of the glass (brighter at the top left).
			const edge = Math.exp(-(((s - 0.93) / 0.012) ** 2));
			const light = 0.5 + 0.5 * smooth(H, 0, y) * smooth(W, 0, x * 0.8);
			blend(i, 0.92, 0.95, 1, edge * 0.22 * light);
			// One curved glare across the upper glass.
			const g = Math.hypot((x - CX) / (W * 0.62), (y - H * 0.95) / (H * 1.0));
			const glare = Math.exp(-(((g - 0.83) / 0.01) ** 2)) * 0.1 + Math.exp(-(((g - 0.8) / 0.045) ** 2)) * 0.035;
			blend(i, 1, 1, 1, glare * smooth(H * 0.45, H * 0.05, y) * (1 - rim));
		}
	}
	// Faint smudges.
	for (let s = 0; s < 14; s++) {
		const cx = rand() * W;
		const cy = rand() * H;
		const r = 60 + rand() * 160;
		const a = 0.01 + rand() * 0.018;
		for (let y = Math.max(0, cy - r) | 0; y < Math.min(H, cy + r); y++) {
			for (let x = Math.max(0, cx - r) | 0; x < Math.min(W, cx + r); x++) {
				const t = 1 - Math.hypot(x - cx, y - cy) / r;
				if (t > 0 && visor(x, y) < 0.95) blend(y * W + x, 0.9, 0.93, 0.96, a * t * t);
			}
		}
	}
	// Hairline scratches, more towards the rim.
	for (let s = 0; s < 80; s++) {
		const x = rand() * W;
		const y = rand() * H;
		if (visor(x, y) > 0.92 || rand() > 0.25 + smooth(0.3, 0.9, visor(x, y))) continue;
		const len = 20 + rand() * 110;
		const ang = rand() * Math.PI;
		const a = 0.03 + rand() * 0.05;
		for (let t = 0; t < len; t++) {
			const ix = Math.round(x + Math.cos(ang) * t);
			const iy = Math.round(y + Math.sin(ang) * t);
			if (ix >= 0 && iy >= 0 && ix < W && iy < H) blend(iy * W + ix, 1, 1, 1, a * Math.sin((t / len) * Math.PI));
		}
	}
	for (let s = 0; s < 90; s++) dot(rand() * W, rand() * H, 0.8 + rand() * 1.6, [0.95, 0.9, 0.85], 0.05 + rand() * 0.07);
	return px;
}

function fog() {
	const { px, blend, dot } = canvas();
	for (let y = 0; y < H; y++) {
		for (let x = 0; x < W; x++) {
			// Strongest at the bottom centre (where the breath hits) and the lower corners.
			const mouth = Math.exp(-(((x - CX) / (W * 0.3)) ** 2) - (((y - H) / (H * 0.42)) ** 2));
			const corners = smooth(0.75, 1.0, visor(x, y)) * smooth(H * 0.35, H, y);
			const patches = smooth(0.35, 0.75, fbm(x / 140, y / 140));
			const a = Math.min(1, mouth * 0.9 + corners * 0.5) * (0.35 + 0.65 * patches);
			blend(y * W + x, 0.92, 0.94, 0.96, a * 0.75);
		}
	}
	// Condensation droplets in the misted area: a dark rim with a bright spot.
	for (let s = 0; s < 260; s++) {
		const x = CX + (rand() - 0.5) * W * 0.95;
		const y = H * (0.55 + rand() * 0.45);
		const mist = Math.exp(-(((x - CX) / (W * 0.32)) ** 2) - (((y - H) / (H * 0.45)) ** 2));
		if (rand() > mist + 0.15) continue;
		const r = 1.5 + rand() * 4.5;
		dot(x, y, r, [0.55, 0.6, 0.66], 0.35);
		dot(x - r * 0.3, y - r * 0.3, r * 0.4, [1, 1, 1], 0.6);
	}
	return px;
}

function dust() {
	const { px, blend, dot } = canvas();
	for (let y = 0; y < H; y++) {
		for (let x = 0; x < W; x++) {
			// Patchy fine grain, heavier towards the rim and the bottom.
			const grain = fbm(x / 6, y / 6, 2);
			const patch = smooth(0.3, 0.8, fbm(x / 220 + 7, y / 220 + 3));
			const where = 0.45 + 0.55 * smooth(0.4, 1.0, visor(x, y)) + 0.25 * smooth(H * 0.5, H, y);
			const a = smooth(0.42, 0.72, grain) * patch * where;
			blend(y * W + x, 0.62, 0.36, 0.22, a * 0.55);
		}
	}
	// Specks and a few dragged streaks.
	for (let s = 0; s < 700; s++) dot(rand() * W, rand() * H, 0.7 + rand() * 2.4, [0.55, 0.32, 0.2], 0.25 + rand() * 0.35);
	for (let s = 0; s < 40; s++) {
		const x = rand() * W;
		const y = rand() * H;
		const len = 30 + rand() * 120;
		const ang = Math.PI * (0.35 + rand() * 0.3);
		for (let t = 0; t < len; t++) {
			dot(x + Math.cos(ang) * t, y + Math.sin(ang) * t, 1.2, [0.6, 0.36, 0.22], 0.08 * Math.sin((t / len) * Math.PI));
		}
	}
	return px;
}

// --- PNG encoding (RGBA8, no dependencies) ---
const crcTable = new Uint32Array(256).map((_, n) => {
	let c = n;
	for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
	return c >>> 0;
});
const crc32 = (buf) => {
	let c = 0xffffffff;
	for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
	return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length);
	const td = Buffer.concat([Buffer.from(type), data]);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(crc32(td));
	return Buffer.concat([len, td, crc]);
};
function png(px) {
	const raw = Buffer.alloc((W * 4 + 1) * H);
	for (let y = 0; y < H; y++) {
		raw[y * (W * 4 + 1)] = 0;
		for (let x = 0; x < W; x++) {
			const k = (y * W + x) * 4;
			const o = y * (W * 4 + 1) + 1 + x * 4;
			for (let c = 0; c < 3; c++) raw[o + c] = Math.round(Math.min(1, px[k + c]) * 255);
			raw[o + 3] = Math.round(Math.min(1, px[k + 3]) * 255);
		}
	}
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(W, 0);
	ihdr.writeUInt32BE(H, 4);
	ihdr[8] = 8;
	ihdr[9] = 6;
	return Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk("IHDR", ihdr),
		chunk("IDAT", deflateSync(raw, { level: 9 })),
		chunk("IEND", Buffer.alloc(0)),
	]);
}

const outDir = process.argv[2] ?? ".";
for (const [name, make] of [
	["visor-frame.png", frame],
	["visor-fog.png", fog],
	["visor-dust.png", dust],
]) {
	const file = join(outDir, name);
	const data = png(make());
	writeFileSync(file, data);
	console.log(`${file}: ${data.length} bytes`);
}

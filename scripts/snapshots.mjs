// Fetches curated NASA data snapshots into src/server/data/<name>.json.
// Usage: node --use-system-ca scripts/snapshots.mjs <name|all>
// Sources and checks: kb/data/nasa-sources.md. Each snapshot = { header, rows }.
import { writeFileSync, mkdirSync } from "node:fs";

const OUT = new URL("../src/server/data/", import.meta.url);

async function getJson(url) {
	const res = await fetch(url);
	if (!res.ok) throw new Error(`${res.status} ${url}`);
	return res.json();
}

async function getText(url) {
	const res = await fetch(url);
	if (!res.ok) throw new Error(`${res.status} ${url}`);
	return res.text();
}

const snapshots = {
	// Curiosity REMS weather around the 2018 global dust storm.
	async "rems-2018"() {
		const url = "https://mars.nasa.gov/rss/api/?feed=weather&category=msl&feedtype=json";
		const data = await getJson(url);
		const rows = data.soles
			.filter((s) => s.terrestrial_date >= "2018-05-01" && s.terrestrial_date <= "2018-09-30")
			.map((s) => ({
				date: s.terrestrial_date,
				sol: Number(s.sol),
				minTemp: s.min_temp === "--" ? null : Number(s.min_temp),
				maxTemp: s.max_temp === "--" ? null : Number(s.max_temp),
				pressure: s.pressure === "--" ? null : Number(s.pressure),
				uv: s.local_uv_irradiance_index,
			}))
			.sort((a, b) => a.sol - b.sol);
		return {
			header: {
				source: "Curiosity REMS",
				url,
				credit: "Centro de Astrobiología (CAB) / NASA JPL-Caltech",
				notes: "Outreach data only (CAB disclaimer). Temperatures in °C, pressure in Pa.",
			},
			rows,
		};
	},

	// Curiosity REMS: the latest 60 sols that have temperatures (cold nights).
	async "rems-recent"() {
		const url = "https://mars.nasa.gov/rss/api/?feed=weather&category=msl&feedtype=json";
		const data = await getJson(url);
		const rows = data.soles
			.filter((s) => s.min_temp !== "--" && s.max_temp !== "--")
			.map((s) => ({
				date: s.terrestrial_date,
				sol: Number(s.sol),
				minTemp: Number(s.min_temp),
				maxTemp: Number(s.max_temp),
				pressure: s.pressure === "--" ? null : Number(s.pressure),
				uv: s.local_uv_irradiance_index,
			}))
			.sort((a, b) => b.sol - a.sol)
			.slice(0, 60)
			.reverse();
		return {
			header: {
				source: "Curiosity REMS",
				url,
				credit: "Centro de Astrobiología (CAB) / NASA JPL-Caltech",
				notes: "Outreach data only (CAB disclaimer). Temperatures in °C, pressure in Pa.",
			},
			rows,
		};
	},

	// Curiosity RAD dose rate on the Mars surface around the 20 May 2024 solar storm.
	async "radlab-2024-05"() {
		const url =
			"https://visualization.osdr.nasa.gov/radlab/api/?instrument_id=MSL-RAD-Surface" +
			"&timestamp>=2024-05-10&timestamp<2024-06-01&absorbed_dose_rate&format=csv";
		const csv = await getText(url);
		const rows = csv
			.trim()
			.split("\n")
			.slice(1)
			.map((line) => {
				const [time, , rate] = line.split(",");
				return { time: time.replaceAll('"', ""), doseRate: Number(rate) };
			})
			.filter((r) => Number.isFinite(r.doseRate))
			.sort((a, b) => (a.time < b.time ? -1 : 1));
		return {
			header: {
				source: "Curiosity RAD",
				url,
				credit: "NASA OSDR RadLab",
				notes: "absorbed_dose_rate; microgray per hour (μGy/h), absorbed dose; see kb/data/nasa-sources.md.",
			},
			rows,
		};
	},

	// DONKI solar flares of the last 60 days (fallback for the live fetch in Donki.luau).
	async "donki-flr"() {
		const url = `https://ccmc.gsfc.nasa.gov/DONKI-API/get/FLR?startDate=${daysAgo(60)}&endDate=${daysAgo(0)}`;
		const data = await getJson(url);
		const rows = data.map((f) => ({ peakTime: f.peakTime, classType: f.classType, link: f.link }));
		return {
			header: { source: "NASA DONKI", url, credit: "NASA CCMC", notes: "Solar flares (FLR)." },
			rows,
		};
	},

	// DONKI WSA-ENLIL model runs that forecast a CME reaching Mars (last 60 days).
	async "donki-enlil-mars"() {
		const url = `https://ccmc.gsfc.nasa.gov/DONKI-API/get/WSAEnlilSimulations?startDate=${daysAgo(60)}&endDate=${daysAgo(0)}`;
		const data = await getJson(url);
		const rows = [];
		for (const sim of data) {
			const hit = (sim.impactList ?? []).find((i) => i.location === "Mars");
			const cme = (sim.cmeInputs ?? [])[0];
			if (!hit || !cme) continue;
			rows.push({
				simulationID: sim.simulationID,
				modelCompletionTime: sim.modelCompletionTime,
				cmeStartTime: cme.cmeStartTime,
				speed: cme.speed,
				arrivalTime: hit.arrivalTime,
				link: sim.link,
			});
		}
		return {
			header: {
				source: "NASA DONKI WSA-ENLIL",
				url,
				credit: "NASA CCMC",
				notes: "Model forecast, not a measurement. Speed in km/s.",
			},
			rows,
		};
	},
};

function daysAgo(days) {
	return new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
}

async function run(name) {
	const make = snapshots[name];
	if (!make) throw new Error(`unknown snapshot "${name}"; known: ${Object.keys(snapshots).join(", ")}`);
	const { header, rows } = await make();
	const out = { header: { ...header, retrievedAt: new Date().toISOString().slice(0, 10) }, rows };
	mkdirSync(OUT, { recursive: true });
	writeFileSync(new URL(`${name}.json`, OUT), JSON.stringify(out, null, "\t") + "\n");
	console.log(`${name}: ${rows.length} rows`);
}

const arg = process.argv[2];
if (!arg) {
	console.error("usage: node --use-system-ca scripts/snapshots.mjs <name|all>");
	process.exit(1);
}
for (const name of arg === "all" ? Object.keys(snapshots) : [arg]) await run(name);

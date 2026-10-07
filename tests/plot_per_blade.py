#!/usr/bin/env python3
"""Plot per-blade torque vs azimuth for baseline/offset/phased runs.
Generates PNGs in tests/results/plots/per_blade_<run>.png
"""
import matplotlib.pyplot as plt
from pathlib import Path

RUN_DIRS = {
	'baseline': Path('tests/baseline_run/torque_vs_azimuth.dat'),
	'offset': Path('tests/offset_run/torque_vs_azimuth.dat'),
	'phased': Path('tests/phased_run/torque_vs_azimuth.dat')
}

OUT_DIR = Path('tests') / 'results' / 'plots'
OUT_DIR.mkdir(parents=True, exist_ok=True)

for name, path in RUN_DIRS.items():
	if not path.exists():
		print(f"Skipping {name}: {path} not found")
		continue
	az = []
	total = []
	b1 = []
	b2 = []
	b3 = []
	with open(path, 'r', encoding='utf-8') as f:
		for line in f:
			if line.strip() == '':
				continue
			if line.lstrip().startswith('#'):
				continue
			# try to parse floats from the line
			parts = line.strip().split()
			if len(parts) < 5:
				# try comma separated
				parts = line.strip().split(',')
			try:
				a = float(parts[0])
				t = float(parts[1])
				tb1 = float(parts[2])
				tb2 = float(parts[3])
				tb3 = float(parts[4])
			except Exception:
				continue
			az.append(a)
			total.append(t)
			b1.append(tb1)
			b2.append(tb2)
			b3.append(tb3)
	if not az:
		print(f"No numeric data found in {path}")
		continue
	plt.figure(figsize=(10,5))
	plt.plot(az, total, label='total', linewidth=2)
	plt.plot(az, b1, label='blade1')
	plt.plot(az, b2, label='blade2')
	plt.plot(az, b3, label='blade3')
	plt.xlabel('Azimuth (deg)')
	plt.ylabel('Torque (Nm)')
	plt.title(f'Per-blade Torque vs Azimuth: {name}')
	plt.grid(True)
	plt.legend()
	out = OUT_DIR / f'per_blade_{name}.png'
	plt.savefig(out, dpi=150)
	plt.close()
	print(f'Wrote {out}')

print('Done')

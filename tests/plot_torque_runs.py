#!/usr/bin/env python3
"""Plot torque vs azimuth for baseline, offset, and phased runs.
Generates PNGs in tests/results/plots.
"""
import matplotlib.pyplot as plt
import csv
from pathlib import Path

RUNS = {
	'baseline': Path('tests/baseline_run/torque_vs_azimuth.csv'),
	'offset': Path('tests/offset_run/torque_vs_azimuth.csv'),
	'phased': Path('tests/phased_run/torque_vs_azimuth.csv')
}

OUT_DIR = Path('tests') / 'results' / 'plots'
OUT_DIR.mkdir(parents=True, exist_ok=True)

for name, path in RUNS.items():
	if not path.exists():
		print(f"Skipping {name}: {path} not found")
		continue
	az = []
	tor = []
	with open(path, 'r', encoding='utf-8') as f:
		next(f)
		for line in f:
			a, t = line.strip().split(',')
			az.append(float(a))
			tor.append(float(t))
	plt.figure(figsize=(8,4))
	plt.plot(az, tor, label=name)
	plt.xlabel('Azimuth (deg)')
	plt.ylabel('Torque (Nm)')
	plt.title(f'Torque vs Azimuth: {name}')
	plt.grid(True)
	plt.legend()
	out = OUT_DIR / f'torque_{name}.png'
	plt.savefig(out, dpi=150)
	plt.close()
	print(f'Wrote {out}')

# Combined plot
plt.figure(figsize=(10,5))
for name, path in RUNS.items():
	if not path.exists():
		continue
	az = []
	tor = []
	with open(path, 'r', encoding='utf-8') as f:
		next(f)
		for line in f:
			a, t = line.strip().split(',')
			az.append(float(a))
			tor.append(float(t))
	plt.plot(az, tor, label=name)
plt.xlabel('Azimuth (deg)')
plt.ylabel('Torque (Nm)')
plt.title('Torque vs Azimuth: baseline vs offset vs phased')
plt.grid(True)
plt.legend()
out = OUT_DIR / 'torque_combined.png'
plt.savefig(out, dpi=150)
print(f'Wrote {out}')

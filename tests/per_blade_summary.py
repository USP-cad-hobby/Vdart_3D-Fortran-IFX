#!/usr/bin/env python3
"""Compute numeric per-blade torque summaries for baseline/offset/phased runs.
Writes tests/results/per_blade_summary.txt
"""
import csv
from pathlib import Path

RUNS = {
	'baseline': Path('tests/baseline_run/torque_vs_azimuth.dat'),
	'offset': Path('tests/offset_run/torque_vs_azimuth.dat'),
	'phased': Path('tests/phased_run/torque_vs_azimuth.dat')
}
OUT = Path('tests') / 'results' / 'per_blade_summary.txt'
OUT.parent.mkdir(parents=True, exist_ok=True)

def read_rows(path):
	az = []
	total = []
	b = [[], [], []]
	if not path.exists():
		return None
	with open(path, 'r', encoding='utf-8') as f:
		for line in f:
			if line.strip() == '' or line.lstrip().startswith('#'):
				continue
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
			b[0].append(tb1)
			b[1].append(tb2)
			b[2].append(tb3)
	return {'az': az, 'total': total, 'blades': b}

from statistics import mean

with open(OUT,'w',encoding='utf-8') as out:
	out.write('Per-blade torque summary\n')
	out.write('========================\n\n')
	for name,path in RUNS.items():
		data = read_rows(path)
		if data is None:
			out.write(f'{name}: no data file at {path}\n\n')
			continue
		total = data['total']
		blades = data['blades']
		out.write(f'Run: {name}\n')
		out.write(f'  Samples: {len(total)}\n')
		out.write(f'  Mean total torque: {mean(total):.2f} Nm\n')
		for i in range(3):
			bi = blades[i]
			out.write(f'  Blade {i+1}: mean={mean(bi):.2f} Nm, min={min(bi):.2f}, max={max(bi):.2f}, contribution_mean={mean(bi)/mean(total)*100.0:.2f}%\n')
		out.write('\n')

print('Wrote', OUT)

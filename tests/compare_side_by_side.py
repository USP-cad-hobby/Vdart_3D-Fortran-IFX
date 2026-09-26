#!/usr/bin/env python3
"""Create a combined baseline vs offset summary and delta file.
Produces tests/results/combined_comparison.txt and tests/results/combined_torque_delta.csv
"""
import re
import csv
from pathlib import Path

def read_summary(path):
	data = {}
	with open(path, 'r', encoding='utf-8') as f:
		for line in f:
			if 'Mean torque reported' in line:
				m = re.findall(r"([-+]?[0-9]*\.?[0-9]+)", line)
				if m:
					data['mean_torque_reported'] = float(m[-1])
			if 'CP reported' in line:
				m = re.findall(r"([-+]?[0-9]*\.?[0-9]+)", line)
				if m:
					data['cp_reported'] = float(m[-1])
			if 'Mean torque difference' in line:
				m = re.findall(r"([-+]?[0-9]*\.?[0-9]+)", line)
				if m:
					data['mean_diff'] = float(m[0])
			if 'CP difference' in line:
				m = re.findall(r"([-+]?[0-9]*\.?[0-9]+)", line)
				if m:
					data['cp_diff'] = float(m[0])
	return data

results_dir = Path('tests') / 'results'
results_dir.mkdir(parents=True, exist_ok=True)

base = read_summary('tests/baseline_run/compare_summary.txt')
off = read_summary('tests/offset_run/compare_summary.txt')

combined_path = results_dir / 'combined_comparison.txt'
with open(combined_path, 'w', encoding='utf-8') as f:
	f.write('Baseline vs Offset Combined Summary\n')
	f.write('=================================\n')
	f.write(f"Baseline mean torque reported: {base.get('mean_torque_reported', 'N/A')} Nm\n")
	f.write(f"Baseline CP reported: {base.get('cp_reported', 'N/A')}\n")
	f.write('\n')
	f.write(f"Offset mean torque reported: {off.get('mean_torque_reported', 'N/A')} Nm\n")
	f.write(f"Offset CP reported: {off.get('cp_reported', 'N/A')}\n")
	f.write('\n')
	if 'mean_torque_reported' in base and 'mean_torque_reported' in off:
		mean_diff = off['mean_torque_reported'] - base['mean_torque_reported']
		pct = mean_diff / base['mean_torque_reported'] * 100.0
		f.write(f"Delta mean torque (offset - baseline): {mean_diff:.2f} Nm ({pct:.2f}%)\n")
	if 'cp_reported' in base and 'cp_reported' in off:
		cp_diff = off['cp_reported'] - base['cp_reported']
		pct_cp = cp_diff / base['cp_reported'] * 100.0
		f.write(f"Delta CP (offset - baseline): {cp_diff:.5f} ({pct_cp:.2f}%)\n")

# Also build a CSV of torque deltas by azimuth from the two runs if files exist
base_csv = Path('tests/baseline_run/torque_vs_azimuth.csv')
off_csv = Path('tests/offset_run/torque_vs_azimuth.csv')
if base_csv.exists() and off_csv.exists():
	base_rows = {}
	with open(base_csv, 'r', encoding='utf-8') as f:
		next(f)
		for line in f:
			az, t = line.strip().split(',')
			base_rows[float(az)] = float(t)
	with open(off_csv, 'r', encoding='utf-8') as f:
		next(f)
		off_rows = [(float(line.split(',')[0]), float(line.split(',')[1])) for line in f]
	csv_out = results_dir / 'combined_torque_delta.csv'
	with open(csv_out, 'w', newline='', encoding='utf-8') as out:
		writer = csv.writer(out)
		writer.writerow(['azimuth_deg','torque_baseline_Nm','torque_offset_Nm','delta_Nm','delta_pct'])
		for az, off_t in off_rows:
			base_t = base_rows.get(az, None)
			if base_t is None: continue
			delta = off_t - base_t
			pct = delta / base_t * 100.0 if base_t != 0 else None
			writer.writerow([f"{az:.6f}", f"{base_t:.6f}", f"{off_t:.6f}", f"{delta:.6f}", f"{pct:.6f}" if pct is not None else ''])

print('Combined summary and torque delta CSV written to tests/results')

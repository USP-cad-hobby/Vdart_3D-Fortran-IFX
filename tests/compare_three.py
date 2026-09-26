#!/usr/bin/env python3
"""Aggregate baseline, offset, and phased runs into a combined summary and per-azimuth CSV.
Produces tests/results/combined_three_comparison.txt and tests/results/combined_three_torque.csv
"""
import re
import csv
from pathlib import Path

RUNS = {
	'baseline': Path('tests/baseline_run'),
	'offset': Path('tests/offset_run'),
	'phased': Path('tests/phased_run')
}

RESULTS_DIR = Path('tests') / 'results'
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

float_re = re.compile(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?')

def read_summary(path):
	data = {}
	if not path.exists():
		return data
	with open(path, 'r', encoding='utf-8') as f:
		for line in f:
			if 'Mean torque reported' in line:
				m = float_re.findall(line)
				if m:
					data['mean_torque_reported'] = float(m[-1])
			if 'CP reported' in line:
				m = float_re.findall(line)
				if m:
					data['cp_reported'] = float(m[-1])
	return data


def read_torque_csv(path):
	rows = {}
	if not path.exists():
		return rows
	with open(path, 'r', encoding='utf-8') as f:
		header = f.readline()
		for line in f:
			parts = line.strip().split(',')
			if len(parts) >= 2:
				az = float(parts[0])
				torque = float(parts[1])
				rows[az] = torque
	return rows


def main():
	summaries = {}
	torques = {}
	for name, p in RUNS.items():
		summaries[name] = read_summary(p / 'compare_summary.txt')
		torques[name] = read_torque_csv(p / 'torque_vs_azimuth.csv')

	# Write combined textual summary
	out_txt = RESULTS_DIR / 'combined_three_comparison.txt'
	with open(out_txt, 'w', encoding='utf-8') as f:
		f.write('Baseline vs Offset vs Phased Combined Summary\n')
		f.write('===========================================\n\n')
		for name in ['baseline', 'offset', 'phased']:
			s = summaries.get(name, {})
			f.write(f"{name.capitalize()} mean torque reported: {s.get('mean_torque_reported','N/A')} Nm\n")
			f.write(f"{name.capitalize()} CP reported: {s.get('cp_reported','N/A')}\n\n")

		# compute pairwise deltas
		b = summaries.get('baseline', {})
		o = summaries.get('offset', {})
		p = summaries.get('phased', {})
		if 'mean_torque_reported' in b and 'mean_torque_reported' in o:
			md = o['mean_torque_reported'] - b['mean_torque_reported']
			pct = md / b['mean_torque_reported'] * 100.0
			f.write(f"Offset - Baseline: {md:.2f} Nm ({pct:.2f}%)\n")
		if 'mean_torque_reported' in b and 'mean_torque_reported' in p:
			md = p['mean_torque_reported'] - b['mean_torque_reported']
			pct = md / b['mean_torque_reported'] * 100.0
			f.write(f"Phased - Baseline: {md:.2f} Nm ({pct:.2f}%)\n")
		if 'mean_torque_reported' in o and 'mean_torque_reported' in p:
			md = p['mean_torque_reported'] - o['mean_torque_reported']
			pct = md / o['mean_torque_reported'] * 100.0
			f.write(f"Phased - Offset: {md:.2f} Nm ({pct:.2f}%)\n")

	# Build per-azimuth CSV with baseline, offset, phased and deltas
	csv_out = RESULTS_DIR / 'combined_three_torque.csv'
	azs = sorted(set().union(*(set(t.keys()) for t in torques.values())))
	with open(csv_out, 'w', newline='', encoding='utf-8') as out:
		writer = csv.writer(out)
		writer.writerow(['azimuth_deg','torque_baseline_Nm','torque_offset_Nm','torque_phased_Nm','delta_off_minus_base_Nm','delta_phased_minus_base_Nm'])
		for az in azs:
			b_t = torques['baseline'].get(az,'')
			o_t = torques['offset'].get(az,'')
			p_t = torques['phased'].get(az,'')
			d1 = ''
			d2 = ''
			try:
				if b_t != '' and o_t != '': d1 = o_t - b_t
			except Exception:
				d1 = ''
			try:
				if b_t != '' and p_t != '': d2 = p_t - b_t
			except Exception:
				d2 = ''
			writer.writerow([f"{az:.6f}", b_t if b_t!='' else '', o_t if o_t!='' else '', p_t if p_t!='' else '', f"{d1:.6f}" if d1!='' else '', f"{d2:.6f}" if d2!='' else ''])

	print('Combined three-way summary and CSV written to tests/results')

if __name__ == '__main__':
	main()

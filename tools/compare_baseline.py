#!/usr/bin/env python3
"""Simple comparator for torque_vs_azimuth.dat and run output.
Writes torque_vs_azimuth.csv and prints summary vs legacy baseline.
"""
import re
import sys
from statistics import mean

TORQUE_FILE = 'torque_vs_azimuth.dat'
OUTPUT_CSV = 'torque_vs_azimuth.csv'
OUTPUT_SUMMARY = 'compare_summary.txt'
OUTPUT_RUN = 'output_run.txt'

# Legacy baseline (from result.dat)
BASELINE_CP = 0.14011
BASELINE_TORQUE = 555757.75  # Nm

float_re = re.compile(r'[-+]?\d*\.\d+(?:[eE][-+]?\d+)?|[-+]?\d+(?:[eE][-+]?\d+)?')

def parse_torque_file(path):
	rows = []
	try:
		with open(path, 'r', encoding='utf-8') as f:
			for line in f:
				# find all floats in the line
				nums = float_re.findall(line)
				if len(nums) >= 2:
					az = float(nums[0])
					torque = float(nums[1])
					rows.append((az, torque))
	except FileNotFoundError:
		return None
	return rows


def parse_run_summary(path):
	cp = None
	mean_torque = None
	# Some run outputs are written in UTF-16 (Windows). Try utf-8 first,
	# then fall back to utf-16 if decoding fails.
	encodings = ['utf-8', 'utf-16', 'latin-1']
	for enc in encodings:
		try:
			with open(path, 'r', encoding=enc) as f:
				for line in f:
					if 'Power coefficient (CP):' in line:
						m = float_re.findall(line)
						if m:
							cp = float(m[-1])
					if 'Mean torque:' in line:
						m = float_re.findall(line)
						if m:
							mean_torque = float(m[-1])
			break
		except FileNotFoundError:
			return (None, None)
		except UnicodeDecodeError:
			# try next encoding
			continue
	return (cp, mean_torque)


def save_csv(rows, path):
	with open(path, 'w', encoding='utf-8') as f:
		f.write('azimuth_deg,torque_Nm\n')
		for az, t in rows:
			f.write(f'{az:.6f},{t:.6f}\n')


def main():
	rows = parse_torque_file(TORQUE_FILE)
	if not rows:
		print(f'No torque data found in {TORQUE_FILE}')
		sys.exit(1)

	save_csv(rows, OUTPUT_CSV)

	torques = [t for (_, t) in rows]
	azs = [a for (a, _) in rows]

	cp, mean_torque_reported = parse_run_summary(OUTPUT_RUN)

	s = []
	s.append('Comparison summary')
	s.append('==================')
	s.append(f'Rows parsed from {TORQUE_FILE}: {len(rows)}')
	s.append(f'Torque CSV written: {OUTPUT_CSV}')
	s.append('')

	s.append('Torque statistics (from file)')
	s.append(f'  mean    = {mean(torques):.2f} Nm')
	s.append(f'  min     = {min(torques):.2f} Nm')
	s.append(f'  max     = {max(torques):.2f} Nm')
	s.append('')

	if mean_torque_reported is not None:
		s.append(f'Mean torque reported in run output: {mean_torque_reported:.2f} Nm')
	if cp is not None:
		s.append(f'CP reported in run output: {cp:.5f}')
	s.append('')

	s.append('Legacy baseline (from result.dat)')
	s.append(f'  CP baseline      = {BASELINE_CP:.5f}')
	s.append(f'  Torque baseline  = {BASELINE_TORQUE:.2f} Nm')
	s.append('')

	# compare
	mean_file = mean(torques)
	diff_torque = mean_file - BASELINE_TORQUE
	pct = diff_torque / BASELINE_TORQUE * 100.0
	s.append('Comparison vs baseline:')
	s.append(f'  Mean torque difference = {diff_torque:.2f} Nm ({pct:.2f}%)')
	if cp is not None:
		diff_cp = cp - BASELINE_CP
		pct_cp = diff_cp / BASELINE_CP * 100.0
		s.append(f'  CP difference = {diff_cp:.5f} ({pct_cp:.2f}%)')

	# write summary file and print
	with open(OUTPUT_SUMMARY, 'w', encoding='utf-8') as f:
		f.write('\n'.join(s) + '\n')

	print('\n'.join(s))
	print(f'\nSummary also written to {OUTPUT_SUMMARY}')

if __name__ == '__main__':
	main()

#!/usr/bin/env python3
"""Plot torque vs azimuth for baseline, offset, and phased runs.
Generates PNGs in tests/results/plots.

Behaviour:
- If per-run files exist under tests/*_run/ the script plots those.
- Otherwise, it will try to read tests/results/combined_three_torque.csv and plot the three series found there.
- If azimuth values are in revolutions (0..1) they are converted to degrees.
"""
import matplotlib.pyplot as plt
import csv
from pathlib import Path

RUNS = {
	'baseline': Path('tests/baseline_run/torque_vs_azimuth.csv'),
	'offset': Path('tests/offset_run/torque_vs_azimuth.csv'),
	'phased': Path('tests/phased_run/torque_vs_azimuth.csv')
}

COMBINED = Path('tests/results/combined_three_torque.csv')

OUT_DIR = Path('tests') / 'results' / 'plots'
OUT_DIR.mkdir(parents=True, exist_ok=True)


def read_run_csv(path):
	az = []
	tor = []
	with open(path, 'r', encoding='utf-8') as f:
		# tolerate header or no-header: try to parse floats from first column
		first = f.readline()
		try:
			a0 = float(first.split(',')[0])
			# first line is data
			az.append(a0)
			tor.append(float(first.split(',')[1]))
		except Exception:
			# assume header, continue with remaining lines
			pass
		for line in f:
			parts = line.strip().split(',')
			if len(parts) < 2:
				continue
			try:
				az.append(float(parts[0]))
				tor.append(float(parts[1]))
			except ValueError:
				continue
	return az, tor


def read_combined_csv(path):
	# Expect header with columns e.g. azimuth_deg, torque_baseline_Nm, torque_offset_Nm, torque_phased_Nm
	az = []
	series = {}
	with open(path, 'r', encoding='utf-8') as f:
		reader = csv.reader(f)
		header = next(reader)
		# normalize header names
		header = [h.strip() for h in header]
		# find azimuth column
		az_idx = None
		for i, h in enumerate(header):
			if h in ('azimuth_deg', 'azimuth', 'azimuth_rev'):
				az_idx = i
				az_name = h
				break
		# prepare series for torque columns
		torque_cols = []
		for i, h in enumerate(header):
			if h.endswith('_Nm') and 'torque' in h:
				torque_cols.append((i, h))
				series[h] = []
		if az_idx is None or not torque_cols:
			raise RuntimeError('combined CSV missing expected columns')
		for row in reader:
			try:
				a = float(row[az_idx])
			except Exception:
				continue
			az.append(a)
			for i, h in torque_cols:
				try:
					series[h].append(float(row[i]))
				except Exception:
					series[h].append(float('nan'))
	# detect revolutions (tolerant threshold to catch 0..1 inputs)
	if az and max(az) <= 1.01:
		az = [a * 360.0 for a in az]
	return az, series


def _normalize_and_sort_dict(az, series_dict):
	"""Convert azimuths to degrees if needed and sort az + all series by azimuth.

	Returns (az_sorted, series_sorted_dict)
	"""
	if not az:
		return az, series_dict
	# convert revolutions to degrees if max is ~1.0 or less
	if max(az) <= 1.01:
		az = [a * 360.0 for a in az]
	# create sort order by azimuth
	order = sorted(range(len(az)), key=lambda i: az[i])
	az_sorted = [az[i] for i in order]
	series_sorted = {}
	for k, vals in series_dict.items():
		# pad/truncate series to match az length safely
		vals = list(vals)
		if len(vals) < len(az):
			vals = vals + [float('nan')] * (len(az) - len(vals))
		series_sorted[k] = [vals[i] for i in order]
	return az_sorted, series_sorted


def _normalize_and_sort_list(az, *lists):
	"""Convert azimuths to degrees if needed and sort az + parallel lists by azimuth.

	Returns (az_sorted, [list_sorted,...])
	"""
	if not az:
		return az, list(lists)
	if max(az) <= 1.01:
		az = [a * 360.0 for a in az]
	order = sorted(range(len(az)), key=lambda i: az[i])
	az_sorted = [az[i] for i in order]
	lists_sorted = []
	for lst in lists:
		lst = list(lst)
		if len(lst) < len(az):
			lst = lst + [float('nan')] * (len(az) - len(lst))
		lists_sorted.append([lst[i] for i in order])
	return az_sorted, lists_sorted


any_run = any(p.exists() for p in RUNS.values())

# Per-run plots
for name, path in RUNS.items():
	if not path.exists():
		print(f"Skipping {name}: {path} not found")
		continue
	az, tor = read_run_csv(path)
	plt.figure(figsize=(8, 4))
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
plt.figure(figsize=(10, 5))
if any_run:
	# combine per-run files if present
	for name, path in RUNS.items():
		if not path.exists():
			continue
		az, tor = read_run_csv(path)
		plt.plot(az, tor, label=name)
	else:
		# try combined CSV
		if not COMBINED.exists():
			print('No input run files or combined CSV found; nothing to plot for combined view')
		else:
			az, series = read_combined_csv(COMBINED)
			# normalize/convert and sort az + series before plotting
			az, series = _normalize_and_sort_dict(az, series)
			# plot each torque series
			for key, vals in series.items():
				plt.plot(az, vals, label=key)

plt.xlabel('Azimuth (deg)')
plt.ylabel('Torque (Nm)')
plt.title('Torque vs Azimuth: baseline vs offset vs phased')
plt.grid(True)
plt.legend()
out = OUT_DIR / 'torque_combined.png'
plt.savefig(out, dpi=150)
print(f'Wrote {out}')


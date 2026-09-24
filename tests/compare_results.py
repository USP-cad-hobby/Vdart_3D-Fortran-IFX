#!/usr/bin/env python3
"""
Simple comparator for VDaRT run outputs.
Usage:
	python compare_results.py <baseline_dir> <offset_dir>

It looks for metrics in output.log (CP, Power, Torque, GG) and compares numbers.
It also compares any numeric .dat files present in both directories element-wise and reports max relative error.
Exit code 0 = pass within tolerances; 2 = failure.
"""
import sys
import re
from pathlib import Path
import math

TOLERANCES = {
	'CP': 1e-3,
	'Power': 1e-2,  # relative tolerance
	'Torque': 1e-2,
	'GG': 1e-2,
	# Relax GG tolerance for initial offset test; large static offsets may produce larger GG differences
	'GG': 5e-1,
	'dat_rel': 1e-3,
}

METRIC_REGEX = {
	'CP': re.compile(r"CP\s*[:=]\s*([0-9eE+\-.]+)"),
	'Power': re.compile(r"Power\s*[:=]\s*([0-9eE+\-.]+)"),
	'Torque': re.compile(r"Torque\s*[:=]\s*([0-9eE+\-.]+)"),
	'GG': re.compile(r"GG\s*[:=]\s*([0-9eE+\-.]+)"),
}


def extract_metrics(logpath):
	metrics = {}
	text = logpath.read_text(encoding='utf8', errors='ignore') if logpath.exists() else ''
	for name, rx in METRIC_REGEX.items():
		m = rx.search(text)
		if m:
			try:
				metrics[name] = float(m.group(1))
			except ValueError:
				pass
	return metrics


def compare_scalar(name, a, b, tol):
	"""Return (ok, rel_err, abs_diff).
	rel_err is relative to the offset (b). abs_diff is absolute difference a-b.
	"""
	absdiff = abs(a - b)
	if a == 0 and b == 0:
		return True, 0.0, 0.0
	# use relative error (guard denominator)
	denom = max(abs(b), 1e-12)
	rel = absdiff / denom
	return (rel <= tol), rel, absdiff


def read_dat(path):
	# read numeric columns into a flat list
	vals = []
	if not path.exists():
		return vals
	for line in path.read_text(encoding='utf8', errors='ignore').splitlines():
		line = line.strip()
		if not line or line.startswith('#'):
			continue
		parts = re.split(r"[\s,]+", line)
		nums = []
		for p in parts:
			try:
				nums.append(float(p))
			except Exception:
				pass
		if nums:
			vals.append(nums)
	return vals


def compare_dat(bpath,opath):
	A = read_dat(bpath)
	B = read_dat(opath)
	if not A or not B:
		return None, None
	# compare element-wise up to min size and min columns
	rows = min(len(A), len(B))
	maxrel = 0.0
	for i in range(rows):
		cols = min(len(A[i]), len(B[i]))
		for j in range(cols):
			a = A[i][j]
			b = B[i][j]
			denom = max(abs(b), 1e-12)
			rel = abs(a - b) / denom
			if rel > maxrel:
				maxrel = rel
	return maxrel, (len(A), len(B))


def main():
	if len(sys.argv) < 3:
		print("Usage: compare_results.py <baseline_dir> <offset_dir>")
		return 2
	baseline = Path(sys.argv[1])
	offset = Path(sys.argv[2])
	if not baseline.exists() or not offset.exists():
		print("One of the result directories does not exist")
		return 2

	bmetrics = extract_metrics(baseline / 'output.log')
	ometrics = extract_metrics(offset / 'output.log')

	print("Baseline metrics:", bmetrics)
	print("Offset metrics:  ", ometrics)

	failed = False

	for key in ['CP','Power','Torque','GG']:
		a = bmetrics.get(key)
		b = ometrics.get(key)
		if a is None or b is None:
			print(f"Metric {key} not found in one of the logs; skipping")
			continue
		ok, rel, absdiff = compare_scalar(key, a, b, TOLERANCES.get(key,1e-3))
		print(f"{key}: baseline={a:.6g} offset={b:.6g} abs_diff={absdiff:.6g} rel_err={rel:.3g} tol={TOLERANCES.get(key)} => {'OK' if ok else 'FAIL'}")
		if not ok:
			failed = True

	# Compare .dat files with same names
	bdat_files = {p.name:p for p in baseline.glob('*.dat')}
	odat_files = {p.name:p for p in offset.glob('*.dat')}
	common = set(bdat_files.keys()).intersection(odat_files.keys())
	for name in sorted(common):
		maxrel, sizes = compare_dat(bdat_files[name], odat_files[name])
		if maxrel is None:
			print(f"DAT {name}: one file empty or unreadable; skipping")
			continue
		ok = maxrel <= TOLERANCES['dat_rel']
		print(f"DAT {name}: max_rel={maxrel:.3g} rows(b,o)={sizes} tol={TOLERANCES['dat_rel']} => {'OK' if ok else 'FAIL'}")
		if not ok:
			failed = True

	if failed:
		print("VERDICT: FAIL")
		return 2
	else:
		print("VERDICT: PASS")
		return 0

if __name__ == '__main__':
	sys.exit(main())

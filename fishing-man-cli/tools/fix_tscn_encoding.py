# -*- coding: utf-8 -*-
import os

p = r"C:\Users\admin\Desktop\Godot\fishing-man\scenes\main.tscn"
raw = open(p, "rb").read()
text = raw.decode("utf-8")
print("utf8 valid", len(text))
for i, line in enumerate(text.splitlines(), 1):
	if "text =" in line and any(ord(c) > 127 for c in line):
		print("%d %s" % (i, line.encode("unicode_escape").decode()))

bad = []
root = r"C:\Users\admin\Desktop\Godot\fishing-man"
for dirpath, dirs, files in os.walk(root):
	dirs[:] = [d for d in dirs if d not in (".godot", "addons", ".git")]
	for fn in files:
		if not fn.endswith((".gd", ".tscn", ".cfg")):
			continue
		fp = os.path.join(dirpath, fn)
		try:
			open(fp, "rb").read().decode("utf-8")
		except UnicodeDecodeError as e:
			bad.append((fp, str(e)))
print("remaining bad", bad)

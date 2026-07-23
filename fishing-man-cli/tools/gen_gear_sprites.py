# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw
import os

OUT = r"C:\Users\admin\Desktop\Godot\fishing-man\assets\world\gear"
os.makedirs(OUT, exist_ok=True)
SRC = r"C:\Users\admin\Desktop\Godot\fishing-man\assets\world\boat.png"
boat = Image.open(SRC).convert("RGBA")


def recolor(img, map_fn):
	px = img.load()
	w, h = img.size
	out = img.copy()
	op = out.load()
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 20:
				continue
			nr, ng, nb = map_fn(r, g, b)
			op[x, y] = (
				max(0, min(255, nr)),
				max(0, min(255, ng)),
				max(0, min(255, nb)),
				a,
			)
	return out


def is_orange(r, g, b):
	return r > 180 and g < 160 and b < 100 and r > g


def is_cream(r, g, b):
	return r > 180 and g > 170 and b > 140 and abs(r - g) < 40


def is_dark(r, g, b):
	return r < 80 and g < 80 and b < 80


def map_basic(r, g, b):
	if is_orange(r, g, b):
		t = (r - 180) / 70.0
		return (int(90 + 40 * t), int(140 + 30 * t), int(70 + 20 * t))
	if is_cream(r, g, b):
		avg = (r + g + b) / 3.0
		k = avg / 240.0
		return (int(160 * k + 40), int(110 * k + 30), int(60 * k + 20))
	if is_dark(r, g, b):
		return (r, g, b)
	return (int(r * 0.95), int(g * 0.85), int(b * 0.7))


def map_speed(r, g, b):
	if is_orange(r, g, b):
		return (min(255, int(r * 1.05)), max(0, int(g * 0.9)), max(0, int(b * 0.7)))
	if is_cream(r, g, b):
		return (
			min(255, int(r * 0.95)),
			min(255, int(g * 0.98)),
			min(255, int(b * 1.05) + 8),
		)
	return (r, g, b)


def map_cargo(r, g, b):
	if is_orange(r, g, b):
		t = (r - 180) / 70.0
		return (int(40 + 20 * t), int(70 + 30 * t), int(120 + 40 * t))
	if is_cream(r, g, b):
		avg = (r + g + b) / 3.0
		v = int(avg * 0.92)
		return (v, v, min(255, v + 10))
	return (r, g, b)


basic = recolor(boat, map_basic)
speed = recolor(boat, map_speed)
cargo = recolor(boat, map_cargo)

cw, ch = cargo.size
cargo_w = cargo.resize((int(cw * 1.18), ch), Image.LANCZOS)
canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
ox = (256 - cargo_w.size[0]) // 2
canvas.paste(cargo_w, (ox, 0), cargo_w)
d = ImageDraw.Draw(canvas)
for cx in (105, 128, 151):
	y0 = 175
	d.rectangle(
		[cx - 8, y0, cx + 8, y0 + 14],
		fill=(180, 120, 60, 230),
		outline=(90, 55, 25, 255),
	)
	d.line([cx - 8, y0 + 7, cx + 8, y0 + 7], fill=(90, 55, 25, 255), width=1)
cargo = canvas

db = ImageDraw.Draw(basic)
db.ellipse([118, 188, 138, 210], fill=(120, 75, 40, 230), outline=(70, 40, 20, 255))
db.ellipse([122, 192, 134, 206], fill=(140, 90, 50, 200))

ds = ImageDraw.Draw(speed)
ds.rectangle([118, 40, 138, 55], fill=(40, 140, 220, 230))

basic.save(os.path.join(OUT, "boat_basic.png"))
speed.save(os.path.join(OUT, "boat_speed.png"))
cargo.save(os.path.join(OUT, "boat_cargo.png"))


def make_rod(kind):
	img = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	if kind == "bamboo":
		shaft = (180, 150, 70, 255)
		tip = (210, 180, 90, 255)
		reel = (140, 100, 50, 255)
		line_c = (230, 230, 210, 180)
		handle = (60, 40, 25, 255)
	elif kind == "carbon":
		shaft = (50, 55, 65, 255)
		tip = (80, 160, 200, 255)
		reel = (30, 30, 35, 255)
		line_c = (200, 220, 230, 180)
		handle = (40, 40, 45, 255)
	else:
		shaft = (90, 50, 140, 255)
		tip = (240, 190, 60, 255)
		reel = (180, 140, 40, 255)
		line_c = (255, 230, 120, 200)
		handle = (160, 120, 40, 255)

	pts = [(48, 210), (58, 160), (72, 100), (90, 50), (105, 18)]
	for i in range(len(pts) - 1):
		w = 5 if i < 2 else (4 if i < 3 else 3)
		col = shaft if i < 3 else tip
		d.line([pts[i], pts[i + 1]], fill=col, width=w)
	d.ellipse([36, 188, 62, 214], fill=reel, outline=(20, 20, 20, 255))
	d.ellipse([42, 194, 56, 208], fill=(220, 220, 220, 200))
	d.line([(105, 18), (118, 8)], fill=line_c, width=1)
	d.rectangle([44, 205, 54, 220], fill=handle)
	if kind == "legend":
		d.ellipse([98, 12, 112, 26], outline=(255, 220, 80, 220), width=2)
	return img


make_rod("bamboo").save(os.path.join(OUT, "rod_bamboo.png"))
make_rod("carbon").save(os.path.join(OUT, "rod_carbon.png"))
make_rod("legend").save(os.path.join(OUT, "rod_legend.png"))
print("wrote", sorted(os.listdir(OUT)))

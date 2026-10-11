#!/usr/bin/env python3
"""Generates launcher icons into assets/images/. Requires Pillow + numpy."""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "images"))
SS = 2  # supersample

def glow_layer(size, cx, cy, r, color, strength):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    rgba = np.zeros((size, size, 4), np.float32)
    rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3] = color[0], color[1], color[2], a * 255
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")

def background(S):
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((x - S * .55) ** 2 + (y - S * .42) ** 2) / (S * .75)
    t = np.clip(d, 0, 1)[..., None]
    c0, c1 = np.array([46, 20, 64], np.float32), np.array([5, 2, 9], np.float32)
    img = Image.fromarray((c0 * (1 - t) + c1 * t).astype(np.uint8), "RGB").convert("RGBA")
    img.alpha_composite(glow_layer(S, S * .74, S * .27, S * .30, (236, 228, 210), .55))
    dr = ImageDraw.Draw(img)
    dr.ellipse([S * .74 - S * .085, S * .27 - S * .085, S * .74 + S * .085, S * .27 + S * .085], fill=(238, 232, 214, 255))
    dr.rectangle([0, S * .80, S, S], fill=(10, 6, 16, 255))
    dr.line([0, S * .80, S, S * .80], fill=(110, 90, 140, 160), width=max(2, S // 170))
    return img

def foreground(S, k=1.0):
    """Runner + creature eyes. k<1 shrinks the art toward the centre (adaptive-icon safe zone)."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    def P(u, v): return ((0.5 + (u - 0.5) * k) * S, (0.5 + (v - 0.5) * k) * S)
    dr = ImageDraw.Draw(img)
    # tall creature silhouette rising from the left edge
    body = [P(-.05, .90), P(-.05, .16), P(.10, .12), P(.22, .22), P(.25, .40), P(.30, .62), P(.34, .90)]
    dr.polygon(body, fill=(2, 0, 4, 255))
    dr.ellipse([*P(.05, .16), *P(.24, .46)], fill=(2, 0, 4, 255))
    img.alpha_composite(glow_layer(S, *P(.115, .30), S * .22 * k, (255, 30, 50), 1.0))
    img.alpha_composite(glow_layer(S, *P(.185, .30), S * .22 * k, (255, 30, 50), 1.0))
    dr = ImageDraw.Draw(img)
    for ex in (.115, .185):
        cx, cy = P(ex, .30)
        dr.polygon([(cx - S * .030 * k, cy - S * .006 * k), (cx + S * .030 * k, cy + S * .014 * k), (cx + S * .026 * k, cy + S * .026 * k), (cx - S * .030 * k, cy + S * .006 * k)], fill=(255, 235, 235, 255))
    # runner (pale so it reads on dark), leaning forward
    col = (176, 166, 198, 255); w = max(3, int(S * .032 * k))
    head = P(.70, .43); hip = P(.60, .64); sh = P(.66, .49)
    dr.ellipse([head[0] - S * .045 * k, head[1] - S * .045 * k, head[0] + S * .045 * k, head[1] + S * .045 * k], fill=col)
    dr.line([hip, sh], fill=col, width=int(w * 1.6))
    dr.line([hip, P(.70, .72), P(.76, .80)], fill=col, width=w)
    dr.line([hip, P(.55, .74), P(.47, .77)], fill=(120, 110, 140, 255), width=w)
    dr.line([sh, P(.72, .58), P(.79, .55)], fill=col, width=w)
    dr.line([sh, P(.58, .55), P(.53, .62)], fill=(120, 110, 140, 255), width=w)
    # red scarf streaming back toward the creature
    pts = [P(.665 - i * .045, .475 + math.sin(i * 1.1) * .018 + i * .008) for i in range(6)]
    dr.line(pts, fill=(226, 30, 56, 255), width=int(w * 1.3), joint="curve")
    return img

def scaled(img, size): return img.resize((size, size), Image.LANCZOS)

def main():
    os.makedirs(OUT, exist_ok=True)
    S = 512 * SS
    full = background(S); full.alpha_composite(foreground(S, 1.0))
    scaled(full.convert("RGB"), 512).save(os.path.join(OUT, "icon.png"))
    scaled(full.convert("RGB"), 192).save(os.path.join(OUT, "icon_192.png"))
    S2 = 432 * SS
    scaled(background(S2).convert("RGB"), 432).save(os.path.join(OUT, "icon_bg_432.png"))
    scaled(foreground(S2, 0.62), 432).save(os.path.join(OUT, "icon_fg_432.png"))
    print("icons ->", OUT, sorted(os.listdir(OUT)))

main()

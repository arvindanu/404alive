#!/usr/bin/env python3
"""Renders assets/images/logo.png: the "404: Alive" wordmark. The 0 of 404 is an eye, glancing back
over its shoulder. Requires Pillow + the bundled Gloock font."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Gloock-Regular.ttf")
OUT = os.environ.get("LOGO_OUT", os.path.join(ROOT, "assets", "images", "logo.png"))
W, H = 3200, 700
BONE = (238, 230, 224); CRIMSON = (214, 34, 58); INK = (10, 6, 16)
TITLE = "404: Alive"
EYE_INDEX = 1            # the "0"
TRACK = 30               # extra letter-spacing in px at font size 330
Y0 = 120                 # top of the text line on the canvas


def main():
    big = ImageFont.truetype(FONT, 330)
    # --- layout: per-character advance with tracking
    pos = []; x = 0
    for i, ch in enumerate(TITLE):
        w = big.getlength(ch)
        pos.append((ch, x, w)); x += w + (TRACK * 1.6 if ch == ":" else TRACK + (26 if i <= EYE_INDEX else 0))
    total = int(x - TRACK); ox = (W - total) // 2

    mask = Image.new("L", (W, H), 0)          # glyph mask (gradient fill + glow)
    red_mask = Image.new("L", (W, H), 0)      # glyphs painted crimson ("404:")
    md = ImageDraw.Draw(mask); rd = ImageDraw.Draw(red_mask)
    eye = None
    zb = big.getbbox("0")
    for i, (ch, cx, w) in enumerate(pos):
        if i == EYE_INDEX:
            ww = zb[2] - zb[0]; ex0 = ox + cx + (w - ww) / 2
            eye = (ex0, Y0 + zb[1], ex0 + ww, Y0 + zb[3])
        elif ch != " ":
            md.text((ox + cx, Y0), ch, font=big, fill=255)
            if i < 4:                         # "4", "4", ":"  -> crimson
                rd.text((ox + cx, Y0), ch, font=big, fill=255)
    text_mask = mask.copy(); ed = ImageDraw.Draw(text_mask)
    ed.ellipse(eye, fill=255)                  # the eye is part of the glow/gradient mask

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (W, H), CRIMSON + (0,))
    glow.putalpha(text_mask.filter(ImageFilter.GaussianBlur(38)).point(lambda v: min(255, int(v * 1.5))))
    img.alpha_composite(glow)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.putalpha(text_mask.filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.85)))
    img.alpha_composite(shadow, (6, 10))
    grad = Image.new("RGBA", (W, H)); gd = ImageDraw.Draw(grad)
    for yy in range(H):
        t = min(1.0, max(0.0, (yy - Y0) / 400))
        col = tuple(int(BONE[i] * (1 - t) + (168, 150, 168)[i] * t) for i in range(3))
        gd.line([(0, yy), (W, yy)], fill=col + (255,))
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0)); body.paste(grad, (0, 0), mask)
    band = Image.new("RGBA", (W, H), CRIMSON + (255,)); body.paste(band, (0, 0), red_mask)
    img.alpha_composite(body)

    # --- the eye (same construction as the original wordmark's eyes)
    d = ImageDraw.Draw(img)
    a, b, c, e = eye; w, h = c - a, e - b; cxm, cym = (a + c) / 2, (b + e) / 2
    d.ellipse((a, b, c, e), fill=BONE + (255,))
    ins = w * 0.17
    d.ellipse((a + ins, b + ins * 0.8, c - ins, e - ins * 0.8), fill=INK + (255,))
    look = -0.16 * w                           # looks back over its shoulder
    ix = cxm + look; ir = w * 0.20
    for k in range(6, 0, -1):                  # soft iris glow
        d.ellipse((ix - ir - k * 3, cym - ir - k * 3, ix + ir + k * 3, cym + ir + k * 3), fill=CRIMSON + (int(14 * (7 - k)),))
    d.ellipse((ix - ir, cym - ir, ix + ir, cym + ir), fill=(226, 40, 62, 255))
    d.ellipse((ix - ir * 0.32, cym - ir * 0.95, ix + ir * 0.32, cym + ir * 0.95), fill=(6, 2, 8, 255))
    d.ellipse((ix - ir * 0.55, cym - ir * 0.7, ix - ir * 0.25, cym - ir * 0.4), fill=(255, 255, 255, 220))

    # --- scratch under the wordmark (kept from the original design)
    bb = img.getbbox(); yb = bb[3] - 26
    ImageDraw.Draw(img).line([(bb[0] + 260, yb), (bb[2] - 330, yb + 6)], fill=CRIMSON + (200,), width=5)
    img = img.crop(img.getbbox()); pad = 40
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0)); out.alpha_composite(img, (pad, pad))
    out.save(OUT); print("logo ->", OUT, out.size, "aspect %.3f" % (out.width / out.height))


main()

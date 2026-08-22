#!/usr/bin/env python3
"""Render the Nothing OS dot-matrix boot animation as a seamless loop.

The original hexagon_dots frames were a one-shot ping: ~17 frames of motion,
15 frames frozen, then a hard cut back to frame 0.  The lattice underneath was
recovered from those frames by least-squares fit (hex, 5 rings, 91 dots, pitch
22.24 px on the 800x600 canvas, centre (400, 289.5), residual 0.012 px/dot) and
is re-rendered here at final display size with a continuous radial wave, so
frame N-1 flows into frame 0 with no discontinuity.

Each ring's radius is a pure cosine of time with a phase offset of one full
wavelength across the 5 rings, which makes the loop exact by construction.
"""
import math
import numpy as np
from PIL import Image

RINGS   = 5
FRAMES  = 60          # paired with Plymouth.SetRefreshRate(30) -> 2.0 s per ripple
PITCH   = 61.0        # output px; = 22.24 source px * 2.743, the scale in use today
SS      = 4           # supersampling factor for dot antialiasing

# Resting radius per ring, measured off the original frames (source px) and
# carried over to output scale.  The bump at rings 1-2 is the theme's identity.
BASE = [r * (PITCH / 22.24) for r in (3.58, 4.46, 4.50, 3.55, 2.03, 1.53)]
# Wave depth per ring: the original pulse bit harder the further out it got.
AMPL = [0.12, 0.18, 0.25, 0.34, 0.46, 0.58]
MIN_R = 1.6           # never let a dot fall below this, or it flickers out

sites = []
for q in range(-RINGS, RINGS + 1):
    for r in range(-RINGS, RINGS + 1):
        if max(abs(q), abs(r), abs(q + r)) <= RINGS:
            sites.append((PITCH * (math.sqrt(3) / 2) * q,
                          PITCH * (r + q / 2),
                          max(abs(q), abs(r), abs(q + r))))
assert len(sites) == 3 * RINGS * RINGS + 3 * RINGS + 1 == 91

RMAX = max(BASE[n] * (1 + AMPL[n]) for _, _, n in sites)
MARGIN = math.ceil(RMAX) + 2
W = 2 * math.ceil(RINGS * PITCH * math.sqrt(3) / 2 + MARGIN)
H = 2 * math.ceil(RINGS * PITCH + MARGIN)
CX, CY = W / 2.0, H / 2.0


def disc(canvas, cx, cy, rad):
    """Add an antialiased filled circle by supersampling its bounding box."""
    x0, x1 = int(cx - rad - 1), int(cx + rad + 2)
    y0, y1 = int(cy - rad - 1), int(cy + rad + 2)
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, canvas.shape[1]), min(y1, canvas.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    sx = (np.arange((x1 - x0) * SS) + 0.5) / SS + x0 - cx
    sy = (np.arange((y1 - y0) * SS) + 0.5) / SS + y0 - cy
    inside = (sx[None, :] ** 2 + sy[:, None] ** 2) <= rad * rad
    cover = inside.reshape(y1 - y0, SS, x1 - x0, SS).mean(axis=(1, 3))
    np.maximum(canvas[y0:y1, x0:x1], cover, out=canvas[y0:y1, x0:x1])


for i in range(FRAMES):
    buf = np.zeros((H, W), dtype=np.float64)
    for dx, dy, ring in sites:
        # One wavelength across the radius: the crest is born at the centre as
        # the previous one dies at the rim, so t = 0 and t = FRAMES agree exactly.
        phase = 2 * math.pi * (i / FRAMES - ring / RINGS)
        rad = BASE[ring] * (1 + AMPL[ring] * math.cos(phase))
        disc(buf, CX + dx, CY + dy, max(rad, MIN_R))
    Image.fromarray(np.rint(buf * 255).astype(np.uint8), mode="L").save(
        f"dot-{i}.png", optimize=True)

print(f"{FRAMES} frames  {W}x{H}  pitch={PITCH}  rmax={RMAX:.1f}")
print(f"runtime RAM = {FRAMES * W * H * 4 / 2**20:.0f} MB "
      f"(was {32 * 2194 * 1645 * 4 / 2**20:.0f} MB)")

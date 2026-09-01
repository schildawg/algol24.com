# Algol-24 — the mark

Algol is **β Persei**, the Demon Star: a hierarchical triple in Perseus, and one
of the first variable stars ever identified as variable, by Geminiano Montanari
in 1667. Algol A and Algol B eclipse each other every **2.87 days**. The mark is
that system.

| In the mark | In the sky |
|---|---|
| The orange star | **Algol B** — K0IV, a cooler orange subgiant, physically the larger |
| The blue star | **Algol A** — B8V, the hot blue-white main-sequence primary |
| The small dark star | **Algol C** — A7m, the distant third, 680 days out |
| The two orbits | The pair's mutual orbit, and Algol C's around them |

Two bodies that must be observed together, whose agreement over time is the
whole measurement. The language has an interpreter and a compiler and demands
that the two agree. The mark was well chosen.

---

## Palette

Sampled from the original concept rather than invented, so the assets and the
source image agree.

| Token | Hex | Where it comes from |
|---|---|---|
| `--algol-orange` | `#F5901E` | Algol B, mid-tone. The primary accent. |
| `--algol-orange-deep` | `#E06309` | Algol B, gradient foot. Hovers, active states. |
| `--algol-orange-glow` | `#FEDD9B` | Algol B's halo. Backgrounds, highlight fills. |
| `--algol-blue` | `#2F7BD1` | Algol A, mid-tone. The secondary accent. |
| `--algol-blue-deep` | `#1264C7` | Algol A, gradient foot. |
| `--algol-blue-glow` | `#DCEBFB` | Algol A's halo. |
| `--algol-ink` | `#00153D` | Algol C, and the darkest pixel in the concept. Body text, dark ground. |
| `--algol-c-light` | `#C7D4E6` | Algol C lifted, for dark grounds only. |

### Which star leads depends on the theme

The site carries a light/dark toggle, and the contrast measurements decide the
accent for each — they are not interchangeable.

| Color | On white | On ink |
|---|---|---|
| `#F5901E` orange | **2.36** ✗ fails everything | **7.57** ✓ body text |
| `#E06309` orange-deep | **3.52** — large text only | 5.07 ✓ |
| `#2F7BD1` blue | 4.31 — just short of body | 4.15 — large text only |
| `#1264C7` blue-deep | **5.72** ✓ body text | 3.13 ✗ |
| `#C7D4E6` c-light | 1.50 ✗ | **11.91** ✓ |

So **light theme leads with Algol A, the blue** (`#1264C7` for links and
interactive text), and **dark theme leads with Algol B, the orange**
(`#F5901E`). Which happens to be the eclipse: which star you see depends on the
phase.

⚠️ **Orange is never body text on white.** At 2.36:1 it fails even the
large-text threshold, and an orange that would pass on white is a brown. In the
light theme it is for the mark, rules, and headings at 24px and above, using
`--algol-orange-deep`. This is the single easiest thing to get wrong here.

For dark-theme blue, lift to `#8FC2F6` (9.55) rather than using `--algol-blue`.

### Tokens by theme

| Role | Light | Dark |
|---|---|---|
| ground | `#FFFFFF` | `#00153D` |
| body text | `#00153D` | `#E8EEF7` |
| muted text | `#3D5273` | `#9FB3CE` |
| accent / links | `#1264C7` | `#F5901E` |
| accent hover | `#0D4E9E` | `#FFC46B` |
| rules, marks | `#E06309` | `#F5901E` |
| code panel | `#F6F8FB` | `#041B45` |

---

## The four tiers, and why there are four

A single artwork does not survive from 1200px to 16px. Each tier drops whatever
stops being legible at its floor.

| Tier | Use at | Carries | Drops |
|---|---|---|---|
| `algol-24-full` | **≥160px** | both stars, both orbits, Algol C, glow | — |
| `algol-24-compact` | **48–128px** | both stars, one orbit, no glow | second orbit, Algol C, glow |
| `algol-24-glyph` | **32–48px** | both stars, flat fill | orbits entirely |
| `algol-24-micro` | **≤32px** | both stars, points thickened to `.58` | everything else |

The thickening in `micro` is the whole point of it. The concept's star points
taper to a hairline, and a hairline at 16px is a subpixel — it renders as two
vertical smudges. Widening the horizontal axis is what keeps a *four-pointed
star* reading as a four-pointed star at favicon size.

The floors are not guesses. `review/contact.png` renders every tier at 16, 32, 48,
64 and 128 for exactly this comparison; regenerate it whenever a tier changes.

---

## Building

```sh
./build.sh          # svg/ -> dist/
```

⚠️ **Two rasterisers, for a bad reason.** ImageMagick keeps alpha but fills SVG
gradients flat black through its built-in MSVG delegate. `qlmanage` renders
gradients correctly through WebKit and always composites onto an opaque
background. So the flat tiers go through ImageMagick and the gradient tiers go
through `qlmanage` against a background painted into a temporary wrapper.

`brew install librsvg` removes the whole problem — `rsvg-convert` keeps alpha
*and* renders gradients. Collapse `build.sh` to one path the day it is on the
build machine.

### What `dist/` holds

| File | For |
|---|---|
| `favicon.ico` | 16/32/48 in one file, transparent |
| `favicon-16/32/48.png` | modern `<link rel="icon">` |
| `apple-touch-icon.png` | 180×180, opaque — iOS composites its own corners |
| `icon-192.png`, `icon-512.png` | web app manifest |
| `icon-512-dark.png` | dark ground, Algol C lifted |
| `maskable-512.png` | `purpose="maskable"`, mark inside the safe zone |
| `og-image.png` | 1200×630 social card |
| `*.svg` | the masters — what the site itself should link |

**Prefer the SVG on the site.** The rasters exist for platforms that demand a
PNG.

⚠️ **Inline the SVG into the page; do not reference it with `<img src>`.**
`algol-24-full.svg` lifts Algol C on dark grounds through a
`prefers-color-scheme` rule, and that rule answers to the **operating system**,
not to the site's theme toggle. An `<img>`-referenced SVG is a separate document
that cannot see `data-theme`, so a visitor who forces dark on a light machine
gets a dark page with a near-black Algol C sitting invisibly on it.

Inlined, the same file inherits the page's custom properties and follows the
toggle for free. The generator emits the markup, so this costs nothing and also
removes a request. The media query stays in the file as the fallback for
anywhere it is used standalone — a README, a GitHub social preview.

---

## Still open

- **No wordmark.** "Algol-24" set beside the mark, with a chosen typeface, a
  fixed relationship and clear space. Needed before a site header exists.
- **The concept file is not a master.** `algol-24.png` is 573×502, RGB with **no
  alpha**, so it carries a baked white background and cannot go on a dark ground
  or into an icon. `svg/` supersedes it. Keep the original as provenance.
- **The vectors are a redraw, not a trace.** They were rebuilt from the concept
  by eye and by sampled color. Proportions are close but not identical, and the
  concept's star points are finer than the redraw's.
- **The mark is stronger on dark than on light.** The glow reads as starlight
  against a night sky and as haze against white. Worth weighing when the site's
  ground color is chosen.

# Beamforming Physics Simulation

MATLAB simulation establishing the **physics ceiling** for the RP2040 true-time-delay
audio phased array: what a 6-element uniform linear array *should* do under ideal
conditions, so later hardware measurements have something to be compared against.

This directory covers the simulation step only — no firmware, no Simulink, no
hardware-measured data. Base MATLAB only; the Phased Array System Toolbox is used
**optionally** in one test as an independent cross-check, never in the primary
computation. The point of the project is that the physics is transparent, so every
array factor is computed from raw first-principles equations.

---

## Quick start

```bash
matlab -batch "run('simulation/tests/test_array_factor_sanity.m')"
```

```bash
matlab -batch "run('simulation/scripts/run_beampattern_sweep.m')"
```

```bash
matlab -batch "run('simulation/scripts/run_plots.m')"
```

Run them in that order: the tests validate the library, the sweep writes
`results/`, and the plots read `results/` and write `figures/`. Each script resolves
its own paths, so the working directory does not matter. Inside the MATLAB desktop,
use `run('simulation/scripts/run_beampattern_sweep.m')` instead.

The full sweep takes about half a second. Everything under `results/` and `figures/`
is regenerated from source and is gitignored.

---

## The three conditions

All three are the *same* array-factor equation with a different applied per-element
phase `psi_n`. Element `n` (`n = 0..N-1`) sits at `x_n = n*d`; `theta` is measured
from broadside; the far-field contribution of element `n` arrives early by
`t_n(theta) = n*d*sin(theta)/c`:

```
AF(theta, f) = (1/N) * sum_n exp( j * ( 2*pi*f*t_n(theta) - psi_n ) )
```

| Condition | Applied phase `psi_n` | Behaviour |
|---|---|---|
| **Ideal TTD** | `2*pi*f * tau_n` | Tracks `f` exactly → beam fixed at `theta0` at every frequency. Squint is identically zero. This is the ceiling. |
| **Quantized TTD** | `2*pi*f * tau_n_q` | Same, but `tau_n_q = round(tau_n*fs)/fs`. Error is a fixed *time*, so its phase error grows linearly with frequency. |
| **Phase-only** | `2*pi*f0 * tau_n` | Frozen at the design frequency. Does **not** scale with `f` — this is what causes beam squint. |

where `tau_n(theta0) = n*d*sin(theta0)/c`.

Because the phase-only geometric term scales with `f` while its applied phase does
not, its peak sits at

```
sin(theta_peak) = (f0 / f) * sin(theta0)
```

which is exact at `f = f0`, collapses toward broadside above it, and swings away
below it. Once `(f0/f)*sin(theta0) > 1` the main lobe leaves visible space entirely.
All three behaviours are asserted numerically in the test suite.

### A note on hardware faithfulness

Real firmware stores non-negative **integer** sample offsets, normally shifted so
`min(k_n) = 0`. That shift is a delay common to every element, so it contributes only
a scalar phase and leaves `|AF|` unchanged — verified to ~1e-15 in the tests. Rounding
`tau_n` directly, as the code does, therefore models the delay line exactly. Negative
delays for `theta0 < 0` are non-causal for the same reason and are handled the same
way: they are a bulk offset and do not affect the magnitude pattern.

---

## Grating lobes: read this before interpreting any result

Grating lobes are a **geometry** limit, not a delay-precision limit. A ULA radiates
full-height lobes wherever `sin(theta_g) = sin(theta0) - lambda/d`, and the first one
enters visible space at

```
f_grating = c / ( d * (1 + sin(theta_max)) )
```

With the current placeholder `d = 5 cm` and `c = 343 m/s`:

| Steering angle | `f_grating` | Aliased portion of the band |
|---:|---:|---|
| 0° | 6860 Hz | top 1.54 of 9.97 octaves |
| 15° | 5450 Hz | top 1.88 octaves |
| 30° | 4573 Hz | top 2.13 octaves |
| 45° | 4018 Hz | top 2.32 octaves |
| 55° | 3771 Hz | top 2.41 octaves |

**Every one of these falls inside the 20 Hz–20 kHz target band.** Above them the array
radiates a second full-strength beam in an unintended direction, and no amount of
delay resolution removes it — only a smaller `d` does. This is a genuine finding about
the placeholder geometry, not a bug, and it bounds how the whole sweep may be read.
Every plot marks and shades this region.

It also makes "the peak angle" genuinely ambiguous above `f_grating`: several lobes
are *exactly* equal in height, so a plain `argmax` can jump between them. The sweep
therefore stores two squint columns (see the glossary), and `analyzeBeamPattern`
flags every affected frequency rather than smoothing it over.

The relevant spacing condition, `d <= lambda / (1 + sin(theta_max))`, is the same one
used by Gaviola et al. (2018) for their Arduino Due array.

---

## Key results from the current configuration

**Ideal TTD squint is exactly zero** — not approximately. On the sampled angle grid
the peak lands precisely on `theta0` at every frequency and every steering angle
tested. This is the frequency-invariance property that motivates TTD.

**Quantized TTD costs very little until the top octave.** On-target loss relative to
the ideal ceiling:

| Steering | 1 kHz | 5 kHz | 10 kHz | 15 kHz | 20 kHz |
|---:|---:|---:|---:|---:|---:|
| 0° | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 dB |
| 15° | −0.01 | −0.16 | −0.66 | −1.52 | −2.81 dB |
| 30° | −0.01 | −0.14 | −0.56 | −1.27 | −2.29 dB |
| 45° | −0.01 | −0.13 | −0.51 | −1.18 | −2.16 dB |
| 55° | −0.01 | −0.16 | −0.66 | −1.51 | −2.74 dB |

Loss stays under 1 dB until 12.3–14.2 kHz depending on steering angle. Broadside is
exactly lossless because every `tau_n` is zero and there is nothing to round.

The rounding error is bounded by half a sample (11.34 µs at 44.1 kHz); at 55° the
worst element lands 10.61 µs off, which is **76° of phase at 20 kHz**. That fixed
time error is the whole mechanism: it is negligible in the bass and severe in the
top octave.

Quantized TTD also introduces a small **frequency-independent** squint — the rounded
delays best-fit a slightly different angle. It is constant across the band and
non-monotonic in steering angle (it depends on where each `tau_n` happens to fall
relative to a sample boundary): 0.000° at 0°, −0.325° at 15°, +0.442° at 30°,
−0.035° at 45°, −0.576° at 55°.

**Phase-only is the outlier by a wide margin.** Steered to 55° with `f0 = 1 kHz`:

| Frequency | Squint | Peak angle | On-target loss |
|---:|---:|---:|---:|
| 200 Hz | +35.00° | 90.0° (off-screen) | −5.21 dB |
| 819 Hz | +33.43° | 88.4° | −0.23 dB |
| 1000 Hz | 0.00° | 55.0° | 0.00 dB |
| 2000 Hz | −30.82° | 24.2° | −9.03 dB |
| 3000 Hz | −39.11° | 15.9° | −12.44 dB |

Exact at its design frequency, and essentially unusable one octave either side. Below
819 Hz — where `(f0/f)·sin 55° > 1` — the main lobe has left visible space altogether.

---

## Directory layout

```
simulation/
├── config/
│   └── array_config.m              every tunable parameter, single source of truth
├── lib/
│   ├── arrayFactorTTDIdeal.m       continuous-delay array factor
│   ├── arrayFactorTTDQuantized.m   sample-quantized array factor
│   ├── arrayFactorPhaseOnly.m      fixed single-frequency phase array factor
│   ├── gratingLobeOnsetFreq.m      spatial-aliasing onset frequency
│   ├── analyzeBeamPattern.m        peak / beamwidth / sidelobe extraction
│   └── private/
│       └── afFromElementPhase.m    shared vectorized AF kernel
├── scripts/
│   ├── run_beampattern_sweep.m     main sweep → results/
│   └── run_plots.m                 all figures ← results/
├── tests/
│   └── test_array_factor_sanity.m  119 physics assertions
├── results/                        generated .mat/.csv (gitignored)
├── figures/                        generated .png/.fig (gitignored)
└── README.md
```

---

## Parameter glossary (`config/array_config.m`)

Nothing outside this file defines a physical constant or a sweep range.

| Parameter | Default | Units | Meaning |
|---|---|---|---|
| `N` | 6 | – | Number of array elements |
| `d` | 0.05 | m | Element spacing. **Placeholder** pending driver selection; sets `f_grating` |
| `c` | 343 | m/s | Speed of sound (dry air, ~20 °C) |
| `fs` | 44100 | Hz | Sample rate; delay quantization step is `1/fs` ≈ 22.68 µs |
| `f0` | 1000 | Hz | Design frequency for the phase-only condition |
| `theta_deg` | −90:0.25:90 | deg | Look-angle axis. Must stay uniform for sub-grid peak interpolation |
| `n_freq` | 241 | – | Base count of log-spaced frequency points |
| `f_Hz` | 253 pts | Hz | 20 Hz–20 kHz log-spaced, with `f0`, the polar-plot frequencies and every `f_grating` forced onto the grid |
| `steer_deg` | [0 15 30 45 55] | deg | Steering angles under test |
| `theta_max_deg` | 55 | deg | Widest steering angle; drives the worst-case grating-lobe report |
| `db_floor` | −40 | dB | Display floor for polar plots and heatmaps |
| `db_store_floor` | −200 | dB | Numerical floor applied before `log10`, avoids `-Inf` |
| `full_lobe_tol_db` | 1.0 | dB | A lobe within this much of the peak counts as full height → grating-lobe detection |
| `plot_f_Hz` | 500…20000 | Hz | Frequencies shown in the polar grid |
| `plot_steer_deg` | [0 30 55] | deg | Steering angles shown in the polar grid |

`f_Hz` is built as a union rather than a plain `logspace` deliberately: without it,
`f0 = 1000 Hz` falls between two samples and the phase-only squint curve never quite
reaches zero at its own design frequency — a sampling artefact that would look like a
physics result.

---

## How to read the figures

| File | What it shows |
|---|---|
| `polar_grid_all` | 3 steering angles × 7 frequencies, all conditions overlaid |
| `polar_steer<A>` | The same, one readable page per steering angle |
| `heatmap_steer<A>` | Angle vs frequency, dB as colour — the clearest single view of squint |
| `squint_vs_frequency` | Squint(f), one line per condition, one panel per steering angle |
| `beamwidth_vs_frequency` | −3 dB beamwidth(f) |
| `sidelobe_vs_frequency` | Peak sidelobe level(f) |
| `ontarget_gain_vs_frequency` | Response at the *intended* angle — the best single summary |

Saved as both `.png` (for reports) and `.fig` (for zooming).

Reading notes:

- **Shaded band = spatially aliased.** Above `f_grating` the array has a second
  full-strength beam. Those numbers describe an array already broken by geometry, not
  by delay precision. Do not quote them as a delay-resolution result.
- **On the heatmaps, ideal TTD's bright ridge is dead vertical** while phase-only's
  bends toward broadside. That bend *is* beam squint.
- **Ideal TTD's squint line sits on zero everywhere by construction.** Any deviation
  would be a bug, not a finding.
- **Gaps in the beamwidth curves at low frequency are correct.** A 30 cm aperture is
  effectively omnidirectional below a few hundred Hz, so it has no half-power point
  inside ±90°. `analyzeBeamPattern` returns `NaN` rather than inventing a number.
- **Sidelobe level rising to ~0 dB is the correct reporting of an aliased array** — a
  grating lobe *is* a 0 dB sidelobe.
- On the squint panels the dotted overlay follows the full-height lobe nearest the
  intended angle. It coincides with the solid line below the aliasing onset and
  separates above it, marking exactly where "the peak" stops being well defined.

---

## Output data

`results/sweep_results.mat` holds `results` with:

- `theta_deg` `[1×721]`, `f_Hz` `[1×253]`, `steer_deg` `[1×5]`
- `af_db.<condition>` `[721×253×5]` — normalised array factor in dB
- `metrics.<condition>.<metric>` `[253×5]`
- `f_grating_Hz` `[1×5]`, and `params` (a copy of the config used)

`results/sweep_metrics.csv` is the same metrics flattened to one row per
(condition, steering angle, frequency) — 3795 rows.

### Metric glossary

| Field | Meaning |
|---|---|
| `peak_angle_deg` | Angle of maximum response, parabolically refined below the grid step |
| `peak_angle_sampled_deg` | Angle of the largest *sample*, no interpolation — bias-free |
| `peak_angle_tracked_deg` | Full-height lobe nearest the intended angle |
| `squint_deg` | `peak_angle_deg − theta0` (the metric named in the project spec) |
| `squint_tracked_deg` | Same, from the tracked lobe. Agrees with `squint_deg` below `f_grating`; diverges above, where the peak is ambiguous |
| `beamwidth_3db_deg` | Full half-power width; `NaN` when no −3 dB point exists in visible space |
| `sidelobe_level_db` | Highest response outside the main-lobe null-to-null region, relative to peak |
| `grating_lobe_flag` | A full-height lobe exists outside the main lobe |
| `n_full_lobes` | How many lobes are within `full_lobe_tol_db` of the peak |

Both `peak_angle_deg` and `peak_angle_sampled_deg` exist because parabolic refinement
carries a small bias for a steered beam: the lobe is symmetric in `sin(theta)` but is
sampled uniformly in `theta`, so the three-point fit sits ~3e-3 of a grid step off
centre (<1e-3° here). Irrelevant for plotting, but it matters when asserting that
squint is *exactly* zero — so the tests assert on the sampled column and separately
bound the interpolator bias.

---

## Test suite

`tests/test_array_factor_sanity.m` runs 119 assertions and errors if any fail, so it
works as a CI gate. It collects every failure in one pass rather than stopping at the
first. Covered:

1. Broadside ideal TTD is symmetric and peaks exactly at 0°
2. Response is exactly 0 dB at `theta0` for ideal TTD (any `f`) and phase-only at `f0`
3. Phase-only equals ideal TTD **exactly** at `f = f0` (max error 0.0)
4. Quantized TTD converges to ideal as `fs → ∞` and as `f → 0`
5. Ideal TTD squint is exactly 0 below aliasing; a full-height lobe stays at `theta0` above it
6. Quantized TTD is bit-identical to ideal at broadside
7. A common integer-sample bulk delay leaves `|AF|` unchanged (the hardware-faithfulness proof)
8. Grating-lobe onset matches `c/(d(1+sin θ_max))`, with one lobe below and several above
9. Phase-only squint follows `asin((f0/f)·sin θ0)` below onset
10. `analyzeBeamPattern` beamwidth matches the textbook `0.886·λ/(N·d)` to ~1–2%
11. Output shapes; scalar-vs-vector and row-vs-column calls agree
12. Optional cross-check against the Phased Array System Toolbox (agrees to ~1e-15)

Check 2 deliberately does **not** assert that quantized TTD reaches 0 dB at `theta0` —
rounding the delays is exactly what stops it, away from broadside. It is bounded
instead, with convergence covered by checks 4 and 6.

---

## Scope

Not included, by design: firmware/PIO/DMA code, a Simulink model, hardware-measured
data, 2D/planar arrays, and the parametric-array (ultrasonic self-demodulation)
extension. No element directivity is modelled either — these are array factors for
isotropic elements, so a real driver's own pattern multiplies on top.

Known extension worth flagging: fractional-delay interpolation would push resolution
below the raw sample period and shrink the quantized-vs-ideal gap directly. It is the
standard mitigation for exactly the penalty quantified here, and is future work rather
than part of this baseline.

---

## References informing this step

Selected from `docs/Reference_Review.md` for direct relevance to the simulation:

- M. Q. Abdalrazak, A. H. Majeed, R. A. Abd-Alhameed, "A Critical Examination of the
  Beam-Squinting Effect in Broadband Mobile Communication: Review Paper,"
  *Electronics*, vol. 12, no. 2, art. 400, 2023. DOI: 10.3390/electronics12020400 —
  peer-reviewed grounding for the squint mechanism and TTD as its mitigation.
- Analog Devices, "Phased Array Antenna Patterns—Part 2: Grating Lobes and Beam
  Squint," *Analog Dialogue* — worked treatment of both effects modelled here.
- A. Da Silva Gaviola, M. Rivai, H. Kusuma, "Audio Beam Steering With Phased Array
  Method Using Arduino Due Microcontroller," ICOIACT 2018, pp. 597–601 — source of
  the `d ≤ λ/(1+sin θ_max)` spacing condition implemented in `gratingLobeOnsetFreq`.
- L. Pope et al., "Phased Array Systems: Design Considerations & System
  Demonstration," IEEE ARRAY 2024 — closest existing analogue to the quantization
  question, in the phase/amplitude domain rather than delay.
- T. I. Laakso, V. Välimäki, M. Karjalainen, U. K. Laine, "Splitting the Unit Delay:
  Tools for Fractional Delay Filter Design," *IEEE Signal Process. Mag.*, vol. 13,
  no. 1, pp. 30–60, 1996 — the standard route below one sample period; cited here as
  the mitigation for the penalty this simulation quantifies.
- Y. Zhang, Q. Xiang, Q. Zhu, "Design of Differential Loudspeaker Line Array for
  Steerable Frequency-Invariant Beamforming," *Sensors*, vol. 24, no. 19, art. 6277,
  2024. DOI: 10.3390/s24196277 — an alternative route to frequency invariance
  (differential processing) worth contrasting with true time delay.
- C. Bakhos, "Steering Sound with a Phased Speaker Array," M.Eng. report, Cornell
  University — RP2040-family array using **phase-only** steering; the closest
  same-hardware precedent for this benchmark's control arm.
- MathWorks, Phased Array System Toolbox documentation — used only as the independent
  cross-check in check 12.

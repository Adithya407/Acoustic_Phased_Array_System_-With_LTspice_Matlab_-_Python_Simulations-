# Simulation

Two standalone MATLAB scripts for the 6-speaker true-time-delay array
(N = 6, 20 mm speakers, d = 50 mm, c = 343 m/s). They need base MATLAB only: no
toolboxes, and neither depends on the other.

| File | What it does |
|---|---|
| `beamforming_physics_explorer.m` | The interactive models from [`docs/beamforming_physics.html`](../docs/beamforming_physics.html), one tab each: sound field, pattern multiplication, visible window, spacing sweep, band and distance. It also prints the page's design tables to the Command Window. |
| `audio_beamforming_sim.m` | Steers an audio file through the array, measures intensity (W/m², L_I, SPL) on an arc at the far-field distance, and plays what a listener at any angle would hear. |

## Run

```matlab
cd simulation
beamforming_physics_explorer
audio_beamforming_sim('path/to/song.wav')   % no argument: pick a file; 'demo': MATLAB's Handel clip
```

## Notes on the audio script

- **Far-field distance:** `2L²/λ`, taken at the frequency below which 99 % of the audio's
  energy lies, and never closer than `2L`.
- **Intensity:** `I = p_rms² / (ρc)`. This plane-wave relation holds because the listeners
  are in the far field.
- **Absolute scale:** the levels assume one speaker produces 80 dB SPL at 1 m (`SPL1m` near
  the top of the file). Set it to your driver's real figure; every level shifts with it.
- **Steered band:** results are reported for the whole audio and for the band the array can
  steer (`c/(Nd)` up to where grating lobes enter), because below about 1.1 kHz the array
  cannot form a beam.

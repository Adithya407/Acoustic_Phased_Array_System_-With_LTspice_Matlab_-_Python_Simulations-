# RP2040 True-Time-Delay Audio Phased Array Beamformer

A 6-element speaker array driven by an RP2040 microcontroller, designed to quantitatively benchmark true-time-delay (TTD) beam steering against phase-only steering across the audible frequency band. This project characterizes both the TTD-vs-phase-only performance gap and how much of the ideal continuous-delay advantage survives when delays are quantized to discrete samples on real embedded hardware.

---

## Motivation

Phased arrays steer radiated energy by controlling the relative timing or phase of signals fed to each element. In narrowband RF systems, a simple per-element phase shift suffices because the signal occupies a small fractional bandwidth. Audio, however, spans roughly three decades (20 Hz – 20 kHz), making it inherently wideband. A fixed phase offset that correctly steers a 1 kHz tone will mis-steer a 4 kHz tone — a phenomenon called **beam squint**. True time delay eliminates beam squint in principle, since a constant group delay shifts all frequency components by the same spatial angle. But on a low-cost microcontroller the available delay is quantized to the sample period (e.g., ~22.7 µs at 44.1 kHz), introducing its own steering errors. No published work on low-cost MCU-based audio arrays has quantified the three-way gap between ideal continuous-delay TTD, sample-quantized TTD, and phase-only steering. This project fills that gap.

## Research Questions

1. **TTD vs. phase-only:** How much does true-time-delay steering outperform phase-only steering in main-lobe consistency and sidelobe suppression across the audio band on the same hardware?
2. **Ideal vs. real TTD:** How closely does sample-quantized TTD (limited by a 44.1 kHz sample rate) approach the ideal continuous-delay TTD ceiling, and at what frequencies and steering angles does the quantization penalty become significant?
3. **Simulation-to-hardware fidelity:** Can a MATLAB/Simulink simulation-first workflow accurately predict measured beam patterns from a physical RP2040 array?

## Three-Condition Benchmarking Framework

The core experimental methodology compares three steering conditions on the same 6-element linear array, using identical element spacing, amplification, and measurement environment:

| Condition | Delay Mechanism | Resolution | Expected Behavior |
|---|---|---|---|
| **Ideal TTD** (simulation ceiling) | Continuous, arbitrary-precision delay | Infinite | Frequency-invariant steering; beam squint = 0 |
| **Hardware TTD** (RP2040) | Sample-domain integer-delay buffer | 1 / f_s ≈ 22.7 µs | Near-ideal at low frequencies; quantization-limited at high frequencies and steep angles |
| **Phase-only** (control) | Per-element phase rotation at a design frequency | Continuous phase, single-frequency optimum | Correct at the design frequency; increasing squint away from it |

## System Architecture

### Hardware

- **Microcontroller:** Raspberry Pi RP2040 (dual Cortex-M0+ at 133 MHz)
  - Programmable I/O (PIO) state machines for deterministic, jitter-free sample output
  - DMA channels for zero-CPU-overhead data transfer between memory and peripherals
- **Speaker elements:** 6 equally spaced full-range drivers in a uniform linear array
- **DAC interface:** I2S or parallel DAC output per channel, clocked at 44.1 kHz
- **Amplification:** Per-channel speaker amplifier stages with low-pass reconstruction filters to suppress DAC quantization noise
- **Input:** Standard line-level audio input, biased and amplified to span the ADC range
- **Steering control:** Potentiometer or serial interface to set the desired beam angle in real time

### Signal Flow

```
Audio Source → ADC → RP2040 Sample Buffer → Per-Channel Delay Line → DAC × 6 → Amplifiers → Speakers
                                                    ↑
                                         Steering Angle Input
```

Each channel's delay line is a circular buffer in RAM. The steering-angle input sets the inter-element delay Δτ, which determines the progressive delay applied to successive speakers. For TTD mode, each channel's read pointer is offset by an integer number of samples corresponding to the required delay. For phase-only mode, the same hardware applies a frequency-dependent phase rotation computed at a single design frequency.

### Software / Firmware

- **Real-time ISR or DMA pipeline:** Samples captured and played back at 44.1 kHz, satisfying the Nyquist criterion for the ~20 kHz upper bound of human hearing
- **Delay computation:** Main loop reads the steering-angle input, computes the per-element delay in samples, and updates the buffer read offsets — all between ISR deadlines
- **MATLAB/Simulink model:** Full array simulation (element pattern, array factor, steering response) used to predict beam patterns before hardware fabrication; simulation parameters match physical geometry exactly

## Prior Work and Literature Context

This project builds on and extends two threads of prior work:

### Beamformer Theory (not embedded-hardware-focused)

- **Luo (2024)** — Constant directivity loudspeaker beamforming with frequency-regularized Rayleigh quotient optimization for heterogeneous speaker arrays
- **Zhang, Xiang & Zhu (2024)** — Steerable frequency-invariant differential beamforming for loudspeaker line arrays (300 Hz – 4 kHz) using Jacobi–Anger modal matching; validated in anechoic chamber (Sensors 24, 6277)
- **Pope et al. (2024)** — Phased array systems design considerations and demonstration for RF applications, covering analog/digital/hybrid architectures, beam-weight synthesis, and calibration

These works establish the theoretical framework for wideband beam steering and frequency-invariant pattern design, but target full-size or RF-domain arrays — not resource-constrained embedded audio hardware.

### MCU-Driven Audio Arrays (hobbyist / course-level)

- **Szoka & Jackson (2012)** — 12-element ATmega644 speaker array sampled at 44.1 kHz using true time delay (group delay in the sample domain); closest direct hardware precedent. They explicitly considered and rejected FFT-based phase steering as too computationally expensive for real-time MCU execution. (Cornell ECE 4760 Final Project)
- **Grassin (2020)** — 12-speaker Arduino Nano array using phase and amplitude steering; demonstrated measured polar patterns at a single tone (~750 Hz–1 kHz) with open-source hardware and Python code generation. (Charles' Labs)

Neither precedent performed a quantitative multi-frequency comparison of TTD vs. phase-only steering, nor characterized the sample-quantization penalty of the delay implementation.

### What This Project Adds

- The **first published three-condition benchmark** (ideal TTD ceiling vs. hardware TTD vs. phase-only) for a low-cost MCU audio array
- **Quantitative characterization** of the sample-quantization gap — how much of the ideal continuous-delay TTD advantage is lost at the RP2040's 44.1 kHz sample rate
- A **simulation-first, hardware-validated workflow** coupling MATLAB/Simulink modeling with physical RP2040 measurements

## Project Structure

```
├── firmware/              # RP2040 C/C++ firmware (PIO programs, DMA config, delay-line logic)
├── simulation/            # MATLAB/Simulink array models and beam pattern scripts
├── hardware/              # KiCad schematics and PCB layouts for amplifier and DAC boards
├── measurements/          # Captured polar-pattern data and analysis notebooks
├── docs/                  # Presentation slides, project reports, and reference PDFs
│   ├── references/        # Literature PDFs and annotated sources
│   └── presentation/      # R1_Presentation.pptx and supporting materials
└── README.md
```

## Key Design Parameters

| Parameter | Value | Rationale |
|---|---|---|
| Number of elements (N) | 6 | Balances cost, wiring complexity, and sufficient array gain for proof-of-concept |
| Sample rate (f_s) | 44.1 kHz | Standard audio rate; Nyquist-compliant for full audible band |
| Delay resolution | 1 / 44100 ≈ 22.7 µs | Inherent sample-period quantization; sets the minimum resolvable inter-element delay |
| MCU clock | 133 MHz | RP2040 default; provides ample headroom for 6-channel ISR within the 22.7 µs budget |
| Target steering range | ±55° from broadside | Matches the angular range where a 6-element linear array maintains useful directivity |

## Future Scope

- **Increased element count:** Scaling to 12+ elements for narrower main lobes and deeper nulls, following the precedent set by Szoka & Jackson (12 elements) and Grassin (12 elements)
- **2D planar array:** Extending from a 1D linear array to a 2D grid for azimuth + elevation steering
- **Ultrasound-modulated audio (parametric array loudspeaker):** Exploiting the Berktay self-demodulation effect to generate highly directional audible sound from an ultrasonic carrier — requires predistortion of the modulating signal and would target Open Lab II hardware with ultrasonic transducers
- **Higher sample rates:** Moving to 96 kHz or 192 kHz to halve or quarter the delay quantization step, directly reducing the ideal-vs-real TTD gap
- **Adaptive beamforming:** Implementing real-time beam tracking via microphone feedback and direction-of-arrival estimation

## References

1. Y. Luo, "Constant Directivity Loudspeaker Beamforming," Amazon Inc., 2024.
2. L. Pope et al., "Phased Array Systems: Design Considerations & System Demonstration," in *Proc. IEEE Int. Symp. Phased Array Syst. & Technol.*, 2024.
3. Y. Zhang, Q. Xiang, and Q. Zhu, "Design of Differential Loudspeaker Line Array for Steerable Frequency-Invariant Beamforming," *Sensors*, vol. 24, no. 19, art. 6277, 2024. DOI: [10.3390/s24196277](https://doi.org/10.3390/s24196277)
4. E. Szoka and T. Jackson, "Phased Array Speaker System," ECE 4760 Final Project, Cornell University, Spring 2012. [Online]. Available: [https://people.ece.cornell.edu/land/courses/ece4760/FinalProjects/s2012/tcj26_ecs227/tcj26_ecs227/index.html](https://people.ece.cornell.edu/land/courses/ece4760/FinalProjects/s2012/tcj26_ecs227/tcj26_ecs227/index.html)
5. C. Grassin, "Acoustic Beamsteering with a Speaker Array," Charles' Labs, Mar. 2020. [Online]. Available: [https://charleslabs.fr/en/project-Acoustic+beamsteering+with+a+speaker+array](https://charleslabs.fr/en/project-Acoustic+beamsteering+with+a+speaker+array)

## License

This project is developed as part of an academic capstone / open lab research effort. See individual subdirectories for applicable licenses on third-party components.

---

*Built with an RP2040, six speakers, and a stubborn refusal to let beam squint go unquantified.*

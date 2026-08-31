# Reference Review — RP2040 True-Time-Delay Audio Phased Array Beamformer

Scope: `README.md` plus every file in `docs/references/` (9 files). Each PDF/HTML was opened and checked against the project's actual research questions, not just its title.

## 1. Project snapshot (from the README)

- **What it is:** a 6-element linear speaker array driven by an RP2040, built to quantitatively benchmark **true-time-delay (TTD) steering** against **phase-only steering** across the audible band (20 Hz–20 kHz).
- **The gap it fills:** no published low-cost-MCU audio array has quantified the three-way relationship between (1) ideal continuous-delay TTD, (2) sample-quantized TTD (limited to 1/44.1 kHz ≈ 22.7 µs steps), and (3) phase-only steering (which suffers **beam squint** off its design frequency).
- **Method:** MATLAB/Simulink array-factor simulation used to predict beam patterns before build, then validated against measured polar patterns from physical RP2040 hardware. Circuits (input amp, DAC reconstruction filter, output amp) are simulated in LTspice; PCB in KiCad.
- **Future scope named explicitly in the README:** more elements, a 2D planar array, adaptive/mic-feedback steering, higher sample rates, and — notably — a parametric array loudspeaker (ultrasonic self-demodulation) extension for "Open Lab II."

This framing is what the relevance calls below are measured against — not "is this paper about loudspeakers," but "does it inform TTD-vs-phase-only steering, sample-quantized delay, MCU implementation, or the LTspice-simulated analog chain."

## 2. How the existing references stack up

The README already cites 5 of the 9 files in `docs/references/`. The other 4 are sitting in the folder uncited. Reading all 9 confirms the README's own picks are sound, but reshuffles where the other 4 belong.

| # | File | Actual paper | In README's reference list? | Verdict |
|---|------|-------------|:---:|---|
| 1 | `ECE 4760 Final Project_ Phased Array Speaker System.html` | Szoka & Jackson, *Phased Array Speaker System*, Cornell ECE 4760, 2012 | Yes (#4) | **Core** |
| 2 | `Charles' Labs - Acoustic beamsteering with a speaker array.html` | Grassin, *Acoustic Beamsteering with a Speaker Array*, 2020 | Yes (#5) | **Core** |
| 3 | `AudioBeamSteeringWithPhasedArrayMethodUsingArduinoDueMicrocontrollerRG.pdf` | Gaviola, Rivai & Kusuma, *Audio Beam Steering With Phased Array Method Using Arduino Due Microcontroller*, ICOIACT 2018 | **No** | **Core — promote to citation** |
| 4 | `sensors-24-06277.pdf` | Zhang, Xiang & Zhu, *Design of Differential Loudspeaker Line Array for Steerable Frequency-Invariant Beamforming*, Sensors 24(19):6277, 2024 | Yes (#3) | Supporting |
| 5 | `Phased_Array_Systems__Design_Considerations_amp_System_Demonstration.pdf` | Pope, Tang, Zheng & Zhang, *Phased Array Systems – Design Considerations & System Demonstration*, IEEE ARRAY 2024 | Yes (#2) | Supporting |
| 6 | `Constant Directivity Loudspeaker Beamforming-with-annotations.pdf` | Luo, *Constant Directivity Loudspeaker Beamforming*, Amazon Inc., 2024 | Yes (#1) | Supporting (weakest of the three) |
| 7 | `The feasibility of sound zone control using an array of parametric array loudspeakers-with-annotations.pdf` | Zhuang, Zhong & Lu, arXiv:2407.10054, 2024 | No | **Future-scope only** |
| 8 | `Loudspeaker Beamforming to Enhance Speech Recognition Performance of Voice Driven Applications-with-annotations.pdf` | de Groot, Karslioglu, Scharenborg & Martinez, arXiv:2501.08104, 2025 | No | **Ignore** |
| 9 | `Optimal model-based beamforming and independent steering for spherical loudspeaker arrays-with-annotations.pdf` | Rafaely & Khaykin, IEEE TASLP, 2011 (arXiv:2310.04202) | No | **Ignore** |

### Core — direct hardware/system precedents

**Szoka & Jackson (2012), Cornell ECE 4760** and **Grassin (2020), Charles' Labs** are correctly the anchor citations. Both are MCU-driven, low-cost, delay/phase-steered linear speaker arrays sampled near 44.1 kHz — the exact lineage this project extends (Szoka & Jackson even explicitly rejected FFT-based phase steering as too expensive for real-time MCU execution, which is precisely the "phase-only" arm this project now re-examines properly). Keep both as-is.

**Gaviola, Rivai & Kusuma (2018)** is currently unused but shouldn't be. Confirmed by reading it: a 4-speaker linear array, Arduino Due-generated delayed/PWM-modulated signals, GUI-selected steering angle, and the same grating-lobe spacing condition (`d ≤ λ/(1+sinθmax)`) this project will need for its own 6-element spacing. It's a third, peer-reviewed (ICOIACT conference) example in the README's own "MCU-Driven Audio Arrays" bucket, sitting right next to the two it already cites. **Recommend adding it as reference #6 in the README**, not leaving it as an orphaned PDF.

### Supporting — theory/methodology background (README's own framing holds up)

Reading all three confirms the README's own line — "these works establish the theoretical framework... but target full-size or RF-domain arrays, not resource-constrained embedded audio hardware" — is accurate, with one nuance worth calling out:

- **Zhang, Xiang & Zhu (Sensors 2024)** is the most technique-relevant of the three: same array *shape* (a loudspeaker line array), and it directly targets *steerable, frequency-invariant* beampatterns — i.e., avoiding the frequency-dependence that causes beam squint, just via differential-array signal processing instead of true time delay. Worth a sentence in the report/paper contrasting the two routes to frequency-invariance.
- **Pope et al. (IEEE ARRAY 2024)** is RF hardware, but its treatment of "limitations imposed by quantization and root-mean-square errors" in a phased array is the closest existing analogue — just in the phase/amplitude-quantization domain — to this project's own core question about *delay*-quantization. Worth citing specifically for that parallel, not for RF implementation detail.
- **Luo (Amazon Inc., 2024)** is the weakest fit of the three: it optimizes static per-transducer directivity/crossover weighting (Rayleigh-quotient regularization) for heterogeneous multi-way speakers, with no steering or delay component at all. Keep it (the README's framing is defensible), but it's the first to cut if the reference list needs trimming.

### Future-scope only — don't mix into the core TTD citations

**Zhuang, Zhong & Lu (2024)**, on sound-zone control with an array of parametric array loudspeakers, is a strong match — but for the README's *Future Scope* bullet on "ultrasound-modulated audio (parametric array loudspeaker)... exploiting the Berktay self-demodulation effect," not for the current TTD-vs-phase-only benchmark. It models exactly that nonlinear self-demodulation physics (via the Westervelt equation) for an *array* of parametric emitters. **Recommend keeping it, but citing it separately under a "Future Work" heading** rather than alongside the core beamforming-theory references — as written now it reads like current-scope background, which it isn't.

### Ignore / deprioritize for this project

- **de Groot et al. (2025)** solves a *different* problem: it uses loudspeakers to carve out a low-acoustic-energy "quiet zone" around a device's own microphones so automatic speech recognition works better (loudspeaker "spotforming"). That's near-field acoustic-contrast control aimed at *minimizing* energy in a region, not far-field intensity steering aimed at *directing* it — no TTD, no sample-quantized delay, no MCU implementation. Unless the project pivots toward sound-zone/interference-cancellation work, this one doesn't inform anything in the current README.
- **Rafaely & Khaykin (2011)** is about loudspeakers mounted on a rigid *sphere*, steered via spherical-harmonics decomposition — a fundamentally different geometry and math framework from a 6-element uniform *linear* array. Even the README's own "2D planar array" future item is a closer match than a sphere. Low value here; only reconsider if the project later heads toward 3D/spherical geometries specifically (it currently doesn't).

## 3. Gaps: what's missing that the project actually needs

None of the 9 files address two things the README treats as central:

1. **A direct TTD-vs-phase-shift / beam-squint comparison** — the project's headline research question has no existing reference that tackles it quantitatively (Szoka/Jackson and Grassin each *used* one method; neither compared both).
2. **The LTspice-simulated analog chain** — input amp, anti-alias/reconstruction filtering, output power amp. Despite being half the repo's name, zero of the 9 references touch circuit-level design.

## 4. Recommended additional references

### A. Closing the core TTD-vs-phase-only / beam-squint gap

- **C. Bakhos, "Steering Sound with a Phased Speaker Array," M.Eng. report, Cornell University.** [PDF](https://vanhunteradams.com/6930/Chris_Bakhos.pdf) — Confirmed by reading it: an **8-speaker array on a Raspberry Pi Pico (RP2040) with MCP4822 DACs**, using **phase-only** steering (not TTD) and MATLAB's Phased Array Toolbox for design parameters. This is the closest same-microcontroller-family precedent for the "phase-only" arm of the three-way comparison — arguably a more direct comparator than either of the two currently cited hardware precedents, since it's phase-only where they're both TTD. High priority.
- **M. Q. Abdalrazak, A. H. Majeed, R. A. Abd-Alhameed, "A Critical Examination of the Beam-Squinting Effect in Broadband Mobile Communication: Review Paper," *Electronics*, vol. 12, no. 2, art. 400, 2023.** DOI: [10.3390/electronics12020400](https://doi.org/10.3390/electronics12020400) — Confirmed via abstract: a peer-reviewed review specifically of beam squint in broadband/wideband arrays, including TTD as a mitigation. Directly supports the README's motivation paragraph with a citable, rigorous source instead of an assertion.
- **Analog Devices, "Phased Array Antenna Patterns—Part 2: Grating Lobes and Beam Squint," Analog Dialogue.** [Link](https://www.analog.com/en/resources/analog-dialogue/articles/phased-array-antenna-patterns-part2.html) — Accessible, worked-math tutorial on exactly the grating-lobe and beam-squint mechanics the project studies; a good complement to Pope et al. (also Analog Devices-affiliated) already in the list.

### B. Closing the sample-quantized-delay gap

- **T. I. Laakso, V. Välimäki, M. Karjalainen, U. K. Laine, "Splitting the Unit Delay: Tools for Fractional Delay Filter Design," *IEEE Signal Processing Magazine*, vol. 13, no. 1, pp. 30–60, 1996.** DOI: [10.1109/79.482137](https://ieeexplore.ieee.org/document/482137/) — The canonical fractional-delay-filter paper. Directly relevant to Research Question 2 (ideal vs. sample-quantized TTD): fractional-delay interpolation is the standard way to push resolution below the raw 1/44.1 kHz sample period, which is exactly the quantization penalty the project characterizes. Strong candidate even just as a "future mitigation" citation.

### C. RP2040 implementation references

- **Raspberry Pi Ltd., RP2040 Datasheet and "Hardware Design with RP2040."** [PDF](https://datasheets.raspberrypi.com/rp2040/hardware-design-with-rp2040.pdf) — Primary hardware documentation for the PIO state machines and DMA channels the README's firmware section already describes; currently uncited anywhere.

### D. Simulation-methodology reference

- **MathWorks, Phased Array System Toolbox documentation.** [Link](https://www.mathworks.com/help/phased/) — Both Pope et al. (already cited) and the Bakhos report (recommended above) build on this toolbox for beam-weight synthesis / design parameters. Worth citing directly since the README's "MATLAB/Simulink model" is the project's own validation backbone.

### E. Closing the LTspice/analog-chain gap (currently zero references)

- **W. Kester / Analog Devices, MT-017 Tutorial, "Oversampling Interpolating DACs."** [PDF](https://www.analog.com/media/en/training-seminars/tutorials/MT-017.pdf) — Standard reference for DAC reconstruction-filter design and quantization noise, directly relevant to the README's "low-pass reconstruction filters to suppress DAC quantization noise."
- **Texas Instruments, *Op Amps for Everyone*, Ch. 16 "Active Filter Design Techniques," Literature No. SLOA088** (excerpted from the full design guide, Lit. No. SLOD006). [Mirror PDF](https://www.changpuak.ch/electronics/downloads/sloa088.pdf) — Standard Sallen-Key active-filter design reference; matches the Sallen-Key Butterworth low-pass topology already used in the amplifier/DAC output stage design.

## 5. Suggested updated reference list for the README

Keeping the README's own IEEE-ish style and adding the promoted/new items (future-scope item separated out):

```
References
1. Y. Luo, "Constant Directivity Loudspeaker Beamforming," Amazon Inc., 2024.
2. L. Pope et al., "Phased Array Systems: Design Considerations & System Demonstration,"
   in Proc. IEEE Int. Symp. Phased Array Syst. & Technol., 2024.
3. Y. Zhang, Q. Xiang, and Q. Zhu, "Design of Differential Loudspeaker Line Array for
   Steerable Frequency-Invariant Beamforming," Sensors, vol. 24, no. 19, art. 6277, 2024.
   DOI: 10.3390/s24196277
4. E. Szoka and T. Jackson, "Phased Array Speaker System," ECE 4760 Final Project,
   Cornell University, Spring 2012.
5. C. Grassin, "Acoustic Beamsteering with a Speaker Array," Charles' Labs, Mar. 2020.
6. A. Da Silva Gaviola, M. Rivai, and H. Kusuma, "Audio Beam Steering With Phased Array
   Method Using Arduino Due Microcontroller," in Proc. 2018 Int. Conf. Inf. Commun.
   Technol. (ICOIACT), 2018, pp. 597-601.
7. C. Bakhos, "Steering Sound with a Phased Speaker Array," M.Eng. report, Cornell Univ.
   [Online]. Available: https://vanhunteradams.com/6930/Chris_Bakhos.pdf
8. M. Q. Abdalrazak, A. H. Majeed, and R. A. Abd-Alhameed, "A Critical Examination of
   the Beam-Squinting Effect in Broadband Mobile Communication: Review Paper,"
   Electronics, vol. 12, no. 2, art. 400, 2023. DOI: 10.3390/electronics12020400
9. T. I. Laakso, V. Valimaki, M. Karjalainen, and U. K. Laine, "Splitting the Unit Delay:
   Tools for Fractional Delay Filter Design," IEEE Signal Process. Mag., vol. 13, no. 1,
   pp. 30-60, 1996.
10. Raspberry Pi Ltd., "Hardware Design with RP2040." [Online]. Available:
    https://datasheets.raspberrypi.com/rp2040/hardware-design-with-rp2040.pdf
11. W. Kester, "Oversampling Interpolating DACs," Analog Devices MT-017 Tutorial.
12. Texas Instruments, "Active Filter Design Techniques," Op Amps for Everyone,
    Lit. No. SLOA088.

Future Work
13. T. Zhuang, J.-X. Zhong, and J. Lu, "The Feasibility of Sound Zone Control Using an
    Array of Parametric Array Loudspeakers," arXiv:2407.10054, 2024.
```

`docs/references/Loudspeaker Beamforming to Enhance Speech Recognition...pdf` and `docs/references/Optimal model-based beamforming... spherical loudspeaker arrays...pdf` are left out of both lists — recommend leaving them in the folder (no need to delete) but not citing them in the report/paper.

## 6. Notes on method

- One additional lead — Matt Longbrake's "True Time-Delay Beamsteering for Radar" (Wright State University) — turned up in search but its host redirected in a loop and couldn't be fetched to confirm content, so it's deliberately left out rather than cited unverified.
- Everything above was read directly (title/abstract/intro pages of all 7 PDFs, extracted text of both saved HTML pages) rather than inferred from filenames.

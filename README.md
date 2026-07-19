# Acoustic Phased-Array System

A 6-element acoustic phased array that steers the direction of maximum sound intensity in real time using true time-delay beamforming on an RP2040 microcontroller. Built as an Open Laboratory I project (Dept. of ECE, Amrita Vishwa Vidyapeetham, Coimbatore), 2026–27 Odd semester.

## Overview

Traditional beam steering shifts the phase of a single frequency to redirect a wavefront, but that only works correctly at the one frequency it was tuned for. This project instead applies a **true time delay** between speaker channels, which — unlike single-frequency phase shifting — keeps the beam direction essentially constant across a wide audio band. The steering math is derived from the standard N-element array / diffraction-grating model, converted from a phase term (Φ) to a frequency-independent delay term (t_d):

```
θ = sin⁻¹( -v_s / (2πd) · t_d )
```

where `v_s` is the speed of sound and `d` is the inter-speaker spacing. This relationship is implemented in firmware and cross-checked against a MATLAB simulation of the array's far-field intensity pattern.

## System Architecture

### Hardware signal chain

```
Standard Audio Input → Input Buffer / Level Shifter → TI ADC
                                                          ↓
                          Speaker Amp (×6) ← MCP4728 DAC ← RP2040 Microcontroller
```

- Audio input is re-biased and amplified from a ±1 V line-level signal to the 0–5 V range needed by the ADC.
- The RP2040 reads the digitized input, computes the per-channel time-delay values for the target steering angle, and writes each channel out to a pair of MCP4728 DACs.
- Each DAC output passes through a speaker amplifier stage that low-pass filters (removing DAC quantization noise) and buffers the signal (to drive the 8 Ω speaker load) before reaching the speaker.

### Firmware design

- **Core 0** samples a potentiometer (used as the steering-angle user interface), computes the corresponding per-channel time delays, and writes them into a double buffer.
- **Core 1** is triggered by a 44.1 kHz DMA timer, swaps to the current buffer, and streams the delayed samples out to the DACs over two parallel high-speed I²C (PIO) channels — 4 channels per MCP4728, 6 of the available 8 channels used.
- Double buffering with a buffer-swap sync between cores keeps audio capture/playback glitch-free at the 44.1 kHz interrupt rate.

## Hardware

| Component | Spec | Qty |
|---|---|---|
| Microcontroller | Raspberry Pi RP2040 | 1 |
| DAC | MCP4728 (I²C, quad-channel) | 2 |
| Speaker | PUI Audio AS07108PO-3-R, 8 Ω, 86 dB sensitivity, 100 Hz–20 kHz | 6 |
| ADC | Texas Instruments ADC | 1 |
| Op-amps | Quad op-amp (input buffer / re-bias stage) | 3 |
| Transistors / MOSFETs | NPN / NMOS (amp/buffer stages) | 12 each |
| Potentiometer | 10 kΩ (steering angle UI) | 1 |
| Audio jack | 3.5 mm | 1 |

The speaker was selected from four candidates (Dayton Audio CE36-8, PUI Audio AS03208MS-3-R, Challenge Electronics CS32-03W23-16-1X, PUI Audio AS07108PO-3-R) as the only option meeting the 86 dB sensitivity target exactly, with full datasheet documentation and extended low-frequency response for better full-range array reproduction.

## Why a microcontroller (not discrete hardware)

Generating a live, continuously-adjustable per-channel time delay against a live-sampled waveform is fundamentally an arithmetic/sequencing task rather than a fixed signal-conditioning one. A discrete alternative (e.g., bucket-brigade delay-line ICs with separate clocking per tap) doesn't add meaningful hardware design value — it just swaps one IC-based subsystem for another — and introduces companding noise and clock-feedthrough distortion that works against the array's audio quality goals.

## Status / Roadmap

- [x] Proposal accepted — Open Laboratory I, Review Zero
- [ ] MATLAB verification of the frequency-independence of the time-delay steering model
- [ ] Hardware bring-up (ADC/DAC signal chain, amplifier stages)
- [ ] RP2040 dual-core firmware (sampling, delay computation, DMA/PIO output)
- [ ] Full 6-speaker array integration and beam-pattern testing
- [ ] Future scope: ultrasound-modulated audio (parametric speaker / "sound from ultrasound") extension
- [ ] Open Laboratory II: convert proposal into a finished product

## References

1. Y. Luo, "Constant Directivity Loudspeaker Beamforming," 2024. arXiv:2407.01860v3.
2. C. Pope, H. Tang, B. Zheng and H. Zhang, "Phased Array Systems – Design Considerations & System Demonstration," 2024 IEEE International Symposium on Phased Array Systems and Technology (ARRAY), Boston, MA, USA, 2024, pp. 1-8, doi: 10.1109/ARRAY58370.2024.10880346.
3. B. Rafaely and D. Khaykin, "Optimal model-based beamforming and independent steering for spherical loudspeaker arrays," IEEE Transactions on Audio, Speech, and Language Processing, 2011. arXiv:2310.04202.
4. Zhuang, T., Zhong, J.-X., & Lu, J. (2024). The feasibility of sound zone control using an array of parametric array loudspeakers. arXiv preprint arXiv:2407.10054.
5. D. de Groot, B. Karslioglu, O. Scharenborg, and J. Martinez, "Loudspeaker Beamforming to Enhance Speech Recognition Performance of Voice Driven Applications," arXiv:2501.08104 [eess.AS], Jan. 2025.
6. A. Da Silva Gaviola, M. Rivai and H. Kusuma, "Audio beam steering with phased array method using Arduino Due Microcontroller," 2018 International Conference on Information and Communications Technology (ICOIACT), Yogyakarta, Indonesia, 2018, pp. 597-600, doi: 10.1109/ICOIACT.2018.8350683.

Hardware reference design: *Phased Array Speaker System* — Edward Szoka & Tom Jackson, Cornell ECE 4760.

## Team

Batch 1, Open Laboratory I & II, Dept. of ECE, Amrita Vishwa Vidyapeetham, Coimbatore — 4 members.

## License

TBD.

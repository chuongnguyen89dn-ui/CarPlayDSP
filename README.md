# CarPlayDSP

Rootless iOS 16 / Dopamine CarPlay DSP research POC.

## POC 0.0.1
- Injects into mediaserverd.
- Attempts an AudioUnitRender hook.
- Test filter: peaking EQ 1 kHz, Q 1.0, -15 dB.
- This build is intentionally a feasibility probe, not yet cabin Auto-Tune.
- The runtime hook must be verified on-device before measurement/optimizer work is added.

## Runtime verification
Connect CarPlay, play music, then compare audio with tweak installed vs disabled. Capture logs for subsystem com.anhchuong.carplaydsp. The test filter is deliberately strong.

## Safety scope
The final implementation must identify media/CarPlay streams before processing so calls, Siri and navigation prompts are not modified. POC 0.0.1 does not claim that isolation yet.

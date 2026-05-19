# Seamless audio loop investigation

## Problem

Audible seam when ohm loop sounds (`ohm_inhale.ogg`, `ohm_exhale.ogg`, `ohm_hold.ogg`) cycle back to the beginning via `LoopMode.one`.

## Root causes (in order of likelihood)

### 1. OGG Vorbis encoder delay (most likely)

Ogg Vorbis encodes in 1024-sample blocks. The encoder prepends "priming" silence (~5–20ms) to the beginning of the file. At the loop point ExoPlayer seeks back to position 0, replaying that priming silence — creating an audible gap. WAV has no encoder delay and does not have this issue.

### 2. Waveform discontinuity at loop point

If the amplitude at the end of the file does not match the amplitude at the beginning, the instantaneous jump creates a click. The ohm files likely have a natural decay at the end (amplitude → 0) while the beginning starts from silence or a different phase — textbook discontinuity.

### 3. ExoPlayer `REPEAT_MODE_ONE` gap

Even with perfect files, `LoopMode.one` maps to ExoPlayer's `REPEAT_MODE_ONE` which internally does a seek to position 0 when the file ends. This seek has latency (typically a few ms) that can create a brief silence. This is separate from encoder delay.

## Solutions

### A. Switch loop files to WAV (recommended short-term)

We now preload both loop players at `initialize()` — the 4s WAV load penalty is paid once at session start, not per phase change. WAV has no encoder delay, so `LoopMode.one` on WAV is as close to gapless as ExoPlayer supports. Still requires fixing the waveform discontinuity (see solution C).

Tick files (`tick_clock.ogg`, `tick_heartbeat.ogg`) can stay OGG — they are short one-shots, not looped.

### B. Gapless playlist instead of LoopMode.one

Instead of looping a single file, load the same file N times into the playlist per player:

```dart
final sources = _phaseOrder.map((p) {
  final asset = AudioSource.asset(_phaseAssets[p]!);
  // 8 repetitions × 4s = 32s — enough for any session phase
  return List.generate(8, (_) => asset);
}).expand((x) => x).toList();
```

just_audio uses ExoPlayer's gapless inter-item transition, which is a different (and potentially better) code path than `REPEAT_MODE_ONE`. However this complicates `seek(index: i)` since indices no longer map 1:1 to phases.

Simpler variant: per player, load one phase 8 times as its own playlist, switch playlists on phase change. But this requires per-player playlist management.

### C. Fix audio files to be true seamless loops (required regardless of A or B)

The audio content itself must be designed for looping:
- Trim silence at the start and end
- Ensure the waveform starts and ends at a zero-crossing (zero amplitude)
- The sustained portion of the sound (the "body") should flow from end back to beginning without amplitude discontinuity
- In Audacity: Effect → Crossfade Clips at the loop boundary, or manually match RMS level at start/end

Without fixing the files, no code solution fully eliminates the seam.

### D. OGG loop tags — NOT viable

Vorbis comment tags `LOOPSTART`/`LOOPEND` exist in the spec but ExoPlayer does not support them. Skip.

## Recommendation

1. Fix the audio files (C) — this is required no matter what else we do.
2. Switch loop files to WAV (A) — eliminates encoder delay, simplest code change (just rename extensions back to `.wav` in `_phaseAssets`).
3. If WAV file sizes become a concern later, revisit the gapless playlist approach (B).

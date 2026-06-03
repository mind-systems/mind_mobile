# Mind Mobile

> Guided breathing and meditation with real-time neurofeedback.

Flutter app for iOS and Android. Users run breathing exercises and meditation sessions; a Neiry BCI headset streams EEG, heart rate, and motion data to the server where it is correlated with session activity.

## Key Features

- **Guided breathing sessions** — configurable exercises (inhale / hold / exhale / rest phases), phase-morphing shape animation, crossfade audio
- **Heart-rate tick source** — drive session timing from live RR intervals; auto-falls back to the wall-clock timer when signal is lost
- **BCI device pairing** — scan, connect, impedance check, and calibrate a Neiry headset; calibration cached per serial and auto-restored on reconnect
- **Biometric streaming** — HR, RR, EEG bands, emotions, and motion streamed to the server, gated by the active session window
- **Meditation sessions** — static pose list with session lifecycle tracking and biometric correlation
- **Offline-first sync** — sessions persisted via Drift (SQLite), synced via gRPC with a replay buffer on reconnect

## Setup

See [README_SETUP.md](README_SETUP.md) for environment config, keystores, and run commands.

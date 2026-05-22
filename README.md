<h1><img src="assets/campfire.png" width="36" align="absmiddle">&nbsp;macos-mic-keepwarm</h1>

[![Apple Feedback](https://img.shields.io/badge/Apple_Feedback-Submitted_Feb_2026-orange)](APPLE_FEEDBACK.md)

Fix the 2-5 second push-to-talk activation delay on macOS.

If you use voice transcription apps like SuperWhisper, WhisperFlow, Wispr Flow, macOS Dictation, or any push-to-talk tool and experience a delay before recording starts, especially with AirPods or Bluetooth audio, this is for you.

## The Problem

Two things cause the push-to-talk delay on Apple Silicon Macs (M1/M2/M3/M4):

**1. Microphone hardware sleep.** When no app is actively using the mic, macOS powers down the hardware. The next capture start takes 2-5 seconds before audio samples arrive. If you use the mic again within ~30 seconds, it's instant. Wait a minute, and the delay is back.

**2. Bluetooth device switching.** When AirPods or a Bluetooth headset become the active input device (connecting, reconnecting, or switching from built-in mic), Bluetooth SCO channel negotiation adds 1-3 seconds of delay regardless of whether the mic was idle. This happens on every device switch.

These compound: if the mic was idle AND a Bluetooth switch occurs, both delays stack (3-5+ seconds). The result is the first 2-5 seconds of speech lost every time you press push-to-talk after the mic has been quiet.

## What I Tried (So You Don't Have To)

I spent hours debugging this across SuperWhisper and WhisperFlow on macOS Tahoe 26.2 (M4 MacBook Air). Here's everything that did NOT fix the activation delay:

- Changing the push-to-talk hotkey (tried Function key, Option+Space, Command+Shift+R)
- Restarting `coreaudiod` and `corespeechd`
- Increasing audio buffer sizes (`HALInputBufferSizeFrames`)
- Changing audio sample rates
- Resetting CoreAudio preferences
- Disabling Continuity Camera
- Granting Input Monitoring and Accessibility permissions
- Changing microphone input sources
- Restarting the Mac
- pmset power management tweaks
- nvram boot-args (not applicable on Apple Silicon)

None of these address the hardware-level mic sleep behavior.

### Related Issue: Recording Cutoff at 5-7 Seconds

During debugging I also discovered that **Siri's Built-In Voice Trigger** (`CSBuiltInVoiceTrigger`) can interfere with push-to-talk apps, causing recordings to cut off after 5-7 seconds. If you're experiencing that issue too, disable Siri voice activation:

1. System Settings > Siri & Spotlight
2. Turn OFF "Listen for 'Siri'" / "Listen for 'Hey Siri'"
3. Turn OFF "Press function key for Siri"

### Related Issue: Virtual Audio Plugins Cause Delay

Third-party audio drivers from Teams, Zoom, and other conferencing apps (installed at `/Library/Audio/Plug-Ins/HAL/`) add significant startup latency to mic activation and cause `coreaudiod` to consume excessive CPU even when idle (measured at 36.8% CPU with plugins enabled, 0.0% after disabling). Even with the keep-warm fix, these plugins can reintroduce delay. If you have `MSTeamsAudioDevice.driver`, `ZoomAudioDevice.driver`, or similar, disable them:

```bash
sudo mv /Library/Audio/Plug-Ins/HAL/MSTeamsAudioDevice.driver /Library/Audio/Plug-Ins/HAL/MSTeamsAudioDevice.driver.disabled
sudo mv /Library/Audio/Plug-Ins/HAL/ZoomAudioDevice.driver /Library/Audio/Plug-Ins/HAL/ZoomAudioDevice.driver.disabled
sudo killall coreaudiod
```

Teams and Zoom still work for calls without these custom drivers.

## The Fix

A lightweight native Swift binary that holds the microphone input stream open. The mic hardware stays powered on and ready, so push-to-talk activation is always instant.

### Why native instead of ffmpeg?

The previous approach used ffmpeg from Homebrew. It worked, but every `brew upgrade` moves ffmpeg to a new path (e.g. `8.0.1_2` to `8.0.1_3`). macOS TCC tracks mic permissions by binary path for unsigned binaries, so every upgrade silently breaks the mic permission. You get the push-to-talk delay back with no indication why. The native binary lives at `~/.local/bin/mic-warm` with ad-hoc code signing, so the permission grant is stable. If upgrading from the ffmpeg version, the installer handles migration automatically.

### How It Works

`mic-warm` uses `AVCaptureSession` with an audio data output to hold the default microphone open. Audio samples are captured and immediately discarded. Nothing is recorded, stored, or transmitted. The only effect is that the microphone hardware stays awake and the Bluetooth audio channel stays negotiated.

When you connect or disconnect AirPods, a Bluetooth headset, or any audio device, a CoreAudio property listener fires instantly and the session restarts on the new device after a 3-second debounce window (to let Bluetooth handoffs settle).

**Bluetooth resilience:** When AirPods disconnect, `AVCaptureSession.stopRunning()` can deadlock because CoreAudio's `HALB_Guard` waits on a condition variable for the now-dead Bluetooth device. mic-warm handles this by tearing down the audio pipeline first (releasing the CMIO semaphore that coreaudiod depends on), then dispatching `stopRunning()` to a background thread so a hung Bluetooth teardown is a leaked thread, not a frozen process. A heartbeat timer detects stalled or zero-sample sessions and automatically restarts them.

- CPU usage: ~0%
- Battery impact: negligible
- Privacy: no audio is captured or stored anywhere
- Works with: built-in mic, AirPods, Bluetooth headsets, USB mics, any input device
- Instant device-change detection via CoreAudio event listener (no polling)
- Auto-recovery from Bluetooth disconnects, coreaudiod restarts, and stalled sessions
- **Bluetooth audio note:** holding the mic open on AirPods/Bluetooth keeps the connection in SCO (telephony) mode, which slightly reduces output audio quality. This is a Bluetooth protocol limitation, not specific to mic-warm. Any app using the mic causes the same behavior.

## Two Flavors

| | `mic-warm` (daemon) | `mic-warm-app` (menu bar) |
|---|---|---|
| **UI** | None | Menu bar icon with toggle |
| **Control** | Always on, `launchctl` to stop | Click to turn on/off |
| **State** | Restarts automatically | Remembers last on/off state |
| **Install** | `install.sh` (pre-built binary) | `install-local.sh` (builds from source) |

Both use the same underlying session logic. Choose the daemon if you want zero overhead and never need to toggle. Choose the menu bar app if you want to turn it off occasionally (e.g. when Bluetooth audio quality matters more than push-to-talk latency).

## Installation

### Option A — Daemon (original, pre-built)

```bash
curl -fsSL https://raw.githubusercontent.com/drewburchfield/macos-mic-keepwarm/master/install.sh | bash
```

Downloads a precompiled universal binary (ARM + Intel), installs it to `~/.local/bin/mic-warm`, and creates a LaunchAgent that:
- Starts automatically on login
- Restarts automatically if killed
- Runs silently in the background with no UI

macOS will prompt you to grant mic-warm microphone access. Go to System Settings > Privacy & Security > Microphone and allow it.

### Option B — Menu bar app (pre-built)

```bash
curl -fsSL https://raw.githubusercontent.com/mstovicek/macos-mic-keepwarm/master/install-app.sh | bash
```

Downloads the precompiled universal binary, installs it to `~/.local/bin/mic-warm-app`, and creates a LaunchAgent with the same auto-start/restart behavior as the daemon.

**Or build from source** (requires Xcode Command Line Tools — `xcode-select --install`):

```bash
git clone https://github.com/mstovicek/macos-mic-keepwarm.git
cd macos-mic-keepwarm
bash install-local.sh
```

The menu bar icon shows `mic.fill` when warm and `mic.slash.fill` when cold. Click it to toggle, or open the menu to see the current state and quit.

### Upgrade

**Daemon:** re-run `install.sh`. The script re-signs the binary and reloads the LaunchAgent. Don't replace the binary manually — macOS tracks mic permissions by code signature and will silently reject an unsigned replacement.

**Menu bar app:** re-run `install-app.sh` (or `install-local.sh` if you built from source).

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/drewburchfield/macos-mic-keepwarm/master/uninstall.sh | bash
```

Or clone the repo and run `./uninstall.sh`.

## The Orange Dot

macOS will show the orange microphone indicator dot in the menu bar, attributed to "mic-warm". This is accurate: mic-warm has the mic open. But it's not listening to you. Audio samples are captured and immediately discarded.

This is the same reason transcription apps don't solve this themselves. They should. SuperWhisper's own changelog acknowledges "handling push to talk shortcut if microphone is slow to start." The correct engineering solution is to keep the audio input stream open between recordings and use a ring buffer with lookback. When the user presses push-to-talk, start reading from the buffer, including audio captured just before the keypress. But apps don't want users seeing "SuperWhisper is using your microphone" 24/7, even though the alternative is a broken user experience.

Apple could fix this by providing a fast-wake API or a low-power standby mode for the mic hardware that doesn't trigger the orange dot. As of macOS Tahoe 26.2, no such API exists.

## Why Not Use BlackHole or a Virtual Audio Device?

You don't need one. BlackHole, Loopback, and SoundFlower create virtual audio routing devices, which adds complexity and can introduce their own latency and compatibility issues. This fix works directly with your real microphone hardware. It's simpler and has fewer things that can break.

## System Requirements

- macOS 13 Ventura, 14 Sonoma, 15 Sequoia, or 26 Tahoe
- Apple Silicon (M1/M2/M3/M4) or Intel Mac (universal binary)
- Microphone permission for mic-warm

## Testing

Run the integration test suite to verify process lifecycle, signal handling, and PID file management (targets the `mic-warm` daemon):

```bash
./test.sh
```

Device-switching tests require real audio hardware and should be done manually. For `mic-warm-app`, manually verify that the menu bar icon updates correctly when toggling and when AirPods connect or disconnect.

## Legacy Shell Script

The original `keep-mic-warm.sh` is kept as a fallback for systems where the native binary can't be used. It requires `ffmpeg` and `switchaudio-osx` from Homebrew. See the file header for details.

## License

MIT

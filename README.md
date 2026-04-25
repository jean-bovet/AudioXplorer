# AudioXplorer

AudioXplorer is a macOS sound‑analysis application originally developed by [Arizona Software](https://www.arizona-software.ch) between 2003 and 2009. It records, generates, imports and visualizes audio, and performs Fast Fourier Transform (FFT) and sonogram analysis both on recorded clips and live input.

The 2009 source tree (version 1.3.2 — Snow Leopard fix release) was modernized in 2026 to build on current Xcode and run as a notarized arm64 binary on macOS 12 and later. The application is freeware under a BSD license (relicensed in 2006).

## Download

Latest release: [AudioXplorer 1.4](https://github.com/jean-bovet/AudioXplorer/releases/latest) — signed and notarized DMG. Future updates are delivered in‑app via Sparkle.

## What it does

Two main analysis modes:

- **Static window** — record, generate or import a sound clip and analyze it offline. Each document (`.adx`) holds one or more **views** that can show:
  - Amplitude (waveform) — including a Lissajous representation of stereo data
  - FFT spectrum (with selectable windowing functions)
  - Sonogram (grayscale or color)
  - Linked views: e.g. clicking in a sonogram updates a child FFT view at the cursor position
- **Real‑time window** — live oscilloscope, spectrum and sonogram driven directly from a Core Audio input device, with optional play‑thru, full‑screen mode, and amplitude trigger.

Other features:

- Multi‑channel input (more than 2 channels) with a global channel mixer
- Sound generator (sine, cosine, square, triangle, sawtooth) with per‑channel routing
- Audio Units effects, including Music Effects, with undo on amplitude views
- Import of AIFF, WAV, MP3, MP4, SND, etc.; export of selections to AIFF or raw data
- Copy views to the pasteboard as TIFF, PDF or EPS, and a print path with custom layout
- Plug‑in architecture (Cocoa SDK) for adding effects — see `Plug-ins (AX)/`
- Localized in English, French and Italian

## Repository layout

```
main.m                        NSApplicationMain entry point
Info.plist                    Bundle metadata (CFBundleIdentifier ch.curvuspro.audioxplorer)
AudioXplorer.xcodeproj/       Xcode project (circa Xcode 3, 2009)
Sources/                      ~150 Objective-C / Cocoa source files
  CoreAudio/                  Device, stream, mixer and ring-buffer wrappers
  AudioData*.{h,m}            Amplitude / FFT / Sonogram / Trigger data models
  AudioView*.{h,m}            View hierarchy (2D, 3D, categories for events,
                              display, drag-and-drop, printing, range, …)
  AudioRT*.{h,m}              Real-time window pipeline
  AudioST*.{h,m}              Static window controllers
  AudioDialog*.{h,m}          Modal panels (FFT params, generator, prefs, …)
  AXAU*.{h,m}                 Audio Units host
  AIFF*.{h,m}                 AIFF reader / writer
  MainController.{h,m}        Top-level app controller
ARFramework/                  In-tree helpers (ARDynamicMenu, ARNetwork)
Frameworks/Sparkle.framework/ Vendored Sparkle 2 auto-update framework
AudioXplorer.entitlements     Hardened-runtime entitlements
English.lproj/                Nibs, Localizable.strings, RTF help, Tips.xml
French.lproj/, Italian.lproj/ Localizations
Images/                       App and document icons, custom cursors, toolbar art
Plug-ins (AX)/                Plug-in SDK and three sample plug-ins
  AudioXplorer Plug-Ins SDK.pdf   SDK documentation
  AXPlugIns/                  Single-controller sample
  SinglePlugIn/               Minimal sample
  MultiplePlugIn/             Multi-controller sample
docs/                         GitHub Pages source for the Sparkle appcast
scripts/release.sh            Build, sign, notarize, package DMG, refresh appcast
scripts/sparkle/              Sparkle CLI tools (generate_appcast, sign_update, generate_keys)
```

## Building

Requires Xcode 14+ and macOS 12+. Open the project and build the `AudioXplorer` scheme:

```
open AudioXplorer.xcodeproj
```

To produce a signed and notarized DMG for distribution, see `scripts/release.sh` (requires a Developer ID Application certificate and a `notarytool` keychain profile).

## License

BSD 3‑clause. See [`LICENSE`](LICENSE) for the canonical text. Copyright © 2003–2009 Arizona Software.

## Status

Maintained on a low cadence as a personal project. The 2026 modernization restored buildability on current Xcode/Apple Silicon and added a self-update mechanism via Sparkle. Issues and PRs are welcome but maintenance is best‑effort.

## Version history (excerpt)

- **1.4** (2026‑04‑25) — modernized for Xcode 26 / arm64 / macOS 12+; Developer ID signed and notarized; Sparkle 2 auto‑updates
- **1.3.2** (2009‑09‑08) — Snow Leopard compatibility fixes
- **1.3.1** (2006‑10‑07) — fix: launch on Macs without an input device
- **1.3** (2006‑09‑24) — re‑licensed BSD; Universal Binary (PPC/Intel)
- **1.2** (2005‑08‑28) — discontinued; released as freeware
- **1.1** (2004‑01‑18) — MP3/MP4/WAV import; new update and license managers
- **1.0** (2003‑06‑08) — first release; Audio Units effects; play‑thru

Full history is in `English.lproj/History.rtf`.

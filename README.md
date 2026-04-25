# AudioXplorer

AudioXplorer is a macOS sound‑analysis application originally developed by [Arizona Software](https://www.arizona-software.ch) between 2003 and 2009. It records, generates, imports and visualizes audio, and performs Fast Fourier Transform (FFT) and sonogram analysis both on recorded clips and live input.

This repository is an archival snapshot of the version 1.3.2 source tree (released 8 September 2009, the Snow Leopard fix release). The application was made freeware in 2005 and re‑licensed under the BSD license in 2006.

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
ARCheckForUpdates.framework/  Pre-built auto-update framework (binary)
English.lproj/                Nibs, Localizable.strings, RTF help, Tips.xml
French.lproj/, Italian.lproj/ Localizations
Images/                       App and document icons, custom cursors, toolbar art
Plug-ins (AX)/                Plug-in SDK and three sample plug-ins
  AudioXplorer Plug-Ins SDK.pdf   SDK documentation
  AXPlugIns/                  Single-controller sample
  SinglePlugIn/               Minimal sample
  MultiplePlugIn/             Multi-controller sample
Updates/                      UpdateInfo.plist served to ARCheckForUpdates
```

## Building

The project targets the toolchain that shipped around macOS 10.5–10.6 (Xcode 3) and uses Carbon/Cocoa APIs and Objective‑C frameworks that have since been deprecated or removed (e.g. older `NSNibLoading` patterns, Carbon‑only APIs, the `.nib` format used by Interface Builder 3, the bundled `ARCheckForUpdates.framework` PowerPC/i386 binary). It is **not expected to build out of the box on modern Xcode / Apple Silicon** without porting work.

To open the project on a vintage system:

```
open AudioXplorer.xcodeproj
```

The default scheme is `AudioXplorer` and the build product is `AudioXplorer.app`.

## License

BSD 2‑clause (with non‑endorsement clause). See the header in `Sources/AudioVersions.h` and `main.m` for the canonical text. Copyright © 2003–2009 Arizona Software.

## Status

Discontinued. This repository exists to preserve the source for historical reference; there is no active maintenance, issue tracking, or planned releases.

## Version history (excerpt)

- **1.3.2** (2009‑09‑08) — Snow Leopard compatibility fixes
- **1.3.1** (2006‑10‑07) — fix: launch on Macs without an input device
- **1.3** (2006‑09‑24) — re‑licensed BSD; Universal Binary (PPC/Intel)
- **1.2** (2005‑08‑28) — discontinued; released as freeware
- **1.1** (2004‑01‑18) — MP3/MP4/WAV import; new update and license managers
- **1.0** (2003‑06‑08) — first release; Audio Units effects; play‑thru

Full history is in `English.lproj/History.rtf`.

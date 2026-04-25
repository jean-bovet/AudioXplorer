# AudioXplorer modernization notes

Log of every change made to bring this 2003–2009 Cocoa/Objective-C app back to a working state on current macOS and Xcode.

**Starting state**: Info.plist v1.3.2 (© 2003-09 Arizona Software). Targeting PowerPC + i386, SDK 10.6, QuickTime, Carbon (`AudioUnitCarbonView`, `FSSpec`, Carbon Component Manager), manual retain/release, objectVersion-46 pbxproj. Would not parse in modern Xcode; several of its framework dependencies no longer exist on macOS.

**End state**: Builds cleanly as `arm64` on Xcode 26 / macOS 26, launches, records from the built-in microphone, runs FFT/sonogram analysis, saves/loads AIFF.

**Guiding principle**: Minimum viable changes. Peripheral features that depend on removed APIs were disabled or stubbed, not rewritten. Core audio-analysis engine untouched.

---

## 1. Xcode project settings

`AudioXplorer.xcodeproj/project.pbxproj` and `Plug-ins (AX)/AXPlugIns/AXPlugIns.xcodeproj/project.pbxproj`.

| Setting | Before | After |
|---|---|---|
| `objectVersion` | 46 | 56 |
| `ARCHS` | `(ppc, i386)` / `$(ARCHS_STANDARD_32_BIT)` | `arm64` |
| `SDKROOT` | `macosx10.6` | `macosx` |
| `MACOSX_DEPLOYMENT_TARGET` | 10.6 | 12.0 |
| `CLANG_ENABLE_OBJC_ARC` | — | `NO` (keep manual retain/release) |
| `CODE_SIGN_IDENTITY` | — | `-` (ad-hoc) |
| `CODE_SIGN_STYLE` | — | `Automatic` |
| `WARNING_CFLAGS` | — | adds `-Wno-deprecated-declarations` |

Deleted obsolete settings: `SDKROOT_ppc`, `SDKROOT_i386`, `MACOSX_DEPLOYMENT_TARGET_i386`, `GCC_ENABLE_FIX_AND_CONTINUE`, `ZERO_LINK`, `SECTORDER_FLAGS`, `PREBINDING`, `GCC_FAST_OBJC_DISPATCH`, `FRAMEWORK_SEARCH_PATHS_QUOTED_*` (one of which pointed at the author's long-gone `/path/to/old-dev-dir/…` path).

Framework link changes:
- Dropped `QuickTime.framework` (removed from macOS)
- Dropped `ARCheckForUpdates.framework` (32-bit-only prebuilt binary, no source)
- `vecLib.framework` → `Accelerate.framework` (linker rejects direct `vecLib` link now)

## 2. Auto-updater removed

`ARCheckForUpdates.framework` was a prebuilt universal PPC+i386 bundle with no 64-bit slice and no source available.

Call-site removals in `Sources/AudioApp.m` and `Sources/AudioDialogPrefs.m`:
- `#import <ARCheckForUpdates/ARCheckForUpdates.h>` deleted.
- `[[ARUpdateManager sharedManager] checkForUpdates:sender]` → empty method body.
- `[[ARUpdateManager sharedManager] insertPreferencesIntoView:…]` in `-awakeFromNib` deleted (the prefs "Updates" pane still exists in the nib, just empty).
- `[[ARUpdateManager sharedManager] terminate]` in `-applicationWillTerminate:` deleted.
- `-initVersionChecker` (called from `-applicationWillFinishLaunching:`) body emptied.

The `ARCheckForUpdates.framework/` directory on disk was left alone — only the project references were removed.

## 3. Audio importer rewritten on ExtAudioFile

Originally stubbed behind `AX_ENABLE_QUICKTIME_IMPORTER` while the QuickTime-based importer was unavailable. Now reimplemented on `ExtAudioFile` (AudioToolbox), which on modern macOS handles every format QuickTime did (mp3, m4a/aac, wav, aiff, caf, …) plus several it didn't. The build flag and both code paths it gated were removed.

- `Sources/AudioFileImporter.[hm]`: replaced with an `ExtAudioFile`-based decoder that opens the source URL, sets a client format of 32-bit float / 44.1 kHz / non-interleaved (1 or 2 channels matching the source), and reads into per-channel float buffers in `kImportReadFrames`-frame chunks on a background thread. Output samples are scaled by `[[AudioDialogPrefs shared] fullScaleVoltage] * 0.5` (same convention as the AIFF path, applied via `vDSP_vsmul`) and the buffers are handed to `AudioDataAmplitude` via `-setDataBuffer:size:channel:`, which already assumes `SOUND_DEFAULT_RATE` (44100). No temp AIFF round-trip; cancellation and progress updates marshal back to the main thread.
- `Sources/ARFileUtilities.[hm]`: the FSSpec/FSRef helpers were the only thing this file existed for. The class is now an empty shell (kept in the project to avoid touching the pbxproj for a one-class delete).
- `AudioXplorer.xcodeproj/project.pbxproj`: added `AudioToolbox.framework` to Linked Frameworks. Clang module autolink does not pick it up reliably with this target's settings, so it is linked explicitly.

Call sites in `Sources/AudioSTWindowController.m` were left untouched — the public interface (`-amplitudeFromAnyFile:delegate:parentWindow:` + `amplitudeFromAnyFileCompletedWithAmplitude:` callback) is unchanged.

## 4. Audio Unit plug-in hosting ported

Two modern APIs replaced the Carbon Component Manager throughout:

- `FindNextComponent` → `AudioComponentFindNext`
- `OpenAComponent` → `AudioComponentInstanceNew`
- `CloseComponent` → `AudioComponentInstanceDispose`
- `GetComponentInfo` → `AudioComponentGetDescription` + `AudioComponentCopyName`
- `ComponentDescription` → `AudioComponentDescription`
- `Component` → `AudioComponent`

Files touched:
- `Sources/AXAUManager.m`: `-findComponentsOfType:` rewritten to iterate with `AudioComponentFindNext` and copy names with `AudioComponentCopyName`.
- `Sources/AXAUComponent.[hm]`: struct and pointer types updated; `OSErr` local return types changed to `OSStatus` where needed.

## 5. Audio Unit Carbon editor windows stubbed

`AudioUnitCarbonView` was removed entirely from macOS — no 64-bit version ever shipped. The code that opened a Carbon window to host a third-party AU's custom editor UI was gutted.

In `Sources/AXAUComponent.m`:
- `#import <AudioUnit/AudioUnitCarbonView.h>` removed.
- `auCarbonViewCallback`, `carbonEventCallback`, `carbonButtonEventCallback` C callbacks deleted.
- `-findUIComponent` reduced to `mHasUI = NO` (skip custom editor detection).
- `-openUI` reduced to a stub that returns `NO`.
- `-closeUI` reduced to `return YES`.
- `-windowWillClose:` emptied.

Effect: third-party AU plug-ins are still discovered and their effects still run via `AudioUnitRender`; only the plug-in's custom editor window is missing. The generic parameter UI path still works.

`English.lproj/CarbonWindow.nib` left in the bundle as an unreferenced resource (harmless).

## 6. Carbon menu event hooks stubbed

`ARFramework/ARDynamicMenu/ARDynamicMenu.m` used `InstallMenuEventHandler`, `InvalidateMenuItems`, `UpdateInvalidMenuItems`, `GetCurrentEventKeyModifiers`, and `_NSGetCarbonMenu` to make an `NSMenu` relabel its items live when the user held Option/Control/Shift. All of that Carbon HIToolbox machinery is either removed or private now.

The `ARDynamicMenu` class was rewritten as a no-op shell that still stores item/delegate pairs (so callers compile and run) but never actually re-fires on modifier-key changes. The Effects menu consequently no longer updates dynamically; everything else about it works.

## 7. Legacy vDSP renaming

Unprefixed vDSP function aliases are gone from modern `Accelerate`. Renamed in three files:

| Old | New |
|---|---|
| `ctoz` | `vDSP_ctoz` |
| `fft_zrip` | `vDSP_fft_zrip` |
| `vsmul` | `vDSP_vsmul` |
| `create_fftsetup` | `vDSP_create_fftsetup` |
| `destroy_fftsetup` | `vDSP_destroy_fftsetup` |

Files: `Sources/AudioOperator.m`, `Sources/AudioOpFFT.m`, `Sources/AudioOpSono.m`.

Type aliases `COMPLEX`, `COMPLEX_SPLIT`, enum `FFT_RADIX2`/`FFT_FORWARD`/`FFT_INVERSE`, and `FFTSetup` still resolve through the current `vDSPTranslate.h` compatibility header; left as-is.

## 8. `@defs()` removed

`Sources/AudioSynth.m` used the fragile-runtime `@defs(AudioSynth)` directive to mirror the class's ivars into a C struct so its CoreAudio IO proc could access them through a plain C pointer. `@defs` is not supported on arm64.

Fix:
- In `Sources/AudioSynth.h`, added `@public` visibility to the ivars.
- In `Sources/AudioSynth.m`, deleted the `typedef struct { @defs(AudioSynth); } AudioSynthStruct;` block and cast the IOProc's `userData` directly to `AudioSynth *`. Plain C pointer-to-ivar access via `->mPhase`, `->mFreq_`, etc. works on the non-fragile runtime once the ivars are `@public`. No `__bridge` (project is MRC, not ARC).

## 9. Plug-in sub-project

`Plug-ins (AX)/AXPlugIns/AXPlugIns.xcodeproj` produces `ChCurvusProAXPlugIns.bundle` which the main project embeds. The existing bundle at `build/Deployment/…` was PPC+i386.

Same project-settings sweep as §1 applied to the sub-project's six build-config blocks. Source (`AXPlugIns.m`, `AXPlugInsGainController.m`, prefix header, nibs) rebuilt cleanly without further changes; one `-Wshorten-64-to-32` warning in `AXPlugInsGainController.m:105` suppressed by the project-wide `-Wno-deprecated-declarations` neighbour.

## 10. xattr stripping before codesign

First Release build failed at codesign with:

```
… ChCurvusProAXPlugIns.bundle: resource fork, Finder information, or similar detritus not allowed
```

The project tree carried HFS+-era extended attributes that modern codesign refuses to sign over. One-time fix:

```bash
xattr -cr /path/to/AudioXplorer/
xattr -cr "/path/to/AudioXplorer/Plug-ins (AX)/AXPlugIns/"
rm -rf "/path/to/AudioXplorer/Plug-ins (AX)/AXPlugIns/build"
rm -rf /path/to/AudioXplorer/build
```

After that, both the sub-project and the main project signed and linked as native arm64.

## 11. Microphone permission (Info.plist)

Symptom after first successful launch: the RT (real-time) window opened and looked correct, but nothing was being analyzed — the input was silent.

Root cause: macOS 10.14+ requires `NSMicrophoneUsageDescription` in `Info.plist`. Without it, macOS gives the app silence instead of real audio **and never shows a permission prompt**. The app runs, CoreAudio starts cleanly, but every sample is zero.

Fix in `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>AudioXplorer records and analyzes audio from the selected input device.</string>
```

One-time TCC reset so the new signature triggers a fresh prompt on relaunch:

```bash
tccutil reset Microphone ch.curvuspro.audioxplorer
```

After that, on the next Record action, macOS prompts for microphone access; Allow makes audio start flowing.

## 12. `NSToolbarItem` `setMinSize:` / `setMaxSize:` deprecation

26 call sites across three files, all of the form:

```objc
NSSize itemSize = [someCustomView frame].size;  // or NSMakeSize(32, 32)
[toolbarItem setView:someCustomView];            // or setImage:
[toolbarItem setMinSize:itemSize];
[toolbarItem setMaxSize:itemSize];
```

Both calls were deleted, along with the now-unused `itemSize` locals. For `setView:`-based items the toolbar measures the view's existing frame — same effective size as before. For the `setImage:`-based prefs toolbar items, the toolbar measures the image.

Files touched: `Sources/AudioDialogPrefs+Toolbar.m`, `Sources/AudioRTWindowController.m`, `Sources/AudioSTWindowController.m`.

## 13. App-delegate / document housekeeping

Three console warnings silenced with one method each:

**`Sources/AudioApp.m`** — extended the existing `+initialize` and added a secure-coding delegate method:

```objc
+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults]
        registerDefaults:@{ @"NSQuitAlwaysKeepsWindows": @NO }];
    [AudioDialogPrefs initDefaultValues];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}
```

This kills the "Secure coding is automatically enabled for restorable state…" message and the `restoreWindowWithIdentifier:…Unable to find className=(null)` message (by disabling window restoration entirely).

**`Sources/AudioDocument.m`** — added to top of `@implementation`:

```objc
+ (BOOL)autosavesInPlace
{
    return NO;  // Preserve explicit File > Save semantics for .adx documents.
}
```

This kills the "autosavesInPlace will be changing to YES in a future release" future-default warning and keeps the existing manual-save workflow.

One-time cleanup to clear stale restoration state from earlier runs:

```bash
rm -rf ~/Library/Saved\ Application\ State/ch.curvuspro.audioxplorer.savedState
```

## 14. Codesign vs. iCloud Drive (project in `~/Documents`)

When the project tree lives inside an iCloud-synced directory (`~/Documents`, `~/Desktop`), iCloud's fileprovider daemon continuously re-applies `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P` extended attributes to every file. Codesign refuses any file with `com.apple.FinderInfo`:

```
…/AudioXplorer.app: resource fork, Finder information, or similar detritus not allowed
Command CodeSign failed with a nonzero exit code
```

The §10 one-shot `xattr -cr` recipe loses the race here — iCloud re-tags between strip and codesign. (It worked in §10 because that tree was in `~/Downloads`, which isn't synced.)

Durable fix: do the strip and the codesign in the *same shell*, retrying a few times to absorb the worst case where iCloud re-tags mid-codesign, and disable Xcode's automatic CodeSign step so it doesn't race independently.

Both projects (`AudioXplorer.xcodeproj/project.pbxproj` and `Plug-ins (AX)/AXPlugIns/AXPlugIns.xcodeproj/project.pbxproj`):

- Added a final `PBXShellScriptBuildPhase` named **"Strip xattrs before codesign"** at the end of the target's `buildPhases`. Script body (per project, slightly different — the app variant also forwards `CODE_SIGN_ENTITLEMENTS` if set):

```sh
set -e
DST="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
for i in 1 2 3 4 5 6 7 8; do
  /usr/bin/xattr -cr "$DST"
  if /usr/bin/codesign --force --sign - --timestamp=none \
       --generate-entitlement-der --deep "$DST" 2>/tmp/cs.err; then
    exit 0
  fi
  cat /tmp/cs.err >&2
done
echo "codesign failed after retries" >&2
exit 1
```

- Added `CODE_SIGNING_ALLOWED = NO` to every `XCBuildConfiguration` in both projects (Debug / Release / Default / Deployment). This tells Xcode to skip its built-in CodeSign step, leaving the Run Script as the sole signer.

`CODE_SIGN_IDENTITY = "-"` is left in place so the script still signs ad-hoc.

Verification after a clean rebuild:

```
$ codesign --verify --verbose=2 build/Release/AudioXplorer.app
build/Release/AudioXplorer.app: valid on disk
build/Release/AudioXplorer.app: satisfies its Designated Requirement
```

If the project is later moved out of an iCloud-synced location, this workaround is harmless — `xattr -cr` becomes a no-op and the manual codesign just replaces what Xcode would have done anyway.

## What still works vs. what's disabled

### Works
- Recording via CoreAudio (once microphone permission is granted)
- AIFF load/save
- vDSP FFT, sonogram, amplitude
- Display, printing
- AU plug-in discovery + effect rendering on a selection
- Bundled `ChCurvusProAXPlugIns` gain plug-in
- Real-time analysis window (opens, measures, runs)
- **Import of non-AIFF audio** (mp3/m4a/wav/caf/…) via the new `ExtAudioFile` importer

### Disabled or degraded (by design in this pass)
- **Check for Updates**: feature removed
- **Third-party AU custom editor windows**: Carbon host stubbed; effects still usable through generic UI
- **Effects-menu dynamic relabeling on modifier keys**: Carbon hook stubbed

### Known deferred issue
- `HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload` — CoreAudio real-time thread missing deadlines in the RT window. Symptom of doing too much (Obj-C dispatch, allocation, FFT render) inside the IOProc. Functional but may glitch under load. Not addressed in this pass.

## Files touched

Source:
- `Sources/AudioApp.m`
- `Sources/AudioDialogPrefs.m`
- `Sources/AudioDocument.m`
- `Sources/AudioFileImporter.m` + `.h`
- `Sources/ARFileUtilities.m` + `.h`
- `Sources/AXAUManager.m`
- `Sources/AXAUComponent.m` + `.h`
- `Sources/AudioSynth.m` + `.h`
- `Sources/AudioOperator.m`
- `Sources/AudioOpFFT.m`
- `Sources/AudioOpSono.m`
- `Sources/AudioDialogPrefs+Toolbar.m`
- `Sources/AudioRTWindowController.m`
- `Sources/AudioSTWindowController.m`
- `ARFramework/ARDynamicMenu/ARDynamicMenu.m`

Project/config:
- `AudioXplorer.xcodeproj/project.pbxproj`
- `Plug-ins (AX)/AXPlugIns/AXPlugIns.xcodeproj/project.pbxproj`
- `Info.plist`

## How to build from clean

```bash
cd /path/to/AudioXplorer
xattr -cr .
rm -rf build "Plug-ins (AX)/AXPlugIns/build"

xcodebuild -project "Plug-ins (AX)/AXPlugIns/AXPlugIns.xcodeproj" \
           -configuration Deployment

xcodebuild -project AudioXplorer.xcodeproj -configuration Release
open build/Release/AudioXplorer.app
```

First run will prompt for microphone access once you try to record.

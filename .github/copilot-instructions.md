# copilot-instructions for Scripties (yapLONGER)

Purpose
- Help AI coding agents be immediately productive in this SwiftUI teleprompter app.

Big picture (what to know first)
- App type: native SwiftUI iOS app (open `yapLONGER.xcodeproj`, run `yapLONGER` scheme).
- Directory responsibilities:
  - `iOS/Viewmodels/`: primary app state, controllers, and repositories (e.g. `PracticeSessionController.swift`, `ScriptRepository.swift`, `RecordingStore.swift`).
  - `iOS/Views/Screens/`: SwiftUI screens (e.g. `TeleprompterView.swift`, `OnboardingView.swift`, `PlaybackView.swift`).
  - `iOS/Others/Assets.xcassets/`: images, colors, app icon.

Core services & integration points
- Audio + speech: `AVFoundation` + `Speech` are used extensively. Key file: `iOS/Viewmodels/PracticeSessionController.swift` (audio capture, `SFSpeechRecognizer`, AVAudioEngine, recording URL lifecycle).
- Alignment & rendering: `TeleprompterAlignmentEngine.swift` and `ScriptRenderService.swift` handle mapping transcript words to script lines and producing `RenderedScriptLine` arrays consumed by the teleprompter.
- Analysis: `AudioAnalysisService.swift` performs offline analysis and returns the `Review` used by `ReviewCalculator.swift`.
- Repositories: persistent data is accessed via repository-style classes: `ScriptRepository.swift`, `PracticeSessionRepository.swift`, and `RecordingStore.swift`.

Common patterns and conventions
- MVVM with small controllers: UI views bind to ObservableObject ViewModels in `iOS/Viewmodels/` that expose `@Published` state and async methods.
- Concurrency: `@MainActor` on controllers and `async/await` for long-running actions (look at `PracticeSessionController.start()` and `stopAndAnalyze()` flows).
- Combine is used for notifications and publisher handling (see notification handling in `PracticeSessionController.init()`).
- Audio handling: respect lifecycle in `start()` / `stopAndAnalyze()` / `abandon()`; always remove audio taps and deactivate `AVAudioSession` on stop or error.
- Phrase/context hints: speech recognition requests include `contextualStrings` (see where `SFSpeechAudioBufferRecognitionRequest().contextualStrings` is set) — preserve when editing recognition behavior.

Behavioural invariants to preserve
- Recording lifecycle: create a recording URL via the controller and pass it to analysis; short recordings (<2s) are discarded.
- Alignment engine is reconfigured with `configure(lines:)` before a session; do not skip reconfiguration when preparing a new practice.
- Noise floor learning: audio-level heuristics are intentionally tuned (don't replace with naive thresholding without experimentation).

Build, run, and debug
- Build/run: open `yapLONGER.xcodeproj`, select the `yapLONGER` scheme, pick a simulator or device, then run.
- Permissions: microphone and speech recognition permissions are required; use Settings → Privacy on device/simulator to reset.
- Quick dev loop: use SwiftUI previews for isolated views, but teleprompter & audio flows require a simulator or device due to hardware APIs.

Tests and CI
- There are no visiıble unit tests in the repo. Add tests under a test target in Xcode if needed. CI config not present.

Files worth reading first (quick tour)
- `iOS/Viewmodels/PracticeSessionController.swift` — recording, recognition, alignment, analysis lifecycle.
- `iOS/TeleprompterAlignmentEngine.swift` — how transcripts are mapped to rendered lines.
- `iOS/ScriptRenderService.swift` — transforms script text -> `RenderedScriptLine`.
- `iOS/AudioAnalysisService.swift` — produces `Review` results and the analysis pipeline.
- `iOS/Views/Screens/TeleprompterView.swift` — UI side of the teleprompter flow.

When modifying code
- Preserve `@MainActor` and `@Published` contracts for ViewModels to avoid UI threading issues.
- Keep audio lifecycle exact: installTap / removeTap and `recognitionRequest?.endAudio()` sequencing matters — test on device.
- For UI changes, prefer small ViewModel method additions instead of pushing logic into Views.

If you need to add a feature that touches audio or speech
- Update `PracticeSessionController` and `AudioAnalysisService` together: recording format, writer (`AudioBufferWriter`), and analysis inputs must match.
- Add contextual strings for recognition if adding domain-specific vocabulary.

Local developer tips
- Use Xcode's Scheme `yapLONGER` and run on a physical device for reliable audio and speech recognition.
- To reset speech permissions on a simulator, use Simulator → Erase Content and Settings or reset permissions in Settings.

How to ask follow-ups
- If you want code changes, mention the target file(s) (e.g. `iOS/Viewmodels/PracticeSessionController.swift`) and whether you want a device or simulator workflow.
- For UX changes reference the screen component (e.g. `iOS/Views/Screens/TeleprompterView.swift`).

End

If anything here is unclear or you'd like more examples (small PRs, tests, or a debugging checklist), tell me which area to expand.

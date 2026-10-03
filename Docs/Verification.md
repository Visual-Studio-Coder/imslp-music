# Verification record

Date: 2026-10-03. Build host: macOS 27.2, Xcode 27.0 beta, Swift 6.4. Deployment targets: macOS 15 and iOS/iPadOS 18.

## Confirmed results

- Publication checks used a clean Mac build folder. Five tests passed in `Artifacts/public-mac-e2e.xcresult`. Its two queue tests selected a source-only recording and failed. After selecting a recording with public audio, the playlist test passed in `Artifacts/public-mac-queue-final.xcresult`. The drag test needed its selector scoped to the queue sheet; it then passed in `Artifacts/public-mac-drag-final.xcresult`. All seven scenarios have passing results across these runs. The initial suite is not a passing bundle.

- The reported Mozart K.523 recording, IMSLP435425, is marked EU and has no public player URL in the IMSLP response. The app now shows Open IMSLP, retains the official file link, and explains website-only access. `Artifacts/mac-source-access-final.xcresult` passes using the saved source response. The official file entry leads to an IMSLP browser verification flow. No CAPTCHA bypass or streaming access is claimed.

- The waveform update builds on Mac and mobile. The Mac playback, seek, download, restart, and offline E2E check passes in `Artifacts/mac-waveform.xcresult`. Updated player screenshots show the indicator beside the options menu. Pause and Reduce Motion stop its animation; a spoken accessibility audit remains outstanding.

- Mac Debug and Release builds pass. The Release binary contains arm64 and x86_64 code.
- Four Mac E2E tests pass in `Artifacts/mac-expanded.xcresult`.
- Four iPhone E2E tests pass in `Artifacts/iphone-final.xcresult`. Screenshots are in `Artifacts/Screenshots/iPhone`.
- The Mac mini-player and Command-F test passes in `Artifacts/mac-final-controls.xcresult`. That bundle also contains an earlier queue-drag failure, so the whole bundle is not a passing suite.
- Queue drag and clear pass in `Artifacts/mac-queue-final.xcresult`. Explicit Mac drag handles fixed interference from the row's play button. The same handle and drop logic is used for playlists.
- Tests cover search, empty results, offline errors, real AVFoundation fixture playback, time advance, seek, queue controls, playlist creation/add/rename/remove/delete, favorites, download validation, cancellation, restart without autoplay, offline playback, and separate download removal.
- The live Swift service check passes for Bach, Beethoven, and Debussy. See `Artifacts/live-catalog-check.txt`.
- The live audio check passes for IMSLP310845: streaming, time advance, seeking, complete HTTP download, and local duration validation. See `Artifacts/live-audio-check.txt` and `Artifacts/live-audio-headers.txt`.
- The Release Mac interface also streamed IMSLP310845, advanced the clock, sought to 32 seconds, and paused. See `Artifacts/live-release-ui.txt` for steps and observed values.
- Mac screenshots were inspected. A navigation defect that hid the player and a full-player sizing problem were corrected. Updated screenshots are in `Artifacts/Screenshots/Mac`.

## Source checks

| Work | Recording groups | Result |
| --- | ---: | --- |
| Bach, Cello Suite No.1, BWV 1007 | 11, including synthesized groups | Six files retain the source movement order in the selected recording. |
| Beethoven, Symphony No.5, Op.67 | 27 | 23 public player audio links found. |
| Debussy, Suite bergamasque, CD 82 | 14 | 18 public player audio links found. |

The group counts include items without a playable public link. Counts are a snapshot, not a promise of future source availability.

## Repeat the tests

Run `Scripts/test.sh mac`, `Scripts/test.sh iphone`, or `Scripts/test.sh ipad`. Each run creates a dated `.xcresult`, log, and screenshot export. Mobile tests use simulator devices named `IMSLP iPhone` and `IMSLP iPad`.

The fixture suite uses saved IMSLP responses and an original test tone. Debug-only arguments select an isolated test library and failure conditions. The local fixture download path tests cancellation and validation. It does not simulate every network transfer failure. The separate live audio check verifies a real transfer.

To repeat only the final queue test:

```sh
xcodebuild -project IMSLPMusic.xcodeproj -scheme IMSLPMusicMac \
  -configuration Debug -derivedDataPath build/mac -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:MusicMacE2E/MusicE2ETests/testQueueDragOrder \
  -resultBundlePath Artifacts/queue-rerun.xcresult test
```

For large text, boot the dedicated iPhone simulator, run `xcrun simctl ui 'IMSLP iPhone' content_size accessibility-extra-extra-extra-large`, then run the mobile scheme with `-only-testing:MusicMobileE2E/MusicE2ETests/testReadableLayout`. Restore it with `xcrun simctl ui 'IMSLP iPhone' content_size large` after the check. Use a fresh result-bundle path for every run.

## Practical limits

- iPad verification is incomplete. The first run could not select the iPadOS 27 floating tab bar. The selector was corrected, but two later runs stalled before the test runner started, including after a simulator restart. See `Artifacts/ipad-final.xcresult`, `Artifacts/ipad-verified.log`, and `Artifacts/ipad-retry.log`.
- The iPhone largest-text run also stalled before the test runner started. The setting was confirmed, then restored to the default size after the run was stopped. See `Artifacts/iphone-large-text.log`. The passing iPhone suite used standard text size.
- Physical device signing, App Store publication, notarization, external AirPlay hardware, and real interruption/headphone events have not been verified.
- Deployment compatibility is checked by the compiler. macOS 15 and iOS 18 runtimes were not installed for execution tests.
- VoiceOver labels are present. A complete spoken VoiceOver audit and all larger-text sizes have not been verified.
- The failure inventory is broader than the completed automated suite. Real network loss during transfer, rapid concurrent selections, every source template change, and playlist drag persistence need additional E2E coverage.
- Exact visual parity with Apple Music Classical is not claimed. The Mac interface is an adaptation with native desktop controls.
- IMSLP can change page templates or audio access. The app uses public player data and displays errors with source links when access is unavailable.

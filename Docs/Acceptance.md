# Acceptance cases, written before implementation

## Reference checklist

Reference date: 2026-10-03. Sources: [Classical user guide](https://support.apple.com/guide/apple-music-classical/welcome/web), [player controls](https://support.apple.com/en-euro/guide/apple-music-classical/dev418ee3f2d/web), [queue](https://support.apple.com/en-euro/guide/apple-music-classical/hdr5xvmpmmy3/web), and [current web search](https://classical.music.apple.com/us/search).

- Home, Browse, Library, Search. Desktop uses a sidebar. Mobile uses tabs.
- Search by composer or work. Open a work, compare performances, then select a recording or movement.
- Use clear title hierarchy, large artwork, red action controls, grouped track rows, and native materials.
- A small player remains available during navigation. Selecting it opens the full player. Mobile dismissal uses a downward swipe.
- Player includes previous, play/pause, next, time, seek, volume, favorite, source information, and queue. Previous restarts the track before going to the previous item.
- Queue supports Play Next, Play Last, select, reorder, remove, clear, shuffle, and repeat off/all/one.
- Library supports saved tracks, favorites, playlists, sort, and separate download removal.
- Mac includes keyboard commands, context menus, resize behavior, and a separate mini player.
- Adaptation: downloads are inside this app; editorial pages, subscriptions, lyrics, and listening guides are omitted.
- The reference has not been measured pixel by pixel. Do not report exact visual parity without a measured comparison.

## E2E scenarios

1. Search for Bach, open a work, select a recording, play real audio, and verify time advances. Pause and verify it stops. Seek and skip.
2. Add tracks next/last; verify order, move, remove, clear, shuffle, and repeat controls.
3. Save a track and favorite it. Create, rename, populate, reorder, and delete a playlist. Restart and verify state persists without autoplay.
4. Download a track; verify progress and completion. Relaunch offline, play the local file, then remove only the download. The library item remains.
5. Open and close the full player and Mac mini player. Verify each uses the same player state.
6. Verify empty results, network errors, unavailable files, unsupported formats, and missing metadata show useful states.
7. Verify source changes do not turn scores or videos into audio recordings. Complete performances stay complete; movements keep source order.
8. Cancel a download and retry. Reject HTML, empty files, and incomplete audio. Do not label these as downloaded.
9. Rapid search and rapid track selection must not apply stale results. Duplicate queue entries need separate identities.
10. Verify compact iPhone, wide iPad, and resized Mac layouts, larger text, and labeled controls.

## Failure inventory

- Source-only recording: Mozart K.523, IMSLP435425, has an EU label and no public player URL. Preserve its official file link, show Open IMSLP instead of a working Play promise, and do not label a missing URL as a confirmed bot check. Existing saved tracks must still decode.

- Playing indicator: must appear beside the current track's options menu, stop when paused, move when the track changes, and stay still when Reduce Motion is on. Check that the menu remains usable.

- Source timeout, rate limit, malformed JSON, source redirect, missing page, no audio section, new template syntax.
- Nested wiki templates, names containing punctuation, missing performer, duplicate file entries, MIDI-only work.
- HTML access response, expired URL, non-HTTPS address, partial file, unsupported codec.
- Track switch during resolution; player failure after load; interruption; queue removal while playing.
- Persisted queue index out of range; deleted download; disk full; canceled transfer; failed storage write.
- Simulator access failure, unavailable runtime, missing signing identity, UI automation permission failure.

## Evidence

Keep UI screenshots and `.xcresult` bundles under Artifacts. Include rerun commands, fixture origin, and live source checks. Fixture tests must use the same parser and audio player as production. A passing fixture test does not prove live source availability.

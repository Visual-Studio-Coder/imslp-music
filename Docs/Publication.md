# Publication checks

Prepared on 2026-10-03.

## Source audit

The candidate source files passed the bundled privacy and secret audit after contact email text was removed from saved IMSLP pages. PNG text and EXIF metadata were removed. The original test tone has only format and audio-data chunks. Public composer, performer, and uploader credits remain as source attribution.

The audit found no known private user data or secrets in the candidate source and app payloads. This does not prove that no undiscovered data exists.

There was no Git history or remote to preserve. No dependency folders, build output, local databases, downloaded recordings, logs, or test result bundles are in the source payload. No external packages are required by the app.

## Mac export

The universal Release archive was built in a new build folder. It contains arm64 and x86_64 code and targets macOS 15. Test responses and the test tone are excluded from Release builds.

The exported app has an ad-hoc signature. Signature checks passed for the app extracted from the ZIP and mounted from the DMG. The DMG checksum and mount checks passed. No Developer ID signing identity or notarization setup was available.

The app binary scan found no private home paths. The package audit flagged the standard Applications shortcut. It points only to `/Applications` and is an intentional install link. Disk-image inspection reports the current local file location; that report is not part of the public payload.

The release exports are a Mac DMG, a Mac ZIP, and a SHA-256 checksum file. Mobile targets remain source-only because no distribution signing is configured.

## Local evidence

The source audit report, clean build logs, test results, and package checks are saved under the ignored Artifacts folder. They are not public release attachments. Tests can be repeated with the commands in README and Verification.

The approved settings are a public Visual-Studio-Coder/imslp-music repository, the MIT License with copyright 2026 Vaibhav Satishkumar, and release v1.0.0. The user approved the local ad-hoc signature and no notarization.

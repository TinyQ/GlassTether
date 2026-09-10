# Contributing

This repository is a local pre-publication alpha. Contributions open after the owner confirms licensing and publishes a destination. No public issue/contact endpoint is established yet.

Use Xcode with Swift 6. Run `swift test`, `./script/build.sh`, and `git diff --check`. Keep pure transport logic in PhoneControlCore and platform I/O behind the existing capture/Bluetooth boundaries. Do not start hardware while running automated tests. Changes to report maps, discovery UUIDs, cursor lifetime or input queues need the relevant regression tests plus a clearly separated hardware result.

Keep scope focused on wired video and explicit pointer control. Discuss keyboard, recording, OCR, networking or cloud proposals before implementation. Never log device identifiers, screens or input streams. Do not copy third-party code without recording its origin/license and confirming compatibility. Current USB discovery ownership is still subject to publication review.

A useful pull request states the user-visible problem, final behavior, automated checks, hardware environment (or not tested) and known limitations. Use small changes; no invented performance or support claims. For a bug use the included template and remove notifications, account names and device IDs from attachments.

For community feedback, see RELEASE_REVIEW.md. This draft does not establish a CLA, change anyone's copyright, or authorize publication of private source.

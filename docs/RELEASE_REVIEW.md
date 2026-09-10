# Publication review packet

## Proposed GitHub description

Native macOS app for wired iPhone video and Bluetooth absolute mouse control. Local, explicit, experimental.

Suggested topics: macos, swift, iphone, bluetooth, hid, screen-mirroring, assistivetouch. Repository: [TinyQ/GlassTether](https://github.com/TinyQ/GlassTether), created as a private review repository at the owner’s request. Public visibility and licensing remain pending.

## First release notes: 0.1.0-alpha.1 (draft)

First local GlassTether alpha, derived from a traceable user-owned prototype. Adds a three-step connection interface, USB retry, compact diagnostics and explicit absolute-pointer control. Preserves aspect-fit mapping, bounded ordered reports, fresh-video gating and cursor release paths; adds focus checks and tests for invalid/stale frame timestamps. No audio, recording, OCR, cloud service or keyboard/multitouch forwarding.

Twelve core automated tests passed during local development. Consult VALIDATION.md for the current build and visual check evidence. This renamed application has not been paired or video-connected during development, to avoid competing with the owner's running demo. Hardware compatibility, button actions and every exit path require acceptance. Local build is ad hoc signed and not notarized. Experimental PnP identity remains a distribution blocker.

## Real screenshot and demo plan

Use an actual offline app-window screenshot for UI review, clearly captioned “Disconnected alpha UI”. Never substitute a mock phone image as evidence of working control. If a local screenshot is present in docs/assets, it captures only the new app window with no phone session.

After coordinated hardware testing, capture a 30–45 second external demonstration: show cable/phone, point to center and four quadrant locations, repeat center, click/drag harmless content, leave the video and show restored Mac pointer, then press Esc. Record exact OS/model/app version alongside the clip. Hide personal notifications before filming. Do not add recording functionality to the app. Publish only approved footage and label pending tests honestly.

## Before publication

- [ ] Owner confirms final name and GitHub account/repository; explicitly authorizes publication.
- [ ] Owner confirms redistribution rights for source provenance and copyright holder.
- [ ] Owner selects license; add actual LICENSE and required notices.
- [ ] Resolve prototype Bluetooth PnP identity; verify fresh pairing after any change.
- [ ] Finish current-build hardware acceptance, record exact versions, publish honest matrix.
- [ ] Review source-only export and Git history for private information; replace any machine-local author identity with owner-approved public identity.
- [ ] Choose source-only alpha or sign/notarize binaries with the owner's Developer ID; test on a clean Mac.
- [ ] Enable private vulnerability reporting and validate issue templates.

The owner selected TinyQ as the GitHub destination. The project is being synchronized to the private TinyQ/GlassTether repository. No public release or messages to others have been sent. This upload does not settle the pending license, source-rights or hardware acceptance checks.

## Repeatable release procedure

1. Start from a clean reviewed commit; run `swift test`, `./script/build.sh`, `git diff --check` and the hardware checklist on the actual release build.
2. Update VALIDATION, COMPATIBILITY and release notes. Do not reuse another build's hardware acceptance.
3. After approved name/license/destination, review the exact staged source archive and notices. Keep `.build`, dist, phone media and private docs out of source history.
4. For a source-only alpha, export the reviewed commit with `git archive`; clearly document that users build locally. For binaries, add Developer ID signing, hardened runtime, notarization and stapling under an approved process, then verify Gatekeeper on a clean machine. The current build script is not this public distribution pipeline.
5. Only after explicit publication authorization create/push the destination and publish the approved assets/checksums and release notes. No CI auto-release is included.

## Roadmap

1. Before alpha release: hardware acceptance, cursor lifecycle, pairing recovery, provenance/license and identity review.
2. After alpha feedback: simplify the most common pairing failures, improve localization and accessibility based on tested problems, add measured compatibility rows.
3. When reproducible: investigate latency with a documented measurement method and expand macOS/iPhone combinations. Do not promise dates or universal support.

## Community feedback plan

After authorized publication, invite a small set of opt-in testers using the hardware template. Triage new reports twice weekly for the first month: stuck input/wrong-device reports first, connection failures next, cosmetic issues last. Ask only for versions and reproduction, mark untested environments explicitly, and attach fixes to reproducible reports. Publish a weekly compatibility changelog only when results change. Proposed maintainership cadence, not a scheduled automation or promise that messages have been sent.

Track useful outcomes: reproducible hardware reports, resolved failure modes and repeat testing of fixes. Do not fabricate users, stars, performance numbers or community traction.

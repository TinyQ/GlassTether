# Compatibility and test evidence

Do not convert the minimum compilation target into a support claim.

| Build / environment | Evidence | What remains unknown |
| --- | --- | --- |
| Source demo 004, Apple Silicon, macOS 26.6.2 per source log; iPhone model/iOS unrecorded | User confirmed pointer following and a screenshot visually matched approximately 25%/25% absolute position on 2026-09-10 | Exact phone/OS, precision, latency, all other points and complete click/drag/exit/rotation/reconnect matrix |
| Source demo 005, same development context | Build/signature passed; cursor hide/restore implemented | Actual hide/restore hardware acceptance |
| GlassTether alpha.1 | See VALIDATION.md for local build, tests and launch checks | New name/PnP pairing and complete hardware checklist below |
| Other macOS/iOS/Intel/iPad combinations | No test evidence | All runtime compatibility |

## Hardware acceptance protocol

Run only when the owner has disconnected other preview apps and stopped other BLE broadcasters. Record app commit, Mac model/chip, macOS version, iPhone model, iOS version, cable and AssistiveTouch settings. Do not collect serials or BLE identifiers. Use a blank Notes page or another harmless screen with no private content.

- [ ] Pair GT Mouse and confirm subscription; confirm the same phone is on USB video.
- [ ] Move to center, each 25%/75% quadrant, then center again; verify repeatable landing and observe any offset. Do not label visual estimates pixel measurements.
- [ ] Click, right/middle click, scroll, long press and drag; record iPhone button assignments.
- [ ] Hold a drag and leave the picture; verify release, then repeat across black bars and side panel.
- [ ] Drag into the picture from Mac; no inherited press may be sent.
- [ ] Cross the boundary repeatedly; Mac cursor hides inside and reappears outside.
- [ ] During a drag press Esc, switch apps, minimize and close the window; no stuck button/cursor.
- [ ] Unplug USB/freeze video and disconnect Bluetooth; control switches off and never resumes automatically.
- [ ] Rotate phone and resize window during drag; release before using the new mapping.
- [ ] Stop/restart both connections; no stale click replay. Repeat after app relaunch.
- [ ] Deny camera/Bluetooth permissions, then grant and retry; recovery is understandable.

Record pass/fail/not tested separately with reproduction steps. No latency benchmark is available; a future measurement must state capture method, sample count and distribution. Do not use source-demo feedback as acceptance of this refactor.

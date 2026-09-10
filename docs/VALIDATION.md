# Local validation — 2026-09-10

Environment: Apple Silicon, macOS 26.6.2 (25G83), Xcode macOS 26.5 SDK, Swift 6 language mode. No phone capture, discovery or BLE advertising was started for this project.

- `swift test`: 12 Swift Testing cases passed, zero failures. Five inherited relative-transport regressions, five absolute mapping/report/queue tests, two new frame freshness tests. The XCTest wrapper prints zero tests; the Swift Testing runner separately reports all twelve.
- Final `script/build.sh`: Release build, numbered app packaging, ad hoc codesign verification and Info.plist lint passed. No microphone or networking entitlement is present.
- `swift-format lint --strict`: passed on source, tests and package manifest.
- `git diff --check`: passed. Documentation relative links checked with no missing targets.
- Baseline-import hashes compared with the source demo after development: every selected source file unchanged. Source demo working tree remains clean.
- Initial numbered app launched through the UI tool. Accessibility state confirmed USB off, Bluetooth off, disabled/off Control iPhone. Real window screenshot visually checked: preview placeholder and all three steps fit; connection details expand/collapse without starting services. Esc leaves the offline app disarmed.
- Screenshot: [disconnected alpha UI](assets/disconnected-alpha.png). No iPhone content was captured. Final source cleanup removed an unused probe helper and applied formatting; the UI design did not change.

The first sandboxed build failed because system Swift compiler caches were not writable. Retried using approved build access. Product build artifacts remain in this project's `.build` and `dist`; compiler/SwiftPM may also use their standard system caches. These are not another project's build outputs.

Not tested: this app's actual USB/BLE pairing, latency, positioning accuracy, click/drag/wheel actions, cursor hide/restore during active control, disconnect delivery, permission denial recovery, rotation or any additional OS/device. Follow COMPATIBILITY.md. Existing source-demo evidence is explicitly separate.

Local build identity: `local.glasstether.preview`; Bluetooth advertised name: `GT Mouse`; prototype PnP identity is still not suitable for claiming a production assignment. Build is native to this Mac architecture, ad hoc signed, not notarized and not publicly released.

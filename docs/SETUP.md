# Install, connect and recover

## Local installation

Build from the repository as described in README. Open the numbered app produced by the build script. Keep older builds as rollback; no app is installed in Applications. The sandbox bundle ID is `local.glasstether.preview`, distinct from the source demo. macOS owns any preferences/container under this identity; the app creates no custom configuration directory or device history.

The current ad hoc signature is for local testing only. A public binary needs a reviewed signing/notarization workflow. Do not disable system security to run an untrusted download.

## Connect deliberately

Close other applications' iPhone previews before connecting here. Do not run another BLE mouse broadcaster during pairing. Plug in one phone with a data-capable USB cable, unlock it, and accept Trust This Computer on the phone. Choose Connect USB video; macOS asks for camera permission because AVFoundation supplies video. The program connects video ports only and requests no microphone permission.

Choose Pair Bluetooth mouse. On the phone enable AssistiveTouch and select GT Mouse under Settings → Accessibility → Touch → AssistiveTouch → Devices → Bluetooth Devices. A Mac name can appear instead. Apple documents this [pointer pairing route and button assignments](https://support.apple.com/en-us/111775). A BLE subscription is evidence of a subscriber, not a USB identity match.

Before control: confirm only the intended phone is paired, disable Dwell Control and Drag Lock, use harmless content, then enable Control iPhone. Right/middle button meaning depends on the iPhone's AssistiveTouch configuration. The iPhone pointer is the actual target; if the USB picture does not show it, stop control instead of guessing.

## Return to Mac

Leaving the actual video region releases buttons and restores the Mac cursor. Black bars do not forward input. Esc turns control off. App/window focus loss, sleep, stale video, Bluetooth reset and window removal restore the cursor and release input. Video is considered stale after 0.6 seconds without a fresh frame, checked by a main-run-loop timer; this is not a hard real-time guarantee. Release packets cannot be guaranteed to arrive after a radio disconnect. If the phone remains dragging, disconnect the mouse on iPhone and check Drag Lock.

## Recovery

| Symptom | Next action |
| --- | --- |
| No USB device | Unlock/trust phone, check cable, disconnect preview elsewhere, use Retry video connection. |
| Multiple devices | Leave only the intended wired iPhone connected, retry. |
| Permission denied | Allow camera/Bluetooth for GlassTether in System Settings → Privacy & Security, then reconnect; relaunch if macOS asks. |
| Waiting for video / frozen video | Control stays off. Disconnect video, reconnect cable, retry. |
| Mouse not visible | Ensure Bluetooth is on; stop pairing, expand Connection details, try Compatibility discovery, start again. |
| Old pairing or changed report | Stop Bluetooth and forget the old pairing on iPhone before pairing again. Name changes alone do not clear cached reports. |
| Mouse subscribed but no correct pointing | Stop control. Record exact versions and a harmless reproducible test. Subscription alone does not prove absolute support. |
| Bluetooth disconnect | Stop Bluetooth and pair again. No automatic control resume. |

Pairing a new app identity may require forgetting a previous test pairing. Coordinate that manually; this app never removes bonds or changes AssistiveTouch settings itself.

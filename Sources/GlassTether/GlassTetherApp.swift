import AppKit
import SwiftUI

@main
struct GlassTetherApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  var body: some Scene {
    Window("GlassTether", id: "main") {
      ConnectionView(model: delegate.model, bluetooth: delegate.model.bluetooth)
        .preferredColorScheme(.dark)
        .frame(minWidth: 900, minHeight: 680)
    }
    .defaultSize(width: 1120, height: 800)
    .commands { CommandGroup(replacing: .newItem) {} }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = SessionModel()
  private var keyMonitor: Any?
  func applicationDidFinishLaunching(_ notification: Notification) {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if event.keyCode == 53 {
        self?.model.armed = false
        self?.model.surface?.releaseInput()
        return nil
      }
      return event
    }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  func applicationWillTerminate(_ notification: Notification) {
    model.shutdown()
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
  }
}

struct ConnectionView: View {
  @ObservedObject var model: SessionModel
  @ObservedObject var bluetooth: BluetoothMouse
  @State private var diagnostics = false
  private let accent = Color(red: 0.44, green: 0.87, blue: 0.77)

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.title2).foregroundStyle(
          accent)
        VStack(alignment: .leading, spacing: 3) {
          Text("GlassTether").font(.title2.weight(.semibold))
          Text("Your iPhone. Within reach.").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Label(
          model.armed ? "Control on" : "View only",
          systemImage: model.armed ? "cursorarrow.rays" : "eye"
        )
        .font(.callout.weight(.medium)).foregroundStyle(model.armed ? accent : .secondary)
        Text("ALPHA").font(.caption2.monospaced().bold()).padding(6)
          .background(.white.opacity(0.08), in: Capsule())
      }.padding(24)
      Divider()
      HStack(alignment: .top, spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
          ZStack {
            PhonePreview(model: model)
            if !model.fresh {
              VStack(spacing: 20) {
                Image(systemName: "cable.connector").font(.system(size: 44, weight: .ultraLight))
                  .foregroundStyle(accent)
                Text("Make a little room for your iPhone.").font(.title3.weight(.medium))
                Text(
                  "Connect a USB cable, unlock your iPhone,\nand trust this Mac to start viewing."
                )
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Text("VIDEO ONLY  /  NOTHING SAVED").font(.caption2.monospaced()).foregroundStyle(
                  .secondary)
              }.padding(24).allowsHitTesting(false)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .overlay(
            RoundedRectangle(cornerRadius: 20).stroke(
              model.armed ? accent : .white.opacity(0.12), lineWidth: 2))
          HStack {
            Circle().fill(model.fresh ? accent : .gray).frame(width: 6, height: 6)
            Text(
              model.armed
                ? "Move outside the video to return to your Mac."
                : "Viewing never enables control automatically.")
            Spacer()
            Text("esc").font(.caption.monospaced()).padding(.horizontal, 7).padding(.vertical, 3)
              .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            Text("Stop control")
          }.font(.caption).foregroundStyle(.secondary)
        }
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            step("1", "Connect the picture", symbol: "cable.connector") {
              Text(model.usbStatus).font(.callout).foregroundStyle(.secondary)
              Button(model.usbRequested ? "Disconnect video" : "Connect USB video") {
                if model.usbRequested { model.stopUSB() } else { model.connectUSB() }
              }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
              if model.usbRequested && !model.fresh {
                Button("Retry video connection") { model.retryUSB() }
              }
              Text("Disconnect iPhone preview in other apps first. Connect only one iPhone.").font(
                .caption
              ).foregroundStyle(.secondary)
            }
            Divider()
            step("2", "Pair the mouse", symbol: "computermouse") {
              Text(bluetooth.status).font(.callout).foregroundStyle(.secondary)
              Button(bluetooth.running ? "Stop Bluetooth" : "Pair Bluetooth mouse") {
                if bluetooth.running { bluetooth.stop() } else { bluetooth.start() }
              }
              Text(
                "On iPhone: Settings → Accessibility → Touch → AssistiveTouch → Devices → Bluetooth Devices. Enable AssistiveTouch, then choose GT Mouse."
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            step("3", "Take control", symbol: "cursorarrow") {
              Toggle("Control iPhone", isOn: $model.armed).toggleStyle(.switch).tint(accent)
                .disabled(!bluetooth.connected || !model.fresh)
              Text(
                "Match the paired phone to the preview yourself. USB and Bluetooth identities cannot be verified as the same device."
              )
              .font(.caption).foregroundStyle(.secondary)
              Text(
                "Turn off Dwell Control and Drag Lock on iPhone. Press Esc to stop; enable control again after interruptions."
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            DisclosureGroup("Connection details", isExpanded: $diagnostics) {
              VStack(alignment: .leading, spacing: 10) {
                Text(bluetooth.discoveryStatus)
                Text("Absolute pointer • video only • no saved input logs")
                Picker("Discovery", selection: $bluetooth.compactDiscovery) {
                  Text("Standard").tag(true)
                  Text("Compatibility").tag(false)
                }.disabled(bluetooth.running)
                Text(
                  "If the mouse is not found, stop Bluetooth and try Compatibility. Report changes may require forgetting the old pairing."
                )
              }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            }
            Text("Experimental compatibility. Test this Mac and iPhone before relying on control.")
              .font(.caption).foregroundStyle(.secondary)
          }.padding(.vertical, 4)
        }.frame(width: 300)
      }.padding(24)
    }.background(Color(red: 0.055, green: 0.075, blue: 0.09))
  }

  private func step<Content: View>(
    _ number: String, _ title: String, symbol: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(number).font(.caption.monospaced().bold()).foregroundStyle(accent)
          .frame(width: 24, height: 24).background(accent.opacity(0.12), in: Circle())
        Text(title).font(.headline)
        Spacer()
        Image(systemName: symbol).foregroundStyle(.secondary)
      }
      content()
    }
  }
}

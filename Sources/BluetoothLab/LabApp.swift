import AppKit
import SwiftUI

@main
struct BluetoothLabApp: App {
  @NSApplicationDelegateAdaptor(LabDelegate.self) private var delegate
  var body: some Scene {
    WindowGroup("LiveMate · 蓝牙控制实验室") {
      LabView(model: delegate.model, bluetooth: delegate.model.bluetooth)
        .preferredColorScheme(.dark)
        .frame(minWidth: 900, minHeight: 650)
    }
    .defaultSize(width: 1080, height: 780)
    .commands { CommandGroup(replacing: .newItem) {} }
  }
}

@MainActor
final class LabDelegate: NSObject, NSApplicationDelegate {
  let model = LabModel()
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

struct LabView: View {
  @ObservedObject var model: LabModel
  @ObservedObject var bluetooth: BluetoothMouse
  var body: some View {
    HStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 12) {
        Text("手机预览").font(.headline)
        ZStack {
          PhonePreview(model: model)
          if !model.fresh {
            VStack(spacing: 14) {
              Image(systemName: "iphone.and.arrow.forward").font(.system(size: 40))
              Text("连接 USB 后显示 iPhone 画面")
              Text("仅显示视频 · 不采集声音").font(.caption).foregroundStyle(.secondary)
            }
            .allowsHitTesting(false)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
          RoundedRectangle(cornerRadius: 18).stroke(
            model.armed ? Color.green : Color.gray.opacity(0.3), lineWidth: 2))
        Text(model.armed ? "画面内仅显示手机指针，移出恢复 Mac 指针。按 Esc 立即停用。" : "控制未开启，鼠标只操作 Mac。")
          .font(.callout).foregroundStyle(model.armed ? .green : .secondary)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 7) {
            Text("蓝牙控制实验室").font(.title2.bold())
            Text("独立原型 005 · 不改动主程序").foregroundStyle(.secondary)
          }
          Divider()
          VStack(alignment: .leading, spacing: 10) {
            Label("1  连接鼠标", systemImage: "computermouse").font(.headline)
            Text(bluetooth.status).font(.callout).foregroundStyle(.secondary)
            Picker("定位模式", selection: $bluetooth.absoluteMode) {
              Text("绝对定位（实验）").tag(true)
              Text("相对鼠标（已验证）").tag(false)
            }
            .disabled(bluetooth.running)
            Picker("发现模式", selection: $bluetooth.compactDiscovery) {
              Text("标准发现").tag(true)
              Text("兼容发现").tag(false)
            }
            .disabled(bluetooth.running)
            Text(bluetooth.discoveryStatus).font(.caption).foregroundStyle(.secondary)
            Button(bluetooth.running ? "停止蓝牙" : "开始蓝牙配对") {
              if bluetooth.running { bluetooth.stop() } else { bluetooth.start() }
            }
            Text("iPhone：设置 → 辅助功能 → 触控 → 辅助触控 → 设备 → 蓝牙设备。开启辅助触控并选择本机。")
              .font(.caption).foregroundStyle(.secondary)
          }
          Divider()
          VStack(alignment: .leading, spacing: 10) {
            Label("2  连接画面", systemImage: "cable.connector").font(.headline)
            Text(model.usbStatus).font(.callout).foregroundStyle(.secondary)
            Button(model.usbRequested ? "停止 USB 预览" : "连接 USB 预览") {
              if model.usbRequested { model.stopUSB() } else { model.connectUSB() }
            }
            Text("先断开主程序的手机预览，再连接本原型。手机需解锁并信任此 Mac。")
              .font(.caption).foregroundStyle(.secondary)
          }
          Divider()
          VStack(alignment: .leading, spacing: 10) {
            if bluetooth.absoluteMode {
              Text("定位测试 · 只移动，不点击").font(.caption.bold())
              HStack {
                probeButton("左上", x: 0.25, y: 0.25)
                probeButton("中心", x: 0.5, y: 0.5)
                probeButton("右上", x: 0.75, y: 0.25)
              }
              HStack {
                probeButton("左下", x: 0.25, y: 0.75)
                probeButton("右下", x: 0.75, y: 0.75)
              }
              Text("先确认手机指针到达相应区域，再开启控制。切换定位模式后需忘记旧设备并重新配对。")
                .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("3  开启手机控制", isOn: $model.armed)
              .toggleStyle(.switch)
              .disabled(!bluetooth.connected || !model.fresh)
            if !bluetooth.absoluteMode {
              HStack {
                Text("移动灵敏度")
                Spacer()
                Text(model.sensitivity.formatted(.number.precision(.fractionLength(1))) + "×")
              }.font(.caption)
              Slider(value: $model.sensitivity, in: 0.2...3.0, step: 0.1)
            }
            Text(
              bluetooth.absoluteMode
                ? "本模式直接发送画面坐标，iPhone 是否接受仍待验证。请关闭拖移锁定和停留控制。"
                : "以手机圆形指针为准。Mac 光标与手机指针可能不重合；可调整手机的跟踪速度。请关闭手机的拖移锁定和停留控制。"
            )
            .font(.caption).foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
          Text("配对与控制效果仍需在这台 Mac 和 iPhone 上验证。")
            .font(.caption).foregroundStyle(.orange)
        }
      }
      .frame(width: 310)
    }
    .padding(24)
    .background(Color(red: 0.07, green: 0.08, blue: 0.10))
  }

  private func probeButton(_ title: String, x: Double, y: Double) -> some View {
    Button(title) {
      model.armed = false
      bluetooth.probe(x: x, y: y)
    }
    .disabled(!bluetooth.connected)
  }
}

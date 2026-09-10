@preconcurrency import AVFoundation
import CoreMediaIO
import Foundation

struct ScreenCaptureDevice: @unchecked Sendable {
  let value: AVCaptureDevice

  // AVCaptureDevice is managed by AVFoundation and is not declared Sendable.
  // GlassTether only passes this immutable reference into its serial session queue.
  init(_ value: AVCaptureDevice) {
    self.value = value
  }
}

enum DeviceDiscoveryError: Error {
  case coreMediaIO
}

struct CoreMediaIODeviceDiscovery: Sendable {
  func discoverWiredScreenDevices() throws -> [ScreenCaptureDevice] {
    try applyWiredOnlyPolicy()

    var devices: [ScreenCaptureDevice] = []
    for deviceID in try copyDeviceIDs() {
      guard let uniqueID = try copyDeviceUniqueID(deviceID) else { continue }
      guard let device = AVCaptureDevice(uniqueID: uniqueID) else { continue }
      guard device.hasMediaType(.muxed) else { continue }
      devices.append(ScreenCaptureDevice(device))
    }
    return devices
  }

  private func applyWiredOnlyPolicy() throws {
    try setSystemProperty(
      CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
      value: 1
    )
    try setSystemProperty(
      CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowWirelessScreenCaptureDevices),
      value: 0
    )
  }

  private func setSystemProperty(
    _ selector: CMIOObjectPropertySelector,
    value: UInt32
  ) throws {
    var address = CMIOObjectPropertyAddress(
      mSelector: selector,
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var mutableValue = value
    let status = withUnsafePointer(to: &mutableValue) { pointer in
      CMIOObjectSetPropertyData(
        CMIOObjectID(kCMIOObjectSystemObject),
        &address,
        0,
        nil,
        UInt32(MemoryLayout<UInt32>.size),
        pointer
      )
    }
    guard status == noErr else { throw DeviceDiscoveryError.coreMediaIO }
  }

  private func copyDeviceIDs() throws -> [CMIODeviceID] {
    var address = CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var dataSize: UInt32 = 0
    guard
      CMIOObjectGetPropertyDataSize(
        CMIOObjectID(kCMIOObjectSystemObject),
        &address,
        0,
        nil,
        &dataSize
      ) == noErr
    else { throw DeviceDiscoveryError.coreMediaIO }
    guard dataSize > 0 else { return [] }

    let count = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
    var deviceIDs = [CMIODeviceID](repeating: 0, count: count)
    var dataUsed: UInt32 = 0
    let status = deviceIDs.withUnsafeMutableBytes { bytes in
      CMIOObjectGetPropertyData(
        CMIOObjectID(kCMIOObjectSystemObject),
        &address,
        0,
        nil,
        dataSize,
        &dataUsed,
        bytes.baseAddress!
      )
    }
    guard status == noErr else { throw DeviceDiscoveryError.coreMediaIO }
    let usedCount = Int(dataUsed) / MemoryLayout<CMIODeviceID>.size
    return Array(deviceIDs.prefix(usedCount))
  }

  private func copyDeviceUniqueID(_ deviceID: CMIODeviceID) throws -> String? {
    var address = CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var unmanagedUniqueID: Unmanaged<CFString>?
    var dataUsed: UInt32 = 0
    let status = withUnsafeMutablePointer(to: &unmanagedUniqueID) { pointer in
      CMIOObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        UInt32(MemoryLayout<Unmanaged<CFString>?>.size),
        &dataUsed,
        pointer
      )
    }
    guard status == noErr else { throw DeviceDiscoveryError.coreMediaIO }
    guard let unmanagedUniqueID else { return nil }
    return unmanagedUniqueID.takeRetainedValue() as String
  }
}

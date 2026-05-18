import AVFoundation

let devices = AVCaptureDevice.devices(for: .video)
for (index, device) in devices.enumerated() {
    print("[\(index)] \(device.localizedName)")
}

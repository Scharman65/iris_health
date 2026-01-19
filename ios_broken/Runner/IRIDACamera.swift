import Foundation
import AVFoundation
import UIKit

class IRIDACamera: NSObject {
    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "irida.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
        configureSession()
    }

    // MARK: - Лучший выбор камеры (Tele → Wide)
    private func selectBestDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTelephotoCamera,
                .builtInDualWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .back
        )

        // Ищем tele
        if let tele = discovery.devices.first(where: { $0.deviceType == .builtInTelephotoCamera }) {
            return tele
        }

        // fallback
        return discovery.devices.first
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let selected = selectBestDevice(),
              let input = try? AVCaptureDeviceInput(device: selected)
        else {
            print("[IRIDA] ERROR: No camera available")
            return
        }

        device = selected

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()

        configureMacroSettings()
    }

    // MARK: - Критичная часть: макро-настройки
    private func configureMacroSettings() {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()

            // Ручной ФОКУС → максимальная близость (идеально для радужки)
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
                if device.isLockingFocusWithIDSupported {
                    device.setFocusModeLocked(lensPosition: 1.0) { _ in }
                }
            }

            // Фиксированная экспозиция
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }

            device.isSmoothAutoFocusEnabled = false // без дыхания автофокуса

            // Макро-зум (идеально для iPhone 13 Pro)
            if device.activeFormat.videoMaxZoomFactor > 2.5 {
                device.videoZoomFactor = 2.5
            }

            device.unlockForConfiguration()
        } catch {
            print("[IRIDA] Focus config error:", error)
        }
    }

    // MARK: - Public API
    func startPreview(on view: UIView) {
        sessionQueue.async {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            self.previewLayer?.videoGravity = .resizeAspectFill

            DispatchQueue.main.async {
                if let layer = self.previewLayer {
                    layer.frame = view.bounds
                    view.layer.addSublayer(layer)
                }
            }

            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

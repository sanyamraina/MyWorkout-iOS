import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage.CIFilterBuiltins

struct TemplateShareSheet: View {
    let code: String
    let templateName: String
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Share Template")
                        .font(.custom("Avenir Next", size: 26))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))
                    Text(templateName)
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand).opacity(0.7))

                    QRCodeView(text: code)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Code")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                        Text("Use the button below to copy the code.")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themeColor(.sand).opacity(0.6))
                    }

                    Button {
                        onCopy()
                    } label: {
                        Text("Copy Code")
                            .font(.custom("Avenir Next", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.custom("Avenir Next", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.sand))
                            .background(
                                Capsule()
                                    .stroke(themeColor(.sand).opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(24)
            }
        }
    }
}

struct TemplateShareSheetPayload: Identifiable {
    let id = UUID()
    let code: String
    let templateName: String
}

struct QRCodeView: View {
    let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Group {
            if let image = generateImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(themeColor(.card).opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )
            } else {
                Text("Unable to generate QR code.")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.7))
            }
        }
    }

    private func generateImage() -> UIImage? {
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onError: onError)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let onError: (String) -> Void

        init(onImage: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
            self.onImage = onImage
            self.onError = onError
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onError("No image selected.")
                return
            }
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                onError("Unable to load image.")
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.onImage(image)
                    } else if let error {
                        self.onError(error.localizedDescription)
                    } else {
                        self.onError("Unable to load image.")
                    }
                }
            }
        }
    }
}

struct TemplateQRScanner: View {
    let onScan: (String) -> Void
    let onImportPhoto: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if AVCaptureDevice.default(for: .video) == nil {
                Text("Camera unavailable on this device.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand))
            } else {
                QRScannerView { code in
                    onScan(code)
                }
                .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand))
                    Spacer()
                    Text("Scan QR")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themeColor(.sand).opacity(0.7))
                    Spacer()
                    Button {
                        dismiss()
                        onImportPhoto()
                    } label: {
                        Image(systemName: "photo")
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(themeColor(.sand))
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                Spacer()
            }
        }
        .background(themeColor(.night).ignoresSafeArea())
    }
}

struct QRScannerView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        let session = AVCaptureSession()
        session.sessionPreset = .high
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return view
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        if let preview = view.layer as? AVCaptureVideoPreviewLayer {
            preview.session = session
            preview.videoGravity = .resizeAspectFill
            context.coordinator.previewLayer = preview
        }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = uiView.layer as? AVCaptureVideoPreviewLayer,
           let connection = preview.connection {
            let angle = currentRotationAngle()
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    private func currentRotationAngle() -> CGFloat {
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation ?? .portrait
        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            return 90
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        var session: AVCaptureSession?
        weak var previewLayer: AVCaptureVideoPreviewLayer?

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else { return }
            session?.stopRunning()
            onScan(value)
        }
    }
}

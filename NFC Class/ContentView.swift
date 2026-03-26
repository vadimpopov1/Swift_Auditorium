//
//  ContentView.swift
//  NFC Class
//
//  Created by Вадим Попов on 19.03.2026.
//

import SwiftUI
import CoreImage
import AVFoundation

struct ContentView: View {
    let urlString = "https://sibsutis.ru"
    @State private var showingQR = false
    @State private var showingScanner = false
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Button(action: openQRCode) {
                        Image(systemName: "qrcode")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .glassEffect()
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    
                    Spacer()
                    
                    Button(action: openQRScanner) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .glassEffect()
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showingQR) {
            QRView(urlString: urlString, onClose: {
                showingQR = false
            })
        }
        .fullScreenCover(isPresented: $showingScanner) {
            QRScannerView(onCodeScanned: { scannedCode in
                showingScanner = false
                if let url = URL(string: scannedCode) {
                    UIApplication.shared.open(url)
                }
            })
        }
    }
    
    private func openQRCode() {
        showingQR = true
    }
    
    private func openQRScanner() {
        showingScanner = true
    }
}

struct QRView: View {
    let urlString: String
    let onClose: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        onClose()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                if let qrImage = QRCodeGenerator.generateQRCode(from: urlString) {
                    VStack(spacing: 20) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .padding()
                    }
                } else {
                    Text("Ошибка создания QR-кода")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text("Покажите QR-код для сканирования")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .glassEffect()
                    .cornerRadius(10)
                    .padding(.bottom, 50)
            }
        }
    }
}

struct QRScannerView: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            QRScannerViewControllerRepresentable(onCodeScanned: { code in
                onCodeScanned(code)
                dismiss()
            })
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                Text("Наведите камеру на QR-код")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .glassEffect()
                    .cornerRadius(10)
                    .padding(.bottom, 50)
            }
        }
        .background(Color.black)
    }
}

struct QRScannerViewControllerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> SimpleQRScannerViewController {
        let controller = SimpleQRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SimpleQRScannerViewController, context: Context) {}
}

class SimpleQRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onCodeScanned: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupPreview()
        startScanning()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
        
        if let input = videoInput, captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
    }
    
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            
            captureSession.stopRunning()
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onCodeScanned?(stringValue)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}

class QRCodeGenerator {
    static func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let qrImage = qrFilter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledQrImage = qrImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledQrImage, from: scaledQrImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    ContentView()
}

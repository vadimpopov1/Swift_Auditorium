//
//  ContentView.swift
//  NFC Class
//
//  Created by Вадим Попов on 19.03.2026.
//

import SwiftUI
import CoreImage
import AVFoundation

enum AuthScreen {
    case login, register
}

struct AuthView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userProfile: UserProfile?

    @State private var currentScreen: AuthScreen = .login
    @State private var login = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var inviteCode = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 25) {
            Text(currentScreen == .login ? "Вход" : "Регистрация")
                .font(.largeTitle).bold()

            TextField("Логин", text: $login)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField("Пароль", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if currentScreen == .register {
                SecureField("Повторите пароль", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Пригласительный код", text: $inviteCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }

            Button(action: handleAction) {
                Group {
                    if isLoading { ProgressView() } else {
                        Text(currentScreen == .login ? "Войти" : "Зарегистрироваться")
                    }
                }
                .frame(maxWidth: .infinity).padding()
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isLoading)

            Button(action: switchScreen) {
                Text(currentScreen == .login
                     ? "Нет аккаунта? Зарегистрироваться"
                     : "Уже есть аккаунт? Войти")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .alert("Сообщение", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func switchScreen() {
        withAnimation {
            currentScreen = currentScreen == .login ? .register : .login
            login = ""; password = ""; confirmPassword = ""; inviteCode = ""
        }
    }

    private func handleAction() {
        guard !login.isEmpty, !password.isEmpty else {
            return show("Введите логин и пароль")
        }
        if currentScreen == .register {
            guard password == confirmPassword else { return show("Пароли не совпадают") }
            guard !inviteCode.isEmpty else { return show("Введите пригласительный код") }
        }
        isLoading = true
        Task {
            defer { Task { @MainActor in isLoading = false } }
            do {
                if currentScreen == .login {
                    let profile = try await APIService.shared.login(login: login, password: password)
                    await MainActor.run {
                        userProfile = profile
                        isLoggedIn = true
                    }
                } else {
                    _ = try await APIService.shared.registerByInvite(
                        inviteCode: inviteCode,
                        login: login,
                        password: password
                    )
                    await MainActor.run { switchScreen(); show("Регистрация успешна! Войдите в аккаунт.") }
                }
            } catch {
                await MainActor.run { show(error.localizedDescription) }
            }
        }
    }

    private func show(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var userProfile: UserProfile?

    var body: some View {
        if isLoggedIn, let profile = userProfile {
            MainAppView(profile: profile, onLogout: {
                APIService.shared.logout()
                userProfile = nil
                isLoggedIn = false
            })
        } else {
            AuthView(isLoggedIn: $isLoggedIn, userProfile: $userProfile)
        }
    }
}

struct MainAppView: View {
    let profile: UserProfile
    let onLogout: () -> Void

    @State private var showingQR = false
    @State private var showingScanner = false
    @State private var showingProfile = false
    @State private var showLogoutConfirm = false

    let urlString = "https://sibsutis.ru"

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileCardView(profile: profile, onLogout: { showLogoutConfirm = true })
                    .padding()

                Spacer()

                HStack {
                    Button(action: { showingQR = true }) {
                        Image(systemName: "qrcode")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .glassEffect()
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    Spacer()
                    Button(action: { showingScanner = true }) {
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
            QRView(urlString: urlString, onClose: { showingQR = false })
        }
        .fullScreenCover(isPresented: $showingScanner) {
            QRScannerView(onCodeScanned: { scannedCode in
                showingScanner = false
                if let url = URL(string: scannedCode) {
                    UIApplication.shared.open(url)
                }
            })
        }
        .confirmationDialog("Выйти из аккаунта?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { onLogout() }
            Button("Отмена", role: .cancel) {}
        }
    }
}

struct ProfileCardView: View {
    let profile: UserProfile
    let onLogout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(profile.role == "teacher" ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: profile.roleIcon)
                        .font(.title2)
                        .foregroundColor(profile.role == "teacher" ? .blue : .green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.login)
                        .font(.title3).bold()
                        .lineLimit(1)
                    Label(profile.roleDisplayName, systemImage: profile.roleIcon)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onLogout) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
            }

            Divider()

            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.secondary)
                Text("ID пользователя:")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
                Text(profile.userID)
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
    }
}

struct QRView: View {
    let urlString: String
    let onClose: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: { onClose(); dismiss() }) {
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
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .background(Color.white)
                        .padding()
                } else {
                    Text("Ошибка создания QR-кода").foregroundColor(.red)
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
                    Button(action: { dismiss() }) {
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

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
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

extension View {
    func glassEffect() -> some View {
        self.background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
}

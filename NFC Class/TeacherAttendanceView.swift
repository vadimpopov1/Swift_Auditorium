//
//  TeacherAttendanceView.swift
//  NFC Class
//
//  Created by Вадим Попов on 10.05.2026.
//

import SwiftUI

struct TeacherAttendanceView: View {
    @State private var lessonName = ""
    @State private var expiresMinutes = 20

    @State private var session: AttendanceSession?
    @State private var stats: AttendanceGroupStats?

    @State private var isCreatingSession = false
    @State private var isLoadingStats = false
    @State private var showingQR = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let groupID = 469
    private let subjectID = 1

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    sessionFormCard
                    if let session = session {
                        sessionInfoCard(session: session)
                    }
                    statsCard
                }
                .padding()
            }
            .navigationTitle("Посещаемость")
            .onAppear { loadStats() }
            .alert("Ошибка", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .fullScreenCover(isPresented: $showingQR) {
                if let session = session {
                    AttendanceQRView(session: session, onClose: { showingQR = false })
                }
            }
        }
    }

    private var sessionFormCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Создать сессию", systemImage: "plus.circle.fill")
                .font(.headline)

            TextField("Название занятия", text: $lessonName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Text("Время действия:")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
                Stepper("\(expiresMinutes) мин", value: $expiresMinutes, in: 5...120, step: 5)
                    .fixedSize()
            }

            Button(action: createSession) {
                Group {
                    if isCreatingSession {
                        ProgressView()
                    } else {
                        Label("Создать и показать QR", systemImage: "qrcode")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(isCreatingSession)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func sessionInfoCard(session: AttendanceSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Активная сессия", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)

            Divider()

            infoRow(icon: "book.fill", label: "Занятие", value: session.lessonName)
            infoRow(icon: "person.3.fill", label: "Студентов в группе", value: "\(session.rosterSize)")
            infoRow(icon: "clock.fill", label: "Действует", value: "\(session.expiresMinutes) мин")

            Button(action: { showingQR = true }) {
                Label("Показать QR-код", systemImage: "qrcode")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .cornerRadius(12)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Статистика группы", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                Button(action: loadStats) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.purple)
                }
                .disabled(isLoadingStats)
            }

            if isLoadingStats {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let stats = stats {
                HStack {
                    statBadge(value: "\(stats.sessionsCount)", label: "занятий", color: .blue)
                    statBadge(value: "\(stats.studentsCount)", label: "студентов", color: .purple)
                }

                ForEach(stats.students, id: \.studentID) { student in
                    StudentAttendanceRow(student: student)
                    if student.studentID != stats.students.last?.studentID {
                        Divider()
                    }
                }
            } else {
                Text("Нет данных")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline).bold()
        }
    }

    private func createSession() {
        let name = lessonName.isEmpty ? "Занятие" : lessonName
        isCreatingSession = true
        Task {
            defer { Task { @MainActor in isCreatingSession = false } }
            do {
                let s = try await APIService.shared.createAttendanceSession(
                    subjectID: subjectID,
                    groupIDs: [groupID],
                    lessonName: name,
                    expiresMinutes: expiresMinutes
                )
                await MainActor.run {
                    session = s
                    showingQR = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func loadStats() {
        isLoadingStats = true
        Task {
            defer { Task { @MainActor in isLoadingStats = false } }
            do {
                let s = try await APIService.shared.fetchGroupStats(groupID: groupID, subjectID: subjectID)
                await MainActor.run { stats = s }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct StudentAttendanceRow: View {
    let student: AttendanceStudent

    var percentColor: Color {
        switch student.attendancePercent {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.studentName)
                        .font(.subheadline).bold()
                    Text("\(student.attendedSessions) из \(student.totalSessions) занятий")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f%%", student.attendancePercent))
                    .font(.headline)
                    .foregroundColor(percentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(percentColor)
                        .frame(width: geo.size.width * CGFloat(student.attendancePercent / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

struct AttendanceQRView: View {
    let session: AttendanceSession
    let onClose: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { onClose(); dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                    Spacer()
                }

                Spacer()

                VStack(spacing: 20) {
                    Text(session.lessonName)
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    if let qrImage = QRCodeGenerator.generateQRCode(from: session.joinURL.replacing("localhost", with: "109.172.114.128")) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 280, height: 280)
                            .background(Color.white)
                            .padding()
                    } else {
                        Text("Ошибка создания QR-кода").foregroundColor(.red)
                    }

                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(session.rosterSize)")
                                .font(.headline).bold()
                                .foregroundColor(.white)
                            Text("студентов")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(session.expiresMinutes) мин")
                                .font(.headline).bold()
                                .foregroundColor(.white)
                            Text("действует")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .padding(.horizontal)
                }

                Spacer()

                Text("Студенты сканируют QR для отметки")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
    }
}

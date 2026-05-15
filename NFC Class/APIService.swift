//
//  APIService.swift
//  NFC Class
//
//  Created by Вадим Попов on 16.04.2026.
//

import Foundation
import CryptoKit

struct UserProfile: Codable {
    let userID: String
    let login: String
    let role: String

    var roleDisplayName: String {
        switch role {
        case "teacher": return "Преподаватель"
        case "student": return "Студент"
        default: return role
        }
    }

    var roleIcon: String {
        switch role {
        case "teacher": return "person.fill.checkmark"
        case "student": return "graduationcap.fill"
        default: return "person.fill"
        }
    }
}

struct AttendanceSession {
    let inviteToken: String
    let joinURL: String
    let lessonName: String
    let expiresAt: String
    let expiresMinutes: Int
    let rosterSize: Int
    let subjectID: Int
    let groupIDs: [Int]
}

struct AttendanceStudent {
    let studentID: Int
    let studentName: String
    let attendedSessions: Int
    let totalSessions: Int
    let attendancePercent: Double
    let lastMarkedAt: String?
}

struct AttendanceGroupStats {
    let groupID: Int
    let subjectID: Int
    let sessionsCount: Int
    let studentsCount: Int
    let students: [AttendanceStudent]
}

class APIService {
    static let shared = APIService()
    private let baseURL = "http://109.172.114.128:9000"

    private(set) var token: String?

    private init() {}

    private struct ServerResponse<T: Codable>: Codable {
        let ok: Bool
        let result: T?
        let error: String?
    }

    private func sha256hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func post<B: Encodable, R: Codable>(
        endpoint: String,
        body: B,
        as type: R.Type
    ) async throws -> R? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let response = try JSONDecoder().decode(ServerResponse<R>.self, from: data)
        if let error = response.error, !error.isEmpty {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
        }
        return response.result
    }

    private func get<R: Codable>(endpoint: String, as type: R.Type) async throws -> R? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        let response = try JSONDecoder().decode(ServerResponse<R>.self, from: data)
        if let error = response.error, !error.isEmpty {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
        }
        return response.result
    }

    func registerByInvite(inviteCode: String, login: String, password: String) async throws -> Bool {
        struct Body: Encodable { let invite_code, login, password: String }
        struct Result: Codable { let ok: Bool? }
        let result = try await post(
            endpoint: "/register/by-invite",
            body: Body(invite_code: inviteCode, login: login, password: sha256hex(password)),
            as: Result.self
        )
        return result?.ok ?? true
    }

    func login(login loginStr: String, password: String) async throws -> UserProfile {
        struct Body: Encodable { let login, password: String }
        struct Result: Codable { let token: String; let role: String; let user_ID: String; let login: String? }
        guard let result = try await post(
            endpoint: "/login",
            body: Body(login: loginStr, password: sha256hex(password)),
            as: Result.self
        ) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Сервер не вернул данные"])
        }
        self.token = result.token
        return UserProfile(
            userID: result.user_ID,
            login: result.login ?? loginStr,
            role: result.role
        )
    }

    func fetchProfile() async throws -> UserProfile {
        struct Result: Codable { let user_id: String; let login: String; let role: String }
        guard let result = try await get(endpoint: "/profile", as: Result.self) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Профиль недоступен"])
        }
        return UserProfile(userID: result.user_id, login: result.login, role: result.role)
    }

    func createAttendanceSession(subjectID: Int?, groupIDs: [Int]?, lessonName: String, expiresMinutes: Int) async throws -> AttendanceSession {
        struct Body: Encodable {
            let subject_id: Int?
            let group_ids: [Int]?
            let lesson_name: String
            let expires_minutes: Int
        }
        struct Result: Codable {
            let invite_token: String
            let join_url: String
            let lesson_name: String
            let expires_at: String
            let expires_minutes: Int
            let roster_size: Int
            let subject_id: Int
            let group_ids: [Int]
        }
        guard let result = try await post(
            endpoint: "/api/teacher/attendance/session",
            body: Body(subject_id: subjectID, group_ids: groupIDs, lesson_name: lessonName, expires_minutes: expiresMinutes),
            as: Result.self
        ) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию"])
        }
        return AttendanceSession(
            inviteToken: result.invite_token,
            joinURL: result.join_url,
            lessonName: result.lesson_name,
            expiresAt: result.expires_at,
            expiresMinutes: result.expires_minutes,
            rosterSize: result.roster_size,
            subjectID: result.subject_id,
            groupIDs: result.group_ids
        )
    }

    func fetchGroupStats(groupID: Int, subjectID: Int?) async throws -> AttendanceGroupStats {
        struct Body: Encodable { let group_id: Int; let subject_id: Int? }
        struct StudentResult: Codable {
            let student_id: Int
            let student_name: String
            let attended_sessions: Int
            let total_sessions: Int
            let attendance_percent: Double
            let last_marked_at: String?
        }
        struct SummaryResult: Codable { let sessions_count: Int; let students_count: Int }
        struct Result: Codable {
            let group_id: Int
            let subject_id: Int
            let summary: SummaryResult
            let students: [StudentResult]
        }
        guard let result = try await post(
            endpoint: "/api/teacher/attendance/group",
            body: Body(group_id: groupID, subject_id: subjectID),
            as: Result.self
        ) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Не удалось загрузить статистику"])
        }
        return AttendanceGroupStats(
            groupID: result.group_id,
            subjectID: result.subject_id,
            sessionsCount: result.summary.sessions_count,
            studentsCount: result.summary.students_count,
            students: result.students.map {
                AttendanceStudent(
                    studentID: $0.student_id,
                    studentName: $0.student_name,
                    attendedSessions: $0.attended_sessions,
                    totalSessions: $0.total_sessions,
                    attendancePercent: $0.attendance_percent,
                    lastMarkedAt: $0.last_marked_at
                )
            }
        )
    }

    func logout() {
        token = nil
    }
}

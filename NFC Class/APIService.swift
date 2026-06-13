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

struct AttendanceSession: Codable {
    let inviteToken: String
    let joinURL: String
    let lessonName: String
    let expiresAt: String
    let expiresMinutes: Int
    let rosterSize: Int
    let subjectID: Int
    let groupIDs: [Int]
    let lessonID: String
}

struct AttendanceStudent: Codable {
    let studentID: Int
    let studentName: String
    let attendedSessions: Int
    let totalSessions: Int
    let attendancePercent: Double
    let lastMarkedAt: String?
}

struct AttendanceGroupStats: Codable {
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
            body: Body(invite_code: inviteCode, login: login, password: password),
            as: Result.self
        )
        return result?.ok ?? true
    }

    func login(login loginStr: String, password: String) async throws -> UserProfile {
        struct Body: Encodable { let login, password: String }
        struct Result: Codable { let token: String; let role: String; let user_ID: String; let login: String? }
        guard let result = try await post(
            endpoint: "/login",
            body: Body(login: loginStr, password: password),
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
            let lesson_id: String
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
            groupIDs: result.group_ids,
            lessonID: result.lesson_id
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

    func confirmAttendance(inviteToken: String) async throws -> Bool {
        struct Body: Encodable { let invite_token: String }
        struct Result: Codable { let attendance: String }
        let result = try await post(
            endpoint: "/api/student/attendance/confirm",
            body: Body(invite_token: inviteToken),
            as: Result.self
        )
        return result?.attendance == "confirmed"
    }

    func getActiveSession() async throws -> AttendanceSession? {
        struct ActiveSessionItem: Codable {
            let id: Int
            let lesson_id: Int
            let lesson_name: String
            let invite_token: String?
            let join_url: String?
            let url: String?
            let qr_payload: String?
            let expires_at: String
            let expires_minutes: Int?
            let roster_size: Int
            let subject_id: Int
            let teacher_id: Int
            let marked_count: Int
            let attendance_percent: Double
            let remaining_seconds: Int
            let seconds_remaining: Int
            let is_active: Bool
        }

        struct ActiveSessionResult: Codable {
            let active: Bool?
            let remaining_seconds: Int?
            let seconds_remaining: Int?
            let server_time: String?
            let timezone: String?
            let session: ActiveSessionItem?
        }

        guard let url = URL(string: "\(baseURL)/api/teacher/attendance/session/active") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, httpResp) = try await URLSession.shared.data(for: req)
        let statusCode = (httpResp as? HTTPURLResponse)?.statusCode ?? 0

        guard statusCode == 200 else { return nil }

        guard let outer = try? JSONDecoder().decode(ServerResponse<ActiveSessionResult>.self, from: data),
              outer.ok,
              let result = outer.result,
              result.active == true,
              let s = result.session,
              s.is_active else { return nil }

        let resolvedToken = s.invite_token ?? ""

        let resolvedURL: String
        if let ju = s.join_url, !ju.isEmpty {
            resolvedURL = ju.replacingOccurrences(of: "localhost", with: "109.172.114.128")
        } else if let qr = s.qr_payload, !qr.isEmpty {
            resolvedURL = qr.replacingOccurrences(of: "localhost", with: "109.172.114.128")
        } else if let u = s.url, !u.isEmpty {
            resolvedURL = u.replacingOccurrences(of: "localhost", with: "109.172.114.128")
        } else if !resolvedToken.isEmpty {
            resolvedURL = "http://109.172.114.128:9000/attendance/join?token=\(resolvedToken)"
        } else {
            return nil
        }

        let secs = s.remaining_seconds > 0 ? s.remaining_seconds : s.seconds_remaining

        return AttendanceSession(
            inviteToken: resolvedToken,
            joinURL: resolvedURL,
            lessonName: s.lesson_name,
            expiresAt: s.expires_at,
            expiresMinutes: s.expires_minutes ?? (secs / 60),
            rosterSize: s.roster_size,
            subjectID: s.subject_id,
            groupIDs: [],
            lessonID: String(s.lesson_id)
        )
    }

    func getMarkedCount(lessonId: Int) async throws -> (marked: Int, roster: Int, percent: Double) {
        struct Result: Codable {
            let lesson_id: Int
            let marked_count: Int
            let roster_size: Int
            let attendance_percent: Double
        }
        guard let result = try await get(
            endpoint: "/api/teacher/attendance/session/marked-count?lesson_id=\(lessonId)",
            as: Result.self
        ) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Нет данных о сессии"])
        }
        return (result.marked_count, result.roster_size, result.attendance_percent)
    }

    func getSessionTimer(lessonId: Int) async throws -> (secondsRemaining: Int, isActive: Bool) {
        struct Result: Codable {
            let expires_at: String
            let server_time: String
            let remaining_seconds: Int
            let seconds_remaining: Int
            let is_active: Bool
            let lesson_id: Int
            let timezone: String
        }
        guard let result = try await get(
            endpoint: "/api/teacher/attendance/session/timer?lesson_id=\(lessonId)",
            as: Result.self
        ) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Нет данных о таймере"])
        }
        let seconds = result.remaining_seconds > 0 ? result.remaining_seconds : result.seconds_remaining
        return (seconds, result.is_active)
    }

    func logout() {
        token = nil
    }
}

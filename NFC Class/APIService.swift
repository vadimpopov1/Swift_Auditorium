//
//  APIService.swift
//  NFC Class
//
//  Created by Вадим Попов on 16.04.2026.
//

import Foundation

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

    func logout() {
        token = nil
    }
}

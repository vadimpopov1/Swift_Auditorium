//
//  APIService.swift
//  NFC Class
//
//  Created by Вадим Попов on 16.04.2026.
//

import Foundation

class APIService {
    static let shared = APIService()
    private let baseURL = "http://109.172.114.128:9000"
    private init() {}

    private struct ServerResponse<T: Codable>: Codable {
        let ok: Bool
        let result: T?
        let error: String?
    }

    private func post<B: Encodable, R: Codable>(endpoint: String, body: B, as type: R.Type) async throws -> R? {
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

    func register(login: String, password: String) async throws -> Bool {
        struct Body: Encodable { let login, password: String }
        struct Result: Codable { let ok: Bool? }
        let result = try await post(endpoint: "/register", body: Body(login: login, password: password), as: Result.self)
        return result?.ok ?? true
    }

    func login(login: String, password: String) async throws -> String {
        struct Body: Encodable { let login, password: String }
        struct Result: Codable { let token: String; let role: String; let user_ID: String }
        guard let result = try await post(endpoint: "/login", body: Body(login: login, password: password), as: Result.self) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Сервер не вернул данные"])
        }
        return result.token
    }
}

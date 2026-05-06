import Foundation

struct Profile: Codable, Hashable, Identifiable {
    let id: UUID
    var email: String?
    var fullName: String?
    var firstName: String?
    var avatarURL: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case firstName = "first_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Best-guess name to use in the greeting. Falls back gracefully.
    var greetingName: String {
        if let first = firstName?.trimmingCharacters(in: .whitespaces), !first.isEmpty {
            return first
        }
        if let full = fullName?.trimmingCharacters(in: .whitespaces), !full.isEmpty {
            return full.split(separator: " ").first.map(String.init) ?? full
        }
        if let email, let prefix = email.split(separator: "@").first {
            return String(prefix).capitalized
        }
        return "there"
    }
}

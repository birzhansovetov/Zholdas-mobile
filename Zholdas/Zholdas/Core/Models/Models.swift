import Foundation
import CoreLocation

// MARK: - Auth DTOs

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let username: String
    let fullName: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case username
        case fullName = "full_name"
    }
}

struct SignUpResponse: Codable {
    let userID: String
    let username: String
    let fullName: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case fullName = "full_name"
        case message
    }
}

struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct RefreshRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Domain Models

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let username: String
    let fullName: String
    let avatarURL: String?
    let bio: String?
    let city: String?
    let gender: String?
    let birthYear: Int?
    let age: Int?
    let eventsCount: Int?
    let rating: Double?
    let role: String?
    let isBanned: Bool?
    let emailConfirmed: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case bio
        case city
        case gender
        case birthYear = "birth_year"
        case age
        case eventsCount = "events_count"
        case rating
        case role
        case isBanned = "is_banned"
        case emailConfirmed = "email_confirmed"
    }
}

struct UserReview: Codable, Identifiable, Hashable {
    let id: Int32
    let evaluatorName: String
    let evaluatorAvatarURL: String?
    let rating: Int
    let comment: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case evaluatorName = "evaluator_name"
        case evaluatorAvatarURL = "evaluator_avatar_url"
        case rating
        case comment
        case createdAt = "created_at"
    }
}

struct Report: Codable, Identifiable, Hashable {
    let id: Int32
    let reporterID: String
    let reporterName: String
    let reportedUserID: String?
    let reportedUserName: String?
    let eventID: Int32?
    let eventTitle: String?
    let messageID: Int32?
    let messageText: String?
    let reason: String
    let description: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reporterID = "reporter_id"
        case reporterName = "reporter_name"
        case reportedUserID = "reported_user_id"
        case reportedUserName = "reported_user_name"
        case eventID = "event_id"
        case eventTitle = "event_title"
        case messageID = "message_id"
        case messageText = "message_text"
        case reason
        case description
        case createdAt = "created_at"
    }
}

struct Event: Codable, Identifiable, Hashable {
    let id: Int32
    let creatorID: String
    let title: String
    let description: String
    let category: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date
    let maxParticipants: Int32
    let status: String
    let imageURL: String?
    let distanceMeters: Double?
    let participantsCount: Int32?
    let isJoined: Bool?
    let visibility: String?
    let genderFilter: String?
    let minAge: Int32?
    let maxAge: Int32?
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case title
        case description
        case category
        case locationName = "location_name"
        case latitude
        case longitude
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case status
        case imageURL = "image_url"
        case distanceMeters = "distance_meters"
        case participantsCount = "participants_count"
        case isJoined = "is_joined"
        case visibility
        case genderFilter = "gender_filter"
        case minAge = "min_age"
        case maxAge = "max_age"
    }
}

struct Participant: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let fullName: String
    let avatarURL: String?
    let participantStatus: String?
    let arrivedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case participantStatus = "participant_status"
        case arrivedAt = "arrived_at"
    }
}

struct EventLiveLocation: Codable, Identifiable, Hashable {
    let userID: String
    let username: String
    let fullName: String
    let avatarURL: String?
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let updatedAt: Date
    let expiresAt: Date

    var id: String { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case latitude
        case longitude
        case accuracy
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
}

extension Event {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func matchesAudienceFilters(gender: String, age: Int?, maxDistanceKm: Double, distanceMetersOverride: Double? = nil) -> Bool {
        let effectiveDistanceMeters = distanceMetersOverride ?? distanceMeters
        guard let effectiveDistanceMeters else {
            return false
        }
        if effectiveDistanceMeters > maxDistanceKm * 1000 {
            return false
        }

        let eventGender = (genderFilter ?? "all").lowercased()
        if gender != "all", eventGender != "all", eventGender != gender {
            return false
        }

        if let age {
            let minAllowed = Int(minAge ?? 0)
            let maxAllowed = Int(maxAge ?? 0)

            if minAllowed > 0, age < minAllowed {
                return false
            }
            if maxAllowed > 0, age > maxAllowed {
                return false
            }
        }

        return true
    }
}

extension EventLiveLocation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - UserProfile and Simulators

typealias UserProfile = User

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let senderName: String
    let senderAvatarURL: String?
    let text: String
    let timestamp: Date
    let isCurrentUser: Bool
    var dbID: Int32? = nil
    var senderID: String? = nil
}

struct ChatSession: Identifiable, Codable, Hashable {
    let id: Int32
    let title: String
    let timeLabel: String
    let lastMessage: String
    let lastMessageSender: String
    let lastMessageTime: Date
    let isCompleted: Bool
    let categoryIcon: String
    let categoryColorHex: String
    var messages: [ChatMessage]
}

struct ActivityItem: Identifiable, Codable, Hashable {
    let id: UUID
    let userName: String
    let actionText: String
    let targetTitle: String
    let timeString: String
    let category: String // "Все" или "Друзья"
}

struct NotificationItem: Identifiable, Codable, Hashable {
    let id: Int32
    let userID: String
    let actorID: String?
    let actorName: String
    let actorAvatarURL: String
    let eventID: Int32
    let eventTitle: String
    let notificationType: String // "join", "leave", etc.
    let text: String
    let isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case actorID = "actor_id"
        case actorName = "actor_name"
        case actorAvatarURL = "actor_avatar_url"
        case eventID = "event_id"
        case eventTitle = "event_title"
        case notificationType = "notification_type"
        case text
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

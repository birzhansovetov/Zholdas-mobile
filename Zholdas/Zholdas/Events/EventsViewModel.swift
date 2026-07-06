import Foundation
import Combine
import CoreLocation

@MainActor
class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recommendationAnswer: String?
    @Published var recommendedEventIDs: [Int32] = []
    
    // MARK: - API Calls
    
    func fetchNearbyEvents(latitude: Double, longitude: Double, radiusMeters: Int = 10000) async {
        self.isLoading = true
        self.errorMessage = nil
        
        let path = "/events/nearby?latitude=\(latitude)&longitude=\(longitude)&radius_meters=\(radiusMeters)"
        
        do {
            let fetchedEvents: [Event] = try await APIClient.shared.request(path, method: "GET", requiresAuth: true)
            self.events = fetchedEvents
            
            if let encoded = try? JSONEncoder().encode(fetchedEvents) {
                UserDefaults.standard.set(encoded, forKey: "cached_nearby_events")
            }
        } catch {
            self.errorMessage = "Не удалось загрузить события: \(error.localizedDescription)"
            
            if let data = UserDefaults.standard.data(forKey: "cached_nearby_events"),
               let cached = try? JSONDecoder().decode([Event].self, from: data) {
                self.events = cached
                self.errorMessage = "Показываем сохраненные события (офлайн-режим)"
            }
        }
        
        self.isLoading = false
    }
    
    func createEvent(
        title: String,
        description: String,
        category: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        startTime: Date,
        endTime: Date,
        maxParticipants: Int32,
        imageURL: String? = nil,
        visibility: String? = nil,
        genderFilter: String? = nil,
        minAge: Int32? = nil,
        maxAge: Int32? = nil
    ) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        // Используем DTO для создания события
        let request = CreateEventRequest(
            title: title,
            description: description,
            category: category,
            locationName: locationName,
            longitude: longitude,
            latitude: latitude,
            startTime: startTime,
            endTime: endTime,
            maxParticipants: maxParticipants,
            imageURL: imageURL,
            visibility: visibility,
            genderFilter: genderFilter,
            minAge: minAge,
            maxAge: maxAge
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = try encoder.encode(request)
            let _: Event = try await APIClient.shared.request("/events", method: "POST", body: body, requiresAuth: true)
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = "Ошибка при создании события: \(error.localizedDescription)"
            self.isLoading = false
            return false
        }
    }
    
    func fetchAIRecommendations(query: String, latitude: Double, longitude: Double, radiusMeters: Int = 10000) async {
        self.isLoading = true
        self.errorMessage = nil
        self.recommendationAnswer = nil
        self.recommendedEventIDs = []
        
        // Кодируем запрос query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            self.errorMessage = "Некорректный текст запроса"
            self.isLoading = false
            return
        }
        
        let path = "/events/recommendations?q=\(encodedQuery)&latitude=\(latitude)&longitude=\(longitude)&radius_meters=\(radiusMeters)"
        
        do {
            let response: AIRecommendationResponse = try await APIClient.shared.request(path, method: "GET", requiresAuth: true)
            self.recommendationAnswer = response.answer
            self.recommendedEventIDs = response.recommendedCardIDs
        } catch {
            self.errorMessage = "Ошибка ИИ-рекомендаций: \(error.localizedDescription)"
        }
        
        self.isLoading = false
    }
    
    func joinEvent(id: Int32) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        let path = "/events/\(id)/join"
        
        do {
            let _: [String: String] = try await APIClient.shared.request(path, method: "POST", requiresAuth: true)
            
            // Local state update
            if let index = self.events.firstIndex(where: { $0.id == id }) {
                let oldEvent = self.events[index]
                let newCount = (oldEvent.participantsCount ?? 0) + 1
                self.events[index] = Event(
                    id: oldEvent.id,
                    creatorID: oldEvent.creatorID,
                    title: oldEvent.title,
                    description: oldEvent.description,
                    category: oldEvent.category,
                    locationName: oldEvent.locationName,
                    latitude: oldEvent.latitude,
                    longitude: oldEvent.longitude,
                    startTime: oldEvent.startTime,
                    endTime: oldEvent.endTime,
                    maxParticipants: oldEvent.maxParticipants,
                    status: oldEvent.status,
                    imageURL: oldEvent.imageURL,
                    distanceMeters: oldEvent.distanceMeters,
                    participantsCount: newCount,
                    isJoined: true,
                    visibility: oldEvent.visibility,
                    genderFilter: oldEvent.genderFilter,
                    minAge: oldEvent.minAge,
                    maxAge: oldEvent.maxAge
                )
            }
            
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = "Не удалось присоединиться: \(error.localizedDescription)"
            self.isLoading = false
            return false
        }
    }
    
    func leaveEvent(id: Int32) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        let path = "/events/\(id)/leave"
        
        do {
            let _: [String: String] = try await APIClient.shared.request(path, method: "POST", requiresAuth: true)
            
            // Local state update
            if let index = self.events.firstIndex(where: { $0.id == id }) {
                let oldEvent = self.events[index]
                let newCount = max(0, (oldEvent.participantsCount ?? 0) - 1)
                self.events[index] = Event(
                    id: oldEvent.id,
                    creatorID: oldEvent.creatorID,
                    title: oldEvent.title,
                    description: oldEvent.description,
                    category: oldEvent.category,
                    locationName: oldEvent.locationName,
                    latitude: oldEvent.latitude,
                    longitude: oldEvent.longitude,
                    startTime: oldEvent.startTime,
                    endTime: oldEvent.endTime,
                    maxParticipants: oldEvent.maxParticipants,
                    status: oldEvent.status,
                    imageURL: oldEvent.imageURL,
                    distanceMeters: oldEvent.distanceMeters,
                    participantsCount: newCount,
                    isJoined: false,
                    visibility: oldEvent.visibility,
                    genderFilter: oldEvent.genderFilter,
                    minAge: oldEvent.minAge,
                    maxAge: oldEvent.maxAge
                )
            }
            
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = "Не удалось отменить участие: \(error.localizedDescription)"
            self.isLoading = false
            return false
        }
    }
    
    func fetchParticipants(id: Int32) async -> [Participant] {
        let path = "/events/\(id)/participants"
        
        do {
            let list: [Participant] = try await APIClient.shared.request(path, method: "GET", requiresAuth: true)
            return list
        } catch {
            print("Ошибка загрузки участников: \(error.localizedDescription)")
            return []
        }
    }

    func markArrived(id: Int32) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/events/\(id)/arrive",
                method: "POST",
                requiresAuth: true
            )
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = "Не удалось отметить прибытие: \(error.localizedDescription)"
            self.isLoading = false
            return false
        }
    }

    func updateLiveLocation(eventID: Int32, location: CLLocation) async -> Bool {
        self.errorMessage = nil

        let payload = UpdateLiveLocationRequest(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        )

        do {
            let body = try JSONEncoder().encode(payload)
            let _: [String: String] = try await APIClient.shared.request(
                "/events/\(eventID)/live-location",
                method: "POST",
                body: body,
                requiresAuth: true
            )
            return true
        } catch {
            self.errorMessage = "Не удалось обновить локацию: \(error.localizedDescription)"
            return false
        }
    }

    func fetchLiveLocations(eventID: Int32) async -> [EventLiveLocation] {
        do {
            let list: [EventLiveLocation] = try await APIClient.shared.request(
                "/events/\(eventID)/live-locations",
                method: "GET",
                requiresAuth: true
            )
            return list
        } catch {
            self.errorMessage = "Не удалось загрузить локации участников: \(error.localizedDescription)"
            return []
        }
    }

    func stopLiveLocation(eventID: Int32) async {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/events/\(eventID)/live-location",
                method: "DELETE",
                requiresAuth: true
            )
        } catch {
            print("Ошибка остановки live-локации: \(error.localizedDescription)")
        }
    }
}

// MARK: - Additional DTOs for Events

struct UpdateLiveLocationRequest: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
}

struct CreateEventRequest: Codable {
    let title: String
    let description: String
    let category: String
    let locationName: String
    let longitude: Double
    let latitude: Double
    let startTime: Date
    let endTime: Date
    let maxParticipants: Int32
    let imageURL: String?
    let visibility: String?
    let genderFilter: String?
    let minAge: Int32?
    let maxAge: Int32?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case category
        case locationName = "location_name"
        case longitude
        case latitude
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case imageURL = "image_url"
        case visibility
        case genderFilter = "gender_filter"
        case minAge = "min_age"
        case maxAge = "max_age"
    }
}

struct AIRecommendationResponse: Codable {
    let answer: String
    let recommendedCardIDs: [Int32]
    
    enum CodingKeys: String, CodingKey {
        case answer
        case recommendedCardIDs = "recommended_card_ids"
    }
}
